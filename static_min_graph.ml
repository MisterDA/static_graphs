module DG = Graph.Pack.Digraph
module Option = struct
  let get = function None -> raise (invalid_arg "") | Some v -> v
end

type ttbl_event = {tarr : Gtfs.time; tdep : Gtfs.time}
type ttbl_stop = {events : ttbl_event Vector.t;
                  arr : DG.V.label; dep : DG.V.label;
                  station : DG.V.t}
type ttbl = (Gtfs.route_id, ttbl_stop Vector.t) Hashtbl.t

type t = {
    max_station : int option;
    graph : DG.t;
    stations : (Gtfs.station_id, DG.V.t) Hashtbl.t;
    names : string Vector.t;
  }

let parse_trips gtfs_dir =
  let trips = Hashtbl.create 16 in
  let aux (Gtfs.{ route_id; trip_id }) = Hashtbl.add trips trip_id route_id in
  File.input_all (Gtfs.parse_trips aux) (gtfs_dir ^ "trips.csv") File.Csv;
  trips

let parse_stations smg gtfs_dir =
  let max_station = ref (0 : DG.V.label) in
  let aux (Gtfs.{station_id}) =
    let v = DG.V.create !max_station in
    DG.add_vertex smg.graph v;
    Hashtbl.add smg.stations station_id v;
    Vector.push_back smg.names station_id;
    incr max_station
  in
  File.input_all (Gtfs.parse_stations aux) (gtfs_dir ^ "stops.csv") File.Csv;
  {smg with max_station = Some !max_station}

let parse_stop_times smg idx trips gtfs_dir : ttbl =
  let ttbl = Hashtbl.create 42 in
  let idx = ref idx in
  let post_incr () = let old = !idx in incr idx; old in

  let dummy_station = DG.V.create (-1) in
  let dummy_event = { tarr = -1; tdep = -1} in
  let dummy_stop = { events = Vector.make 1 dummy_event;
                     station = dummy_station; arr = -1; dep = -1} in

  let aux (Gtfs.{ trip_id; arrival; departure; station_id; stop_sequence }) =
    let route_id = Hashtbl.find trips trip_id in
    let event = {tarr = arrival; tdep = departure} in
    let new_stop seq =
      let station = Hashtbl.find smg.stations station_id in
      let stop = {events = Vector.make 1 dummy_event; station;
                  arr = post_incr (); dep = post_incr ()} in
      Vector.push_back stop.events event;
      Vector.push_back seq stop;
      let name = station_id ^ "_" ^ string_of_int route_id ^ "_" in
      Vector.push_back smg.names (name ^ "arr");
      Vector.push_back smg.names (name ^ "dep")
    in
    match Hashtbl.find_opt ttbl route_id with
    | None ->
       assert (stop_sequence = 1);
       let seq = Vector.make 1 dummy_stop in
       new_stop seq;
       Hashtbl.add ttbl route_id seq
    | Some seq ->
       if stop_sequence <= Vector.length seq then
         let stop = Vector.get seq (stop_sequence - 1) in
         Vector.push_back stop.events event
       else new_stop seq
  in
  File.input_all (Gtfs.parse_stop_times aux) (gtfs_dir ^ "stop_times.csv") File.Csv;
  ttbl

let output_ttbl ttbl =
  Hashtbl.iter (fun route_id ttbl_stop ->
      Printf.printf "route: %d\n" route_id;
      Vector.iteri (fun i {events; _} ->
          Printf.printf "%i:\n" i;
          Vector.iter (fun {tarr; tdep} -> Printf.printf "  %d:%d\n" tarr tdep) events
        ) ttbl_stop
    ) ttbl

let parse_transfers smg symmetrize gtfs_dir =
  let aux (Gtfs.{ departure; arrival; transfer }) =
    let departure = Hashtbl.find smg.stations departure in
    let arrival = Hashtbl.find smg.stations arrival in
    let e = DG.E.create departure transfer arrival in
    DG.add_edge_e smg.graph e;
    if symmetrize then
      let e = DG.E.create arrival transfer departure in
      DG.add_edge_e smg.graph e
  in
  File.input_all (Gtfs.parse_transfers aux) (gtfs_dir ^ "transfers.csv") File.Csv

let create gtfs_dir min_change_time =
  let smg = parse_stations {graph = DG.create ~size:42 (); max_station = None;
                            stations = Hashtbl.create 42;
                            names = Vector.make 1 ""} gtfs_dir in
  parse_transfers smg true gtfs_dir;
  let trips = parse_trips gtfs_dir in
  let ttbl = parse_stop_times smg (Option.get smg.max_station) trips gtfs_dir in
  let id = ref (Option.get smg.max_station) in
  let add_stop stop =
    let varr, vdep = DG.V.create !id, DG.V.create (!id + 1) in
    incr id; incr id;
    let t = Vector.fold_left (fun wait {tarr; tdep} -> min wait (tdep - tarr))
              max_int stop.events in
    let e = DG.E.create varr t vdep in
    DG.add_edge_e smg.graph e;
    let e1 = DG.E.create varr min_change_time stop.station in
    let e2 = DG.E.create stop.station min_change_time vdep in
    DG.add_edge_e smg.graph e1;
    DG.add_edge_e smg.graph e2;
    varr, vdep
  in
  let add_connection vdep varr prev curr =
    let t = Vector.fold_left2
              (fun wait {tdep; _} {tarr; _} -> min wait (tarr - tdep))
              max_int prev curr in
    let e = DG.E.create vdep t varr in
    DG.add_edge_e smg.graph e
  in
  Hashtbl.iter (fun route_id stops ->
      ignore (Vector.fold_left (fun prev stop ->
                  match prev with
          | None -> Some (add_stop stop, stop)
          | Some ((prev_arr, prev_dep), prev) ->
             let stop_arr, stop_dep = add_stop stop in
             add_connection prev_dep stop_arr prev.events stop.events;
             Some ((stop_arr, stop_dep), stop))
        None stops))
    ttbl;
  smg

let load path =
  let f = File.open_in path File.Tuples in
  let graph = DG.create ~size:128 () in
  let aux = function
    | [src; dst; wgt] ->
       let src, dst = DG.V.create (int_of_string src),
                      DG.V.create (int_of_string dst) in
       let wgt = int_of_string wgt in
       let e = DG.E.create src wgt dst in
       DG.add_edge_e graph e
    | _ -> failwith "Invalid format"
  in
  begin try while true do File.input_line aux f done
        with End_of_file -> () end;
  {graph; max_station = None; stations = Hashtbl.create 0; names = Vector.make 1 ""}

let output smg path =
  let oc = open_out path in
  DG.iter_edges_e (fun e ->
      let src = Vector.get smg.names (DG.E.src e |> DG.V.label) in
      let dst = Vector.get smg.names (DG.E.dst e |> DG.V.label) in
      Printf.fprintf oc "%s %s %d\n" src dst (DG.E.label e))
    smg.graph;
  close_out oc

let display_with_gv smg = DG.display_with_gv smg.graph
let dot_output smg f = DG.dot_output smg.graph f
