# Static Minimum Graphs Experiment

Antonin Décimo\
OCaml >= 4.08

``` sh
opam install ocamlgraph camlzip ocamlbuild
make
export OCAMLRUNPARAM=b	# for backtraces
./main.native static_min_graph -o output.gr small/
./hltrans hubs-next-hop output.gr > small/output.hl
./main.native comparison -o output.tp -q queries.csv small/
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
