bin_PROGRAMS  =  eismint3_glide

nodist_include_HEADERS := $(wildcard *.mod)
EXTRA_DIST = f90_dep.mak eismint3_vars.def
BUILT_SOURCES = eismint3_io.F90
CLEANFILES = $(BUILT_SOURCES) f90_dep.mak *.mod



eismint3_glide_SOURCES = eismint3_glide.F90 eismint3_forcing.F90 eismint3_types.F90 eismint3_io.F90
if USE_GLIDE_IF
eismint3_glide_LDADD = $(top_builddir)/libglint/libglint.la  $(top_builddir)/libglide_if/libglide_if.la $(top_builddir)/libglide/libglide.la \
                       $(top_builddir)/libglimmer-solve/libglimmer-solve.la \
                       $(top_builddir)/libglimmer/libglimmer-IO.la $(top_builddir)/libglimmer/libglimmer.la \
                       $(NETCDF_LDFLAGS) $(HDF5_LDFLAGS) $(NETCDF_LIBS) $(BLAS_LIBS)
else
eismint3_glide_LDADD = $(top_builddir)/libglint/libglint.la  $(top_builddir)/libglide/libglide.la \
                       $(top_builddir)/libglimmer-solve/libglimmer-solve.la \
                       $(top_builddir)/libglimmer/libglimmer-IO.la $(top_builddir)/libglimmer/libglimmer.la \
                       $(NETCDF_LDFLAGS) $(HDF5_LDFLAGS) $(NETCDF_LIBS) $(BLAS_LIBS)
endif

AM_FCFLAGS = $(NETCDF_FCFLAGS)  $(F90_MODFLAG)$(top_builddir)/libglimmer-solve $(F90_MODFLAG)$(top_builddir)/libglide \
             $(F90_MODFLAG)$(top_builddir)/libglimmer $(F90_MODFLAG)$(top_builddir)/libglint
if USE_GLIDE_IF
AM_FCFLAGS += $(F90_MODFLAG)$(top_builddir)/libglide_if
endif



#some special rules for automatically generating ncdf src code
eismint3_io.F90:	eismint3_vars.def $(top_srcdir)/libglimmer/ncdf_template.F90.in
			$(PYTHON) $(top_srcdir)/scripts/generate_ncvars.py $^

f90_dep.mak:	$(SOURCES)
		$(PYTHON) $(top_srcdir)/scripts/f90_dependencies.py -o $@ $^

-include f90_dep.mak
