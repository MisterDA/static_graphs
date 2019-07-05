type 'a t
val make : int -> 'a -> 'a t
val push_back : 'a t -> 'a -> unit
val get : 'a t -> int -> 'a
val set : 'a t -> int -> 'a -> unit
val length : 'a t -> int
val trim : 'a t -> unit
val iter : ('a -> unit) -> 'a t -> unit
val iteri : (int -> 'a -> unit) -> 'a t -> unit
val map : ('a -> 'b) -> 'a t -> 'b t
(* val mapi : (int -> 'a -> 'b) -> 'a t -> 'b t *)
val fold_left : ('a -> 'b -> 'a) -> 'a -> 'b t -> 'a
val fold_left2 : ('a -> 'b -> 'c -> 'a) -> 'a -> 'b t -> 'c t -> 'a

val lower_bound : 'a t -> int -> int -> 'b -> ('a -> 'b -> bool) -> int
val reverse : 'a t -> unit
val copy : 'a t -> 'a t
