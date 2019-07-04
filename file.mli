type t
type format = Csv | Tuples
val open_in : string -> format -> t
val close_in : t -> unit
val input_line : (string list -> unit) -> t -> unit
val input_all : (string list -> unit) -> string -> format -> unit
