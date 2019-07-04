all:
	ocamlbuild -use-ocamlfind -pkgs 'ocamlgraph,zip' main.native
clean:
	ocamlbuild -clean

.PHONY: all clean
