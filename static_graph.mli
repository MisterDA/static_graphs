type t
type fn = Min | Max | Avg
val create : string -> int -> fn -> start:int -> finish:int -> t
val load : string -> t
val output : t -> string -> unit
val output_pretty : t -> string -> unit
val display_with_gv : t -> unit
val dot_output : t -> string -> unit
val comparison : t -> string -> (out_channel -> string -> string -> string -> int -> unit)
