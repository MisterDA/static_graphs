(* module Bytes = struct
 *   include Bytes
 *
 *   (\* let index_from_upto buf start len c =
 *    *   let idx = ref (-1) in
 *    *   try
 *    *     for i = start to len - 1 do
 *    *       if Bytes.get buf i = c then (idx := i; raise Exit)
 *    *     done;
 *    *     None
 *    *   with Exit -> Some (!idx) *\)
 *
 *   (\* let print buf = Seq.iter (fun c -> print_char c) (Bytes.to_seq buf) *\)
 *   (\* let print_upto buf len =
 *    *   for i = 0 to min (Bytes.length buf) len - 1 do
 *    *     print_char (Bytes.get buf i)
 *    *   done *\)
 * end *)

let cap = 200_000_000 (* 200 megabytes *)

type format = Csv | Tuples
type t =
  | File of Stdlib.in_channel * format
  | Gzip of Gzip.in_channel * (bytes * int ref) * format

let split fmt line =
  String.split_on_char (match fmt with Csv -> ',' | Tuples -> ' ') line

let input_line parse f =
  match f with
  | File (chan, fmt) ->
     let line = input_line chan in
     let last = String.length line - 1 in
     (if String.get line last = '\r' then String.sub line 0 last else line)
     |> split fmt |> parse
  | Gzip (_, (s, cur), fmt) ->
     let i = Bytes.index_from s !cur '\n' in
     let j = if Bytes.get s (i - 1) = '\r' then i - 1 else i in
     let str = Bytes.sub_string s !cur (j - !cur) in
     print_endline str;
     cur := i + 1;
     split fmt str |> parse

let open_in path fmt =
  let n = String.length path in
  let f =
    if String.sub path (n - 3) 3 = ".gz" then
      try Gzip (Gzip.open_in path, (Bytes.create cap, ref 0), fmt)
      with _ -> File (open_in (String.sub path 0 (n - 3)), fmt)
    else
      try
        let path = path ^ ".gz" in
        Gzip (Gzip.open_in path, (Bytes.create cap, ref 0), fmt)
      with _ -> File (open_in path, fmt)
  in
  begin match f with
    | Gzip (chan, (s, _), _) ->
       begin try Gzip.really_input chan s 0 cap;
                 failwith "Not enough buffer allocated."
             with End_of_file -> () end;
    | File _ -> ()
  end;
  match fmt with
  | Tuples -> f
  | Csv -> input_line (fun _ -> ()) f; f

let close_in = function
    File (f, _) -> close_in f | Gzip (f, _, _) -> Gzip.close_in f

let input_all f path fmt =
  let ic = open_in path fmt in
  begin
    let line = ref 1 in
    try
      while true do
        input_line f ic;
        incr line
      done
    with End_of_file -> ()
       | Failure e ->
          let e = path ^ " at line " ^ string_of_int !line ^ ": " ^ e in
          raise (Failure e)
       | Exit -> raise Exit
       | e ->
          Printf.eprintf "%s at line %d\n" path !line;
          raise e
  end;
  close_in ic;
