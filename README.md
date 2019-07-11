# Static Minimum Graphs Experiment

Antonin Décimo\
OCaml >= 4.08

``` sh
opam install ocamlgraph camlzip dune
git clone https://github.com/MisterDA/static_graphs.git
git clone https://github.com/MisterDA/big-graph-tools.git
git clone https://github.com/MisterDA/hl-csa-raptor.git
# Have all files from here in files.inria.fr/London
# https://files.inria.fr/gang/graphs/public_transport/London/index.html
cd static_graphs
make build
make min # max avg
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
