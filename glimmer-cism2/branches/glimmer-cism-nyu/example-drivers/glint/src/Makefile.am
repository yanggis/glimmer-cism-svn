if TRILINOS
bin_PROGRAMS  =  
else
bin_PROGRAMS  =  glint_example glex_ebm
endif


nodist_include_HEADERS := $(wildcard *.mod)
EXTRA_DIST = f90_dep.mak
BUILT_SOURCES = 
CLEANFILES = $(BUILT_SOURCES) f90_dep.mak $(wildcard *.mod)

glint_example_SOURCES = glint_example.F90
glex_ebm_SOURCES = glex_ebm.F90 glex_ebm_clim.F90 

LDADD = $(top_builddir)/libglint/libglint.la  $(top_builddir)/libglide/libglide.la \
        $(top_builddir)/libglimmer-solve/libglimmer-solve.la \
        $(top_builddir)/libglimmer/libglimmer-IO.la $(top_builddir)/libglimmer/libglimmer.la \
        $(NETCDF_LDFLAGS) $(HDF5_LDFLAGS) $(NETCDF_LIBS) $(BLAS_LIBS) $(LAPACK_LIBS) $(PARDISO_LIBS) $(UMFPACK_LIBS)

AM_FCFLAGS = $(NETCDF_FCFLAGS) $(F90_MODFLAG)$(top_builddir)/libglimmer-solve $(F90_MODFLAG)$(top_builddir)/libglide \
             $(F90_MODFLAG)$(top_builddir)/libglimmer $(F90_MODFLAG)$(top_builddir)/libglint



f90_dep.mak:	$(srcdir)/*.F90 $(BUILT_SOURCES)
		$(PYTHON) $(top_srcdir)/scripts/f90_dependencies.py -o $@ $^

-include f90_dep.mak
