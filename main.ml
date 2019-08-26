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
  let start, finish = ref min_int, ref max_int in

  let speclist = ref [] in
  let usage_msg = "Usage: graph <static_graph|comparison> gtfs_dir" in
  let anon =
    let sub = ref true in
    fun arg ->
    if !sub then
      begin
        sub := false;
        let common = [("-o", Arg.Set_string output, "<file> output time profiles");
                      ("-min-change-time", Arg.Set_int min_change_time, "<int> minimum change time");
                      ("-gv", Arg.Set_string gv, "<file> output GraphViz");
                      ("-fn", Arg.Set_string fn, "<min|max|avg> edges function");
                      ("-beg", Arg.Set_int start, "<time> minimum event time");
                      ("-end", Arg.Set_int finish, "<time> maximum event time");
                     ] in
        match arg with
        | "static_graph" ->
           speclist := common;
           subcommand := Some SubStatic_graph
        | "comparison" ->
           speclist :=  ("-hl", Arg.Set_string hubs, "<file> hub labeling file")
                        :: ("-query-file", Arg.Set_string queries, "<file> queries file")
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
     if !start = min_int then failwith "Did not specify the starting time";
     if !finish = max_int then failwith "Did not specify the finish time";
     let fn = Static_graph.(if !fn = "min" then Min
                            else if !fn = "max" then Max
                            else if !fn = "avg" then Avg
                            else failwith "Wrong edge function.") in
     match c with
     | SubStatic_graph ->
        let smg = Static_graph.create !gtfs_dir !min_change_time fn
                    ~start:!start ~finish:!finish in
        if !gv <> "" then Static_graph.dot_output smg !gv;
        Static_graph.output smg !output
     | SubComparison ->
        if !hubs = "" then failwith "Did not specify hub labeling file.";
        let smg = Static_graph.create !gtfs_dir !min_change_time fn
                    ~start:!start ~finish:!finish in
        if !gv <> "" then Static_graph.dot_output smg !gv;
        print_endline "Graph generation done.";
        let hubs = Static_graph.hl_input smg !hubs in
        print_endline "Hubs loaded.";
        Gc.compact ();
        let oc = open_out !output in
        output_string oc "query,edt,ldt,eat\n";
        let n = ref 1 in
        print_endline "Starting…";
        let aux = function
          | [src; dst; _; _; _; _] ->
             Printf.printf "Query #%d: " !n; flush stdout;
             begin try Static_graph.comparison smg hubs oc (string_of_int !n) (src, dst) (!start, !finish);
             with Static_graph.No_common_hub ->
               prerr_endline "No common hub found.";
               Printf.fprintf oc "%d,0,0,0\n" !n
             end;
             flush oc;
             if !n = !nq then raise Exit;
             incr n
          | _ -> invalid_arg "invalid query line."
        in
        try File.input_all aux (!gtfs_dir ^ !queries) Csv with Exit -> ();
        close_out oc

let () = main ()
