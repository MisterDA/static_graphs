type 'a t = { mutable data : 'a array;
              mutable len : int;
              mutable cap : int;
              default : 'a
            }

let make cap default =
  let cap = if cap = 0 then 1 else cap in
  { data = Array.make cap default; len = 0; cap; default }

let set {data; _} i x = data.(i) <- x
let get {data; _} i = data.(i)
let length {len; _} = len

let push_back vec x =
  if vec.len = vec.cap then
    begin
      vec.data <- Array.append vec.data (Array.make vec.cap vec.default);
      vec.cap <- vec.cap * 2
    end;
  set vec vec.len x;
  vec.len <- vec.len + 1

let trim vec =
  vec.data <- Array.sub vec.data 0 vec.len;
  vec.cap <- vec.len

let sort cmp vec = Array.fast_sort cmp vec.data

let iter f vec =
  for i = 0 to vec.len - 1 do
    f vec.data.(i)
  done

let iteri f vec =
  for i = 0 to vec.len - 1 do
    f i vec.data.(i)
  done

let map f vec =
  let default = f vec.default in
  let data = Array.make vec.len default in
  for i = 0 to vec.len - 1 do
    data.(i) <- f vec.data.(i)
  done;
  {data; len = vec.len; cap = vec.len; default }

(* let mapi f vec =
 *   let data = Array.make vec.len (f (-1) vec.default) in
 *   for i = 0 to vec.len - 1 do
 *     data.(i) <- f i vec.data.(i)
 *   done;
 *   {vec with cap = vec.len; data} *)

let fold_left f a vec =
  let a = ref a in
  for i = 0 to vec.len - 1 do
    a := f !a vec.data.(i)
  done;
  !a

let fold_left2 f a vec1 vec2 =
  let a = ref a in
  assert (vec1.len = vec2.len);
  for i = 0 to vec1.len - 1 do
    a := f !a vec1.data.(i) vec2.data.(i)
  done;
  !a

   (*     ForwardIt it;
    typename std::iterator_traits<ForwardIt>::difference_type count, step;
    count = std::distance(first, last);

    while (count > 0) {
        it = first;
        step = count / 2;
        std::advance(it, step);
        if (comp(*it, value)) {
            first = ++it;
            count -= step + 1;
        }
        else
            count = step;
    }
    return first; *) *)

let lower_bound vec first last p =
  let first, count = ref first, ref (last - first) in
  while !count > 0 do
    let step = !count / 2 in
    let it = !first + step in
    if p vec.data.(it) then
      (first := it + 1; count := !count - (step + 1))
    else
      count := step
  done;
  !first

let find vec p =
  let rec aux i =
    if i < vec.len then
      if p vec.data.(i) then Some i else aux (i+1)
    else None
  in
  aux 0

let find_first vec first p =
  let p = fun v -> not (p v) in
  if p vec.data.(vec.len - 1) then None
  else Some (lower_bound vec first (vec.len - 1) p)

let find_last vec first p =
  if p vec.data.(vec.len - 1) then Some (vec.len - 1) else
  match lower_bound vec first (vec.len - 1) p  with
  | 0 -> None
  | i -> Some (i - 1)

let reverse vec =
  assert (vec.len <> 0);
  for i = 0 to (vec.len - 1) / 2 do
    let old = vec.data.(i) in
    vec.data.(i) <- vec.data.(vec.len - 1 - i);
    vec.data.(vec.len - 1 - i) <- old
  done

let copy vec = { vec with data = Array.copy vec.data; cap = vec.cap }
