graphics = ice_velo.eps erosion_layers.eps plot_basal.eps pressure_stress_strain.eps sediments.eps sed_profile.eps
EXTRA_DIST = ice_velo.fig erosion_layers.fig pressure_stress_strain.fig $(graphics)
BUILT_SOURCES = $(graphics)
CLEANFILES = $(BUILT_SOURCES)

plot_basal.ps:	plot_basal.py
	$(PYTHON) plot_basal.py

sediments.ps:	../../../tests/fenscan.nc
		$(PYTHON) ../../../python/plot_seds.py -T -1 -p fenscan.prof --not_p $< $@

sed_profile.ps:	../../../tests/fenscan.nc
		$(PYTHON) ../../../python/plot_seds_profile.py -t0. -e stages -p fenscan.prof --not_p $< $@

include $(top_srcdir)/doc/make_doc.rules
