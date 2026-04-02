ROOTLIB := $(dir $(lastword $(MAKEFILE_LIST)))

SRCDIR 		?= .
META   		?= pdf-options.yml
BUILDDIR  	?= build
OUTDIR    	?= out
PLUGINDIR 	?= $(ROOTLIB)/plugins

SRCFILES 	:= $(wildcard $(SRCDIR)/*.md)
OUTFILES 	:= $(patsubst $(SRCDIR)/%.md,$(OUTDIR)/%.pdf,$(SRCFILES))

PLUGINS 	+= $(wildcard $(PLUGINDIR)/*.lua)

PANDOCARGS 	+= \
	-f markdown+raw_tex -t latex \
	--bibliography=bibliography.bib \
	--csl=$(ROOTLIB)/apa-citation.csl \
	--citeproc \
	--no-highlight \
	$(PLUGINS:%=-L %)

#	--highlight-style=$(ROOTLIB)/pygments.theme

LATEXARGS 	+= \
	-halt-on-error \
	-interaction=nonstopmode \
	-shell-escape

.PRECIOUS: $(patsubst $(SRCDIR)/%.md,$(BUILDDIR)/%.md $(BUILDDIR)/%.tex $(BUILDDIR)/%-body.tex $(BUILDDIR)/%-header.yml $(BUILDDIR)/%.pdf,$(SRCFILES))

.PHONY: all clean
all: $(OUTFILES)

$(BUILDDIR)/%.md: $(SRCDIR)/%.md $(META)
	mkdir -p $(dir $@)
	$(ROOTLIB)/scripts/templater -o $@ -D curdir=$(abspath .) $< $(META)

$(BUILDDIR)/%-body.tex: $(BUILDDIR)/%.md $(ROOTLIB)/*
	pandoc $(PANDOCARGS) -o $@ $<

$(BUILDDIR)/%-header.yml: $(SRCDIR)/%.md $(ROOTLIB)/*
	$(ROOTLIB)/scripts/markdownheader < $< > $@

$(BUILDDIR)/%.tex: $(BUILDDIR)/%-body.tex $(BUILDDIR)/%-header.yml $(ROOTLIB)/scripts/templater $(META)
	$(ROOTLIB)/scripts/templater -o $@ -D body=$< -D curdir=$(abspath .) $(ROOTLIB)/template.tex $(META) $(word 2,$^)

$(BUILDDIR)/%.pdf: $(BUILDDIR)/%.tex
	openout_any=a \
	TEXINPUTS="$(abspath $(SRCDIR))//:$(abspath $(ROOTLIB))//:" \
	$(ROOTLIB)/scripts/latexrerun "$(dir $@)" "$(notdir $(patsubst %.pdf,%.log,$@))" lualatex $(LATEXARGS) "$(abspath $<)"

$(OUTDIR)/%.pdf: $(BUILDDIR)/%.pdf
	mkdir -p $(dir $@)
	cp $< $@

clean:
	rm -rf $(BUILDDIR) $(OUTDIR)
