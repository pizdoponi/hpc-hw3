LATEXMK ?= latexmk
LATEXMK_FLAGS ?= -pdf -interaction=nonstopmode -halt-on-error

.PHONY: all assets clean

all: assets
	$(LATEXMK) $(LATEXMK_FLAGS) main.tex

assets:
	python3 generate_report_assets.py

clean:
	rm -f *.aux *.fdb_latexmk *.fls *.log *.out *.pdfsync *.synctex.gz
	rm -rf generated figures
