type subcommand = SubStatic_graph | SubComparison

let main () =
  let output = ref "" in
  let gtfs_dir = ref "" in
  let subcommand = ref None in
  let min_change_time = ref 30 in
  let queries = ref "queries-ranked.csv" in
  let nq = ref (-1) in
  let hubs = ref "" in
  let gv = ref "" in
  let fn = ref "min" in

  let speclist = ref [] in
  let usage_msg = "Usage: graph <static_min_graph|comparison> gtfs_dir" in
  let anon =
    let sub = ref true in
    fun arg ->
    if !sub then
      begin
        sub := false;
        let common = [("-o", Arg.Set_string output, "<file> output time profiles");
                      ("-chg", Arg.Set_int min_change_time, "<int> minimum change time");
                      ("-gv", Arg.Set_string gv, "<file> output GraphViz");
                      ("-fn", Arg.Set_string fn, "<min|max|avg> edges function");
                     ] in
        match arg with
        | "static_min_graph" ->
           speclist := common;
           subcommand := Some SubStatic_graph
        | "comparison" ->
           speclist :=  ("-hl", Arg.Set_string hubs, "<file> hub labeling file")
                        :: ("-q", Arg.Set_string queries, "<file> queries file")
                        :: ("-nq", Arg.Set_int nq, "<int> number of queries")
                        :: common;
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
     if !gtfs_dir = "" then failwith "Did not specify gtfs directory.";
     let fn = Static_graph.(if !fn = "min" then Min
                            else if !fn = "max" then Max
                            else if !fn = "avg" then Avg
                            else failwith "Wrong edge function.") in
     match c with
     | SubStatic_graph ->
        let smg = Static_graph.create !gtfs_dir !min_change_time fn in
        if !gv <> "" then Static_graph.dot_output smg !gv;
        Static_graph.output smg !output
     | SubComparison ->
        if !hubs = "" then failwith "Did not specify hub labeling file.";
        let smg = Static_graph.create !gtfs_dir !min_change_time fn in
        print_endline "Graph generation done.";
        if !gv <> "" then Static_graph.dot_output smg !gv;
        let f = Static_graph.comparison smg !hubs in
        let oc = open_out !output in
        output_string oc "query,edt,ldt,eat\n";
        let n = ref 1 in
        let aux = function
          | [src; dst; deptime; _; _; _] ->
             Printf.printf "query #%d…\n" !n;
             f oc (string_of_int !n) src dst (int_of_string deptime);
             flush oc;
             if !n = !nq then raise Exit;
             incr n
          | _ -> invalid_arg "invalid query line."
        in
        try File.input_all aux (!gtfs_dir ^ !queries) Csv with Exit -> ();
        close_out oc

let () = main ()
