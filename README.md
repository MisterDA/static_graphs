# Static Minimum Graphs Experiment

Antonin Décimo\
OCaml >= 4.08

``` sh
opam install ocamlgraph camlzip dune
dune build main.exe --profile release
ln -snf _build/default/main.exe main
./main static_min_graph -o output.gr small/
./hltrans hubs-next-hop output.gr > output.hl
./main comparison -o output.tp -q queries.csv -hl output.hl small/
```

``` text
small
├── output.gr	# graph
├── output.hl	# hub-labeling
├── output.tp	# time profiles
⋮
├── queries.csv
├── stops.csv
├── stop_times.csv
├── transfers.csv
└── trips.csv
```
