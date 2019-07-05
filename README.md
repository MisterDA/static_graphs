# Static Minimum Graphs Experiment

Antonin Décimo\
OCaml >= 4.07

``` sh
make
export OCAMLRUNPARAM=b	# for backtraces
./main.native static_min_graph -o output.gr ./small/
./hltrans hubs-next-hop output.gr > ./small/output.hl
./main.native comparison -o output.gr ./small/
```
