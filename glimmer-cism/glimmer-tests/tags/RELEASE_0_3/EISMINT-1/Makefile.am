if BUILD_GRAPHICS
  graphics = e1-fm.1.ps e1-fm.2.ps e1-fm.3.ps e1-mm.1.ps e1-mm.2.ps e1-mm.3.ps
endif
BUILT_SOURCES = e1-fm.1.nc e1-fm.2.nc e1-fm.3.nc e1-mm.1.nc e1-mm.2.nc e1-mm.3.nc $(graphics)

EXTRA_DIST = e1-fm.1.config  e1-fm.2.config  e1-fm.3.config  e1-mm.1.config  e1-mm.2.config  e1-mm.3.config

include $(top_srcdir)/make.rules

.nc.ps:
	@GLIMMER_PREFIX@/bin/plotEISMINT.py -t 200 --pmt  -p ../PyCF/eismint.prof $< $@
