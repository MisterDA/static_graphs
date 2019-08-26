HLTRANS=../big-graph-tools/cpp/hltrans
RAPTOR=../hl-csa-raptor/simple_raptor.o
MAIN=_build/default/main.exe
LONDON=../files.inria.fr/London

MIN_CHANGE_TIME=0
QUERIES=queries-rank.csv
T_BEGIN=25200
T_END=32400

OPTS=-min-change-time=$(MIN_CHANGE_TIME) -beg=$(T_BEGIN) -end=$(T_END)
CMPOPTS=-query-file=$(QUERIES) $(OPTS)

build: main hltrans simple_raptor

main:
	dune build main.exe --profile release
hltrans:
	$(MAKE) -C ../big-graph-tools/cpp hltrans
simple_raptor:
	$(MAKE) -C ../hl-csa-raptor simple_raptor
clean:
	dune clean

plots: min max avg raptor
	mkdir -p plots
	pypy3 ./plotter.py			\
		-delays $(LONDON)/delays.csv	\
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
	$(MAIN) static_graph $(OPTS) -fn min -o $@ $(LONDON)/
$(LONDON)/static_min_graph.hl: $(LONDON)/static_min_graph.gr
	$(HLTRANS) hubs-next-hop $< > $@
$(LONDON)/static_min_graph.tp: $(LONDON)/static_min_graph.hl
	$(MAIN) comparison $(CMPOPTS) -fn min -o $@ -hl $< $(LONDON)/
min: build $(LONDON)/static_min_graph.tp

$(LONDON)/static_max_graph.gr:
	$(MAIN) static_graph $(OPTS) -fn max -o $@ $(LONDON)/
$(LONDON)/static_max_graph.hl: $(LONDON)/static_max_graph.gr
	$(HLTRANS) hubs-next-hop $< > $@
$(LONDON)/static_max_graph.tp: $(LONDON)/static_max_graph.hl
	$(MAIN) comparison $(CMPOPTS) -fn max -o $@ -hl $< $(LONDON)/
max: build $(LONDON)/static_max_graph.tp

$(LONDON)/static_avg_graph.gr:
	$(MAIN) static_graph $(OPTS) -fn avg -o $@ $(LONDON)/
$(LONDON)/static_avg_graph.hl: $(LONDON)/static_avg_graph.gr
	$(HLTRANS) hubs-next-hop $< > $@
$(LONDON)/static_avg_graph.tp: $(LONDON)/static_avg_graph.hl
	$(MAIN) comparison $(CMPOPTS) -fn avg -o $@ -hl $< $(LONDON)/
avg: build $(LONDON)/static_avg_graph.tp

clean_timeprofiles:
	$(RM) -r $(LONDON)/*.tp
clean_hubs: clean_timeprofiles
	$(RM) -r $(LONDON)/*.hl
clean_graphs: clean_hubs
	$(RM) -r $(LONDON)/*.gr

$(LONDON)/raptor.csv:
	$(RAPTOR) $(CMPOPTS) -o=$(LONDON)/raptor.csv $(LONDON)/
raptor: $(LONDON)/raptor.csv
clean_raptor:
	$(RM) -r $(LONDON)/raptor.csv

.SECONDARY:
.PHONY: build main hltrans simple_raptor clean min max avg plots raptor
