module Bytes' = Bytes
module Bytes = struct
  include Bytes'
  let index_from_upto buf start len c =
    let idx = ref (-1) in
    try
      for i = start to len - 1 do
        if Bytes.get buf i = c then (idx := i; raise Exit)
      done;
      None
    with Exit -> Some (!idx)
  let print buf = Seq.iter (fun c -> print_char c) (Bytes.to_seq buf)
  let print_upto buf len =
    for i = 0 to min (Bytes.length buf) len - 1 do
      print_char (Bytes.get buf i)
    done
end

type format = Csv | Tuples
type buf = { mutable buf : bytes; mutable len : int; mutable cap : int}
type t =
  | File of Stdlib.in_channel * format
  | Gzip of Gzip.in_channel * buf * format

let split fmt line =
  String.split_on_char (match fmt with Csv -> ',' | Tuples -> ' ') line

let input_line parse = function
  | File (chan, fmt) ->
     let line = input_line chan in
     let last = String.length line - 1 in
     (if String.get line last = '\r' then String.sub line 0 last else line)
     |> split fmt |> parse
  | Gzip (chan, b, fmt) ->
     let str = ref None in
     while !str = None do
       match Bytes.index_from_upto b.buf 0 b.len '\n' with
       | None ->
          b.len <- b.len + Gzip.input chan b.buf b.len (b.cap - b.len);
          if b.len = 0 then raise End_of_file;
       | Some i when i > 0 && Bytes.get b.buf (i-1) = '\r' ->
          str := Some (Bytes.sub_string b.buf 0 (i-1));
          b.len <- b.len - i;
          Bytes.print_upto b.buf b.len;
          if b.len > 0 then Bytes.blit b.buf (i+1) b.buf 0 b.len
       | Some i ->
          str := Some (Bytes.sub_string b.buf 0 i);
          b.len <- b.len - (i+1);
          if b.len > 0 then Bytes.blit b.buf (i+1) b.buf 0 b.len
     done;
     match !str with
     | None -> assert false
     | Some str -> let () = split fmt str |> parse in ()

let open_in path fmt =
  let n = String.length path in
  let f = begin
      if String.sub path (n - 3) 3 = ".gz" then
        try Gzip (Gzip.open_in path,
                  {buf = Bytes.create 256; len = 0; cap = 256}, fmt)
        with e -> File (open_in (String.sub path 0 (n - 3)), fmt)
      else
        try Gzip (Gzip.open_in (path ^ ".gz"),
                  {buf = Bytes.create 256; len = 0; cap = 256}, fmt)
        with e -> File (open_in path, fmt)
    end in
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
