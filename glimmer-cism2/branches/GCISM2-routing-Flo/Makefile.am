SUBDIRS = m4macros scripts libglimmer libglimmer-solve libglide libglint \
          utils extensions tests example-drivers doc
if BUILD_PYTHON
  SUBDIRS += PyGC
endif

EXTRA_DIST = glimmer-cism-config.in
bin_SCRIPTS=glimmer-cism-config

datadir = tests example-drivers

data::
	list='$(datadir)'; for dir in $$list; do \
          (cd $$dir && $(MAKE) $@); \
        done

check-data::
	list='$(datadir)'; for dir in $$list; do \
          (cd $$dir && $(MAKE) $@); \
        done

dist-gold-standard::
	list='$(datadir)'; for dir in $$list; do \
          (cd $$dir && $(MAKE) $@); \
        done ; \
	tar -czf $(PACKAGE)-gold-$(VERSION).tar.gz $(PACKAGE)-gold-$(VERSION)  && rm -rf $(PACKAGE)-gold-$(VERSION)
	echo "Output of tests compressed to" $(PACKAGE)-gold-$(VERSION).tar.gz
