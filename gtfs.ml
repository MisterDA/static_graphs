type station_id = string
type time = int
type trip_id = int
type route_id = int

type stop_times = { trip_id : trip_id; arrival : time; departure : time;
                    station_id : station_id; stop_sequence : int }

let print_stop_times st =
  Printf.printf "%d,%d,%d,%s,%d\n" st.trip_id st.arrival st.departure
    st.station_id st.stop_sequence

let parse_stop_times f l =
  try match l with
      | [trip_id; arrival; departure; station_id; stop_sequence] ->
         { trip_id = int_of_string trip_id; arrival = int_of_string arrival;
           departure = int_of_string departure; station_id;
           stop_sequence = int_of_string stop_sequence } |> f
      | _ -> raise (Failure "was not a correct line of stop_times")
  with Failure e -> raise (Failure (String.concat "," l ^ "\n" ^ e))

type stations = { station_id : station_id }
let parse_stations f l =
  try match l with
  | [station_id] -> f {station_id}
  | _ -> raise (Failure "was not a correct line of stops")
  with Failure e -> raise (Failure (String.concat "," l ^ "\n" ^ e))

type trips = { route_id : route_id; trip_id : trip_id }
let parse_trips f l =
  try match l with
  | [route_id; trip_id] -> f { route_id = int_of_string route_id;
                               trip_id = int_of_string trip_id }
  | _ -> raise (Failure "was not a correct line of trips")
  with Failure e -> raise (Failure (String.concat "," l ^ "\n" ^ e))

type transfers = { departure : station_id; arrival : station_id;
                   transfer : time }
let parse_transfers f l =
  try match l with
  | [departure; arrival; transfer] -> f { departure; arrival;
                                          transfer = int_of_string transfer }
  | _ -> raise (Failure "was not a correct line of transfers")
with Failure e -> raise (Failure (String.concat "," l ^ "\n" ^ e))
