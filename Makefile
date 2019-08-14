HLTRANS=../big-graph-tools/cpp/hltrans
RAPTOR=../hl-cas-raptor/simple_raptor.o
MAIN=_build/default/main.exe

build: main hltrans

main:
	dune build main.exe --profile release
hltrans:
	$(MAKE) -C ../big-graph-tools/cpp hltrans
simple_raptor:
	$(MAKE) -C ../hl-csa-raptor simple_raptor
clean:
	dune clean

LONDON=../files.inria.fr/London

plots: min max avg raptor
	mkdir -p plots
	pypy3 ./plotter.py			\
		$(LONDON)/raptor.csv		\
		$(LONDON)/static_min_graph.tp	\
		$(LONDON)/static_max_graph.tp 	\
		$(LONDON)/static_avg_graph.tp 	\
		$(LONDON)/queries-rank.csv

clean_plots:
	$(RM) -r plots.* plots/ plots-min/

plots_minimize:
	mkdir -p plots-min
	cd plots;							  \
	for file in *.svg; do						  \
		svgcleaner "$$file" "../plots-min/$${file%.svg}.min.svg"; \
	done

$(LONDON)/static_min_graph.gr:
	$(MAIN) static_graph -fn min -o $@ $(LONDON)/
$(LONDON)/static_min_graph.hl: $(LONDON)/static_min_graph.gr
	$(HLTRANS) hubs-next-hop $< > $@
$(LONDON)/static_min_graph.tp: $(LONDON)/static_min_graph.hl
	$(MAIN) comparison -fn min -o $@ -q queries-rank.csv -hl $< $(LONDON)/
min: build $(LONDON)/static_min_graph.tp

$(LONDON)/static_max_graph.gr:
	$(MAIN) static_graph -fn max -o $@ $(LONDON)/
$(LONDON)/static_max_graph.hl: $(LONDON)/static_max_graph.gr
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

clean_timeprofiles:
	$(RM) -r $(LONDON)/*.tp
clean_hubs: clean_timeprofiles
	$(RM) -r $(LONDON)/*.hl
clean_graphs: clean_hubs
	$(RM) -r $(LONDON)/*.gr

$(LONDON)/raptor.csv:
	$(RAPTOR) -query-file=queries-rank.csv -o=$(LONDON)/raptor.csv $(LONDON)/
raptor: $(LONDON)/raptor.csv

.SECONDARY:
.PHONY: build main hltrans simple_raptor clean min max avg plots raptor
