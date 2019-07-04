type station_id = string
type time = int
type trip_id = int
type route_id = int

type stop_times = { trip_id : trip_id; arrival : time; departure : time;
                    station_id : station_id; stop_sequence : int }
val parse_stop_times : (stop_times -> unit) -> string list -> unit

type stations = { station_id : station_id }
val parse_stations : (stations -> unit) -> string list -> unit

type trips = { route_id : route_id; trip_id : trip_id }
val parse_trips : (trips -> unit) -> string list -> unit

type transfers = { departure : station_id; arrival : station_id;
                   transfer : time }
val parse_transfers : (transfers -> unit) -> string list -> unit
