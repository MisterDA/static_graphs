native:
	ocamlbuild -use-ocamlfind -pkgs 'ocamlgraph,zip' main.native
byte:
	ocamlbuild -use-ocamlfind -pkgs 'ocamlgraph,zip' -tag debug main.byte
clean:
	ocamlbuild -clean

.PHONY: all clean
