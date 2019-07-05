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

let lower_bound vec first last value cmp =
  assert (0 <= first && first <= last && last < vec.len);
  let left, right = ref first, ref last in
  while !left < !right do
    let mid = (!left + !right) / 2 in
    if cmp vec.data.(mid) value then
      left := mid + 1
    else
      right := mid
  done;
  if cmp vec.data.(!left) value then raise Exit else !left

let reverse vec =
  assert (vec.len <> 0);
  for i = 0 to (vec.len - 1) / 2 do
    let old = vec.data.(i) in
    vec.data.(i) <- vec.data.(vec.len - 1 - i);
    vec.data.(vec.len - 1 - i) <- old
  done

let copy vec = { vec with data = Array.copy vec.data; cap = vec.cap }
