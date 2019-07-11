type t
type hubs

type fn = Min | Max | Avg
val create : string -> int -> fn -> start:int -> finish:int -> t
val hl_input : t -> string -> (hubs * hubs)
val comparison : t -> (hubs * hubs) -> (out_channel -> string -> string -> string -> int -> unit)

val output : t -> string -> unit
val output_pretty : t -> string -> unit
val display_with_gv : t -> unit
val dot_output : t -> string -> unit

(* val load : string -> t *)
