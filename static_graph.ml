module DG = Graph.Pack.Digraph
module List = struct
  include List
  let unique = function
    | [] -> []
    | h :: t ->
       let rec aux (e, acc) = function
         | h :: t when e = h -> aux (e, acc) t
         | h :: t -> aux (h, h :: acc) t
         | [] -> acc
       in
       List.rev (aux (h, [h]) t)
end

exception No_common_hub

type ttbl_event = {tarr : Gtfs.time; tdep : Gtfs.time}
type ttbl_stop = {events : ttbl_event Vector.t;
                  arr : DG.V.t; dep : DG.V.t;
                  station : DG.V.t}
type ttbl = (Gtfs.route_id, ttbl_stop Vector.t) Hashtbl.t

type stop_type =
  | Arrival of Gtfs.route_id * int
  | Departure of Gtfs.route_id * int
  | Station

type t = {
    max_station : int option;
    graph : DG.t;
    names : string Vector.t;
    vertices : (DG.V.t * stop_type) Vector.t; (* to provide O(1) access *)
    mutable ttbl : ttbl option;
  }

type fn = Min | Max | Avg

let dummy_vertex = DG.V.create (-1)
let dummy_event = { tarr = -1; tdep = -1}
let dummy_stop = { events = Vector.make 1 dummy_event;
                   station = dummy_vertex;
                   arr = dummy_vertex; dep = dummy_vertex}

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
    Vector.push_back smg.vertices (v, Station);
    Vector.push_back smg.names station_id;
    incr max_station
  in
  File.input_all (Gtfs.parse_stations aux) (gtfs_dir ^ "stops.csv") File.Csv;
  {smg with max_station = Some !max_station}

let parse_stop_times smg idx trips start finish gtfs_dir : ttbl =
  let ttbl = Hashtbl.create 42 in
  let idx = ref idx in
  let post_incr () = let old = !idx in incr idx; old in

  let aux (Gtfs.{ trip_id; arrival; departure; station_id; stop_sequence }) =
    if arrival < start || finish < departure then ();
    let route_id = Hashtbl.find trips trip_id in
    let event = {tarr = arrival; tdep = departure} in
    let new_stop seq =
      let station, _ = Vector.get smg.vertices (int_of_string station_id) in
      let varrlbl = post_incr () in
      let vdeplbl = post_incr () in
      let varr, vdep = DG.V.create varrlbl, DG.V.create vdeplbl in
      DG.add_vertex smg.graph varr;
      DG.add_vertex smg.graph vdep;
      Vector.push_back smg.vertices (varr, Arrival (route_id, stop_sequence));
      Vector.push_back smg.vertices (vdep, Departure (route_id, stop_sequence));
      let stop = {events = Vector.make 1 dummy_event; station;
                  arr = varr; dep = vdep} in
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
       else
         new_stop seq
  in
  File.input_all (Gtfs.parse_stop_times aux) (gtfs_dir ^ "stop_times.csv") File.Csv;

  let compare {tarr; _} {tarr=tarr'; _} = compare tarr tarr' in
  Hashtbl.iter (fun _ stops ->
      Vector.iter (fun {events; _} ->
          Vector.trim events;
          Vector.sort compare events) stops)
    ttbl;
  ttbl

(* let print_ttbl ttbl =
 *   Hashtbl.iter (fun route_id ttbl_stop ->
 *       Printf.printf "route: %d\n" route_id;
 *       Vector.iteri (fun i {events; _} ->
 *           Printf.printf "%i:\n" i;
 *           Vector.iter (fun {tarr; tdep} -> Printf.printf "  %d:%d\n" tarr tdep) events)
 *         ttbl_stop)
 *     ttbl *)

let parse_transfers smg symmetrize gtfs_dir =
  let aux (Gtfs.{ departure; arrival; transfer }) =
    let departure, arrival = int_of_string departure, int_of_string arrival in
    if departure = arrival then (); (* remove self loops *)
    let departure, _ = Vector.get smg.vertices departure in
    let arrival, _ = Vector.get smg.vertices arrival in
    let e = DG.E.create departure transfer arrival in
    DG.add_edge_e smg.graph e;
    if symmetrize then
      let e = DG.E.create arrival transfer departure in
      DG.add_edge_e smg.graph e
  in
  File.input_all (Gtfs.parse_transfers aux) (gtfs_dir ^ "transfers.csv") File.Csv

let create gtfs_dir min_change_time fn ~start ~finish =
  let fn', fn0 = match fn with
      Min -> min, max_int | Max -> max, min_int | Avg -> ( + ), 0 in
  let smg = parse_stations {graph = DG.create ~size:42 (); max_station = None;
                            names = Vector.make 1 "";
                            vertices = Vector.make 1 (dummy_vertex, Station);
                            ttbl = None;}
              gtfs_dir in
  parse_transfers smg true gtfs_dir;
  let trips = parse_trips gtfs_dir in
  let ttbl = parse_stop_times smg (Option.get smg.max_station) trips start finish gtfs_dir in
  smg.ttbl <- Some ttbl;
  let add_stop stop =
    let t = Vector.fold_left (fun wait {tarr; tdep} -> fn' wait (tdep - tarr))
              fn0 stop.events in
    let t = if fn = Avg then t / (Vector.length stop.events) else t in
    let e = DG.E.create stop.arr t stop.dep in
    DG.add_edge_e smg.graph e;
    let e1 = DG.E.create stop.arr min_change_time stop.station in
    let e2 = DG.E.create stop.station min_change_time stop.dep in
    DG.add_edge_e smg.graph e1;
    DG.add_edge_e smg.graph e2;
    stop.arr, stop.dep
  in
  let add_connection vdep varr prev curr =
    let t = Vector.fold_left2
              (fun wait {tdep; _} {tarr; _} -> fn' wait (tarr - tdep))
              fn0 prev curr in
    let t = if fn = Avg then t / (Vector.length prev) else t in
    let e = DG.E.create vdep t varr in
    DG.add_edge_e smg.graph e
  in
  Hashtbl.iter (fun _ stops ->
      ignore (Vector.fold_left (fun prev stop ->
                  match prev with
                  | None -> Some (add_stop stop, stop)
                  | Some ((_, prev_dep), prev) ->
                     let stop_arr, stop_dep = add_stop stop in
                     add_connection prev_dep stop_arr prev.events stop.events;
                     Some ((stop_arr, stop_dep), stop))
                None stops))
    ttbl;
  smg

(* let load path =
 *   let f = File.open_in path File.Tuples in
 *   let graph = DG.create ~size:128 () in
 *   let aux = function
 *     | [src; dst; wgt] ->
 *        let src, dst = DG.V.create (int_of_string src),
 *                       DG.V.create (int_of_string dst) in
 *        let wgt = int_of_string wgt in
 *        let e = DG.E.create src wgt dst in
 *        DG.add_edge_e graph e
 *     | _ -> failwith "Invalid format"
 *   in
 *   begin try while true do File.input_line aux f done
 *         with End_of_file -> () end;
 *   {graph; max_station = None; names = Vector.make 1 "";
 *    vertices = Vector.make 1 (dummy_vertex, Station);
 *    ttbl = None; } *)

let pretty_name smg v = Vector.get smg.names (DG.V.label v)

let output_pretty smg path =
  let oc = open_out path in
  DG.iter_edges_e (fun e ->
      let src = pretty_name smg (DG.E.src e) in
      let dst = pretty_name smg (DG.E.dst e) in
      Printf.fprintf oc "%s %s %d\n" src dst (DG.E.label e))
    smg.graph;
  close_out oc

let output smg path =
  let oc = open_out path in
  DG.iter_edges_e (fun e ->
      let src = DG.E.src e |> DG.V.label in
      let dst = DG.E.dst e |> DG.V.label in
      Printf.fprintf oc "%d %d %d\n" src dst (DG.E.label e))
    smg.graph;
  close_out oc

let display_with_gv smg = DG.display_with_gv smg.graph
let dot_output smg f = DG.dot_output smg.graph f

type hub_label = { hub : DG.V.t; next_hop : DG.V.t; length : int }
type hubs = (DG.V.t, hub_label Vector.t) Hashtbl.t
let dummy_label = { hub = dummy_vertex; next_hop = dummy_vertex; length = -1 }

let hl_input smg path : hubs * hubs =
  let outhubs, inhubs = Hashtbl.create 42, Hashtbl.create 42 in
  let find_vertex v = Vector.get smg.vertices (int_of_string v) |> fst in
  let aux = function
    | [t; v1; nh; v2; length] ->
       let length = int_of_string length in
       let v1, nh, v2 = find_vertex v1, find_vertex nh, find_vertex v2 in
       let push hubs v label =
         match Hashtbl.find_opt hubs v with
         | None -> let vec = Vector.make 1 dummy_label in
                   Vector.push_back vec label;
                   Hashtbl.add hubs v vec
         | Some vec -> Vector.push_back vec label
       in
       if t = "o" then
         push outhubs v1 {hub = v2; next_hop = nh; length}
       else if t = "i" then
         push inhubs v2 {hub = v1; next_hop = nh; length}
       else invalid_arg "not a valid hub type."
    | _ -> invalid_arg "not a valid hub labeling line."
  in
  File.input_all aux path File.Tuples;
  outhubs, inhubs

(* let print_outhubs oc smg v outhubs =
 *   Vector.iter (fun {hub; next_hop; length} ->
 *       Printf.fprintf oc  "o %d:%s %d:%s %d:%s %d\n"
 *         (DG.V.label v) (pretty_name smg v)
 *         (DG.V.label next_hop) (pretty_name smg next_hop)
 *         (DG.V.label hub) (pretty_name smg hub)
 *         length)
 *     outhubs
 * let print_inhubs oc smg v inhubs =
 *   Vector.iter (fun {hub; next_hop; length} ->
 *       Printf.fprintf oc "i %d:%s %d:%s %d:%s %d\n"
 *         (DG.V.label hub) (pretty_name smg hub)
 *         (DG.V.label next_hop) (pretty_name smg next_hop)
 *         (DG.V.label v) (pretty_name smg v)
 *         length)
 *     inhubs
 * let print_hubs smg outhubs inhubs =
 *   let oc = stdout in
 *   Hashtbl.iter (print_inhubs oc smg) inhubs;
 *   Hashtbl.iter (print_outhubs oc smg) outhubs *)

let comparison smg (outhubs, inhubs) oc prefix (src, dst) (start, finish) =
  let src, dst = int_of_string src, int_of_string dst in
  let (src, _) = Vector.get smg.vertices src in
  let (dst, _) = Vector.get smg.vertices dst in

  let reachability src dst =
    let outlabels = Hashtbl.find outhubs src in
    let inlabels  = Hashtbl.find inhubs dst  in
    let outlabel, inlabel = ref None, ref None in
    let length = ref max_int in
    let f outlbl inlbl =
      let l = outlbl.length + inlbl.length in
      let shared = (DG.V.label outlbl.hub) = (DG.V.label inlbl.hub) in
      if shared && l <= !length then
        (outlabel := Some outlbl; inlabel := Some inlbl; length := l)
    in
    Vector.iter (fun outlbl ->
        Vector.iter (fun inlbl -> f outlbl inlbl) inlabels)
      outlabels;
    match !outlabel, !inlabel with
    | None, _ | _, None -> raise No_common_hub
    | Some outlabel, Some inlabel -> outlabel, inlabel
  in

  let find_label vec hub =
    let i = Option.get (Vector.find vec (fun hl -> hl.hub = hub)) in
    Vector.get vec i
  in

  let build_path src dst =
    let outlbl, inlbl = reachability src dst in
    assert (outlbl.hub = inlbl.hub);
    let hub = outlbl.hub in
    let rec push path lbl hubs =
      if lbl.next_hop <> hub then
        let nh = find_label (Hashtbl.find hubs lbl.next_hop) hub in
        push (lbl.next_hop :: path) nh hubs
      else path
    in
    List.rev_append (push [src] outlbl outhubs)
      (hub :: (push [dst] inlbl inhubs))
  in

  let is_station v = v < Option.get smg.max_station in

  let build_transfer_patterns path =
    let rec aux = function
      | tp, [] -> tp
      | tp, [dst] -> dst :: tp
      | h :: tp, v1 :: v2 :: path ->
         if h = v1 then aux (h :: tp, v2 :: path)
         else
           let lh, lv1, lv2 = DG.V.label h, DG.V.label v1, DG.V.label v2 in
           if is_station lh || is_station lv1 || is_station lv2 then
             aux (v1 :: h :: tp, v2 :: path)
           else
             aux (h :: tp, v2 :: path)
      | _ -> assert false
    in
    match path with
    | src :: _ -> aux ([src], path)
    | _ -> assert false
  in

  let get_vertices u v =
    Vector.get smg.vertices (DG.V.label u),
    Vector.get smg.vertices (DG.V.label v)
  in
  let events ttbl r seq = (Vector.get (Hashtbl.find ttbl r) (seq - 1)).events in
  let is_simple = ref true in   (* the graph is only transfers *)

  let earliest_arrival_time ttbl transfer_patterns deptime =
    let rec aux arrtime = function
      | [_] -> Some arrtime
      | u :: v :: tp ->
         let (_, ut), (_, vt) = get_vertices u v in
         begin match ut, vt with
         | Departure (ur, useq), Arrival (vr, vseq) ->
            assert (ur = vr);
            is_simple := false;
            let uevs, vevs = events ttbl ur useq, events ttbl vr vseq in
            let i = Vector.find_first uevs 0 (fun vec -> arrtime <= vec.tdep) in
            Option.bind i (fun i -> aux (Vector.get vevs i).tarr (v :: tp))
         | Station, Station | Station, Departure _ | Arrival _, Station ->
            let delay = DG.find_edge smg.graph u v |> DG.E.label in
            aux (arrtime + delay) (v :: tp)
         | _, _ -> assert false
         end
      | _ -> assert false
    in
    aux deptime transfer_patterns
  in

  let last_departure_time ttbl transfer_patterns_rev arrtime =
    let rec aux deptime = function
      | [_] -> Some deptime
      | v :: u :: tp ->
         let (_, ut), (_ , vt) = get_vertices u v in
         begin match ut, vt with
         | Departure (ur, useq), Arrival (vr, vseq) ->
            assert (ur = vr);
            let uevs, vevs = events ttbl ur useq, events ttbl vr vseq in
            let i = Vector.find_last vevs 0 (fun vec -> vec.tarr <= deptime)
            in Option.bind i (fun i -> aux (Vector.get uevs i).tdep (u :: tp))
         | Station, Station | Station, Departure _ | Arrival _, Station ->
            let delay = DG.find_edge smg.graph u v |> DG.E.label in
            aux (deptime - delay) (u :: tp)
         | _, _ -> assert false
         end
      | _ -> assert false
    in
    aux arrtime transfer_patterns_rev
  in

  (* let print_path path =
   *   List.iter (fun v ->
   *       Printf.printf "%d:%s -> " (DG.V.label v) (pretty_name smg v)) path;
   * in *)

  print_string "Building path…"; flush stdout;
  let path = build_path src dst in
  (* print_string " "; print_path path; *)
  print_string " done! Building transfer patterns…"; flush stdout;
  let tp_rev = build_transfer_patterns path in
  let tp = List.rev tp_rev in
  (* print_string " "; print_path tp; *)
  print_string " done! Building time profile…"; flush stdout;

  let rec build_time_profile (ldt', eat') deptime edt =
    match earliest_arrival_time (Option.get smg.ttbl) tp deptime with
    | None -> ()
    | Some eat ->
       match last_departure_time (Option.get smg.ttbl) tp_rev eat with
       | None -> ()
       | Some ldt when not (eat' = eat && ldt = ldt') ->
          output_string oc prefix;
          Printf.fprintf oc ",%d,%d,%d\n" edt ldt eat;
          if ldt <= finish then build_time_profile (ldt, eat) (ldt+1) ldt
       | _ -> ()
  in

  let eat = earliest_arrival_time (Option.get smg.ttbl) tp start in
  if !is_simple && Option.is_some eat then
    begin
      print_string " simple path"; flush stdout;
      output_string oc prefix;
      Printf.fprintf oc ",0,0,%d\n" (Option.get eat)
    end
  else
    build_time_profile (-1, -1) start start;
  print_endline " done!"
