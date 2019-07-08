module Smg = Static_min_graph

type subcommand = SubStatic_min_graph | SubComparison

let main () =
  let output = ref "" in
  let gtfs_dir = ref "" in
  let subcommand = ref None in
  let min_change_time = ref 30 in

  let speclist = ref [] in
  let usage_msg = "Usage: graph <subcommand> -o output gtfs_dir" in
  let anon =
    let sub = ref true in
    fun arg ->
    if !sub then
      begin
        sub := false;
        match arg with
        | "static_min_graph" ->
           speclist := [("-o", Arg.Set_string output, "output graph");
                        ("-chg", Arg.Set_int min_change_time, "minimum change time")];
           subcommand := Some SubStatic_min_graph
        | "comparison" ->
           speclist := [("-o", Arg.Set_string output, "output graph");
                        ("-chg", Arg.Set_int min_change_time, "minimum change time")];
           subcommand := Some SubComparison
        | _ -> failwith "Unrecognized subcommand."
      end
    else
      let gtfs = ref true in
      if !gtfs then
        begin
          gtfs := false;
          gtfs_dir := arg
        end
      else failwith "Too many arguments."
  in
  Arg.parse_dynamic speclist anon usage_msg;
  match !subcommand with
  | None -> failwith "Did not specify subcommand."
  | Some c ->
     if !output = "" then failwith "Did not specify output file.";
     if !gtfs_dir = "" then failwith "Did not specify gtfs directory";
     match c with
     | SubStatic_min_graph ->
        let smg = Static_min_graph.create !gtfs_dir !min_change_time in
        Static_min_graph.dot_output smg "output.gv";
        Static_min_graph.output smg !output
     | SubComparison ->
        let smg = Static_min_graph.create !gtfs_dir !min_change_time in
        Static_min_graph.dot_output smg "output.gv";
        let bkps = Static_min_graph.comparison smg !output !gtfs_dir in
        List.iter (fun (odep, dep, arr) ->
            Printf.printf "TP(%d, %d) := %d\n" odep dep arr) bkps


let () = main ()
