tests = benchmarks EISMINT-1 EISMINT-2 isos lin-non_lin
SUBDIRS = src $(tests)

graphics::
		list='$(tests)'; for dir in $$list; do \
		  (cd $$dir && $(MAKE) $@); \
		done

data::
		list='$(tests)'; for dir in $$list; do \
		  (cd $$dir && $(MAKE) $@); \
		done
