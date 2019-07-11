HLTRANS=../big-graph-tools/cpp/hltrans
MAIN=_build/default/main.exe

build: main hltrans

main:
	dune build main.exe --profile release
hltrans:
	$(MAKE) -C ../big-graph-tools/cpp hltrans
clean:
	dune clean

LONDON=../files.inria.fr/London

$(LONDON)/static_min_graph.gr:
	$(MAIN) static_graph -fn min -o $@ $(LONDON)/
$(LONDON)/static_min_graph.hl: $(LONDON)/static_min_graph.gr
	$(HLTRANS) hubs-next-hop $< > $@
$(LONDON)/static_min_graph.tp: $(LONDON)/static_min_graph.hl
	$(MAIN) comparison -fn min -o $@ -q queries-rank.csv -hl $< $(LONDON)/
min: build $(LONDON)/static_min_graph.tp

$(LONDON)/static_max_graph.gr:
	$(MAIN) static_graph -fn max -o $@ $(LONDON)/
$(LONDON)/static_max_graph.hl:  $(LONDON)/static_max_graph.gr
	$(HLTRANS) hubs-next-hop $< > $@
$(LONDON)/static_max_graph.tp: $(LONDON)/static_max_graph.hl
	$(MAIN) comparison -fn max -o $@ -q queries-rank.csv -hl $< $(LONDON)/
max: build $(LONDON)/static_max_graph.tp

$(LONDON)/static_avg_graph.gr:
	$(MAIN) static_graph -fn avg -o $@ $(LONDON)/
$(LONDON)/static_avg_graph.hl: $(LONDON)/static_avg_graph.gr
	$(HLTRANS) hubs-next-hop $< > $@
$(LONDON)/static_avg_graph.tp: $(LONDON)/static_avg_graph.hl
	$(MAIN) comparison -fn avg -o $@ -q queries-rank.csv -hl $< $(LONDON)/
avg: build $(LONDON)/static_avg_graph.tp

.SECONDARY:
.PHONY: build main hltrans clean min max avg
