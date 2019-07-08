type t
val create : string -> int -> t
val load : string -> t
val output : t -> string -> unit
val display_with_gv : t -> unit
val dot_output : t -> string -> unit
val comparison : t -> string -> string -> (Gtfs.time * Gtfs.time * Gtfs.time) list
