tests = benchmarks EISMINT-1 EISMINT-2 isos lin-non_lin
SUBDIRS = src $(tests)

data::
		list='$(tests)'; for dir in $$list; do \
		(cd $$dir && $(MAKE) $@); \
		done
 

graphics::
		list='$(tests)'; for dir in $$list; do \
		  (cd $$dir && $(MAKE) $@); \
		done

check-data::
		list='$(tests)'; for dir in $$list; do \
		  (cd $$dir && $(MAKE) $@); \
		done

dist-gold-standard::
		list='$(tests)'; for dir in $$list; do \
		  (cd $$dir && $(MAKE) $@); \
		done