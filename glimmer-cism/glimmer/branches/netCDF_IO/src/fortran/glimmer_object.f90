
! +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
! +                                                           +
! +  glimmer_object.f90 - part of the GLIMMER ice model       + 
! +                                                           +
! +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
! 
! Copyright (C) 2004 GLIMMER contributors - see COPYRIGHT file 
! for list of contributors.
!
! This program is free software; you can redistribute it and/or 
! modify it under the terms of the GNU General Public License as 
! published by the Free Software Foundation; either version 2 of 
! the License, or (at your option) any later version.
!
! This program is distributed in the hope that it will be useful, 
! but WITHOUT ANY WARRANTY; without even the implied warranty of 
! MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the 
! GNU General Public License for more details.
!
! You should have received a copy of the GNU General Public License 
! along with this program; if not, write to the Free Software 
! Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 
! 02111-1307 USA
!
! GLIMMER is maintained by:
!
! Ian Rutt
! School of Geographical Sciences
! University of Bristol
! University Road
! Bristol
! BS8 1SS
! UK
!
! email: <i.c.rutt@bristol.ac.uk> or <ian.rutt@physics.org>
!
! GLIMMER is hosted on NeSCForge:
!
! http://forge.nesc.ac.uk/projects/glimmer/
!
! +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

module glimmer_object

  !*FD Holds the dervied type for the ice model
  !*FD instances, and the necessary code for calling them.

  use glimmer_global
  use glimmer_project
  use glimmer_interp
  use glimmer_types

  implicit none

  type glimmer_instance

    !*FD Derived type holding information about 
    !*FD ice model instance. Note that the arrays \texttt{gboxx}, \texttt{gboxy} and {\tt gboxn} 
    !*FD should eventually be contained in a new derived type relating to upscaling.

    type(projection)                 :: proj          !*FD The projection definition of the instance.
    type(downscale)                  :: downs         !*FD Downscaling parameters.
    character(fname_length)          :: paramfile     !*FD The name list file of parameters.
    type(glimmer_global_type)           :: model         !*FD The instance and all its arrays.
    logical                          :: newtemps      !*FD Flag to say we have new temperatures.
    real(dp), dimension(:,:),pointer :: xwind         !*FD $x$-component of surface winds on local grid.
    real(dp), dimension(:,:),pointer :: ywind         !*FD $y$-component of surface winds on local grid.
    real(dp), dimension(:,:),pointer :: global_orog   !*FD Global orography on local coordinates.
    real(dp), dimension(:,:),pointer :: local_orog    !*FD Local orography on local coordinates.
    integer  ,dimension(:,:),pointer :: gboxx         !*FD $x$-indices of the global gridbox to which the point belongs.
    integer  ,dimension(:,:),pointer :: gboxy         !*FD $y$-indices of the global gridbox to which the point belongs.
    integer  ,dimension(:,:),pointer :: gboxn         !*FD Number of local grid-boxes in each global grid-box.
    real(rk) ,dimension(:,:),pointer :: frac_coverage !*FD Fractional coverage of each global gridbox by
                                                      !*FD the projected grid.
    logical                          :: first         !*FD Is this the first timestep?

  end type glimmer_instance

  type output_flags

    !*FD A derived type used internally to communicate the outputs which need
    !*FD to be upscaled, thus avoiding unnecessary calculation

    logical :: orog        !*FD Set if we need to upscale the orography
    logical :: albedo      !*FD Set if we need to upscale the albedo
    logical :: ice_frac    !*FD Set if we need to upscale the ice fraction
    logical :: fresh_water !*FD Set if we need to upscale the freshwater flux

  end type output_flags

contains

  subroutine glimmer_i_initialise(unit,nmlfile,instance,radea,lons,lats,lonb,latb,time_step,start_time)

    !*FD Initialise an ice model (glimmer) instance

    use glimmer_setup
    use glimmer_temp
    use glimmer_velo
    use glimmer_ncfile
    ! Arguments

    integer,              intent(in)    :: unit        !*FD Filename unit to use when opening namelist file.
    character(*),         intent(in)    :: nmlfile     !*FD Name of namelist file.
    type(glimmer_instance),  intent(inout) :: instance    !*FD The instance being initialised.
    real(rk),             intent(in)    :: radea       !*FD Radius of the earth (m).
    real(rk),dimension(:),intent(in)    :: lons        !*FD Longitudes of global grid-points (degrees east).
    real(rk),dimension(:),intent(in)    :: lats        !*FD Latitudes of global grid-points (degrees north).
    real(rk),dimension(:),intent(in)    :: lonb        !*FD Longitudinal edges of grid-boxes (degrees east)
                                                       !*FD The number of elements must be one more than \texttt{lons}.
    real(rk),dimension(:),intent(in)    :: latb        !*FD Latitudinal edges of grid-boxes (degrees north)
                                                       !*FD The number of elements must be one more than \texttt{lats}.
    real(rk),             intent(in)    :: time_step   !*FD Model time-step (years).
    real(rk),optional,    intent(in)    :: start_time  !*FD Start time of model (years).

    ! Internal variables

    real(rk) :: dlon

    instance%model%numerics%tinc=time_step             ! Initialise the model time step
    dlon=lons(2)-lons(1)                               ! Calculate the longitudinal grid spacing - 
                                                       ! this needs generalising, somehow

    call glimmer_global_type_initialise(instance%model)         ! Do (probably redundant) initialisation
    call initial(unit,nmlfile,instance%model,instance%proj)     ! Read namelists and initialise variables
    instance%first=.true.                                       ! This is the first time-step

    call new_proj(instance%proj,radea)                          ! Initialise the projection
    call new_downscale(instance%downs,instance%proj,lons,lats)  ! Initialise the downscaling
    call glimmer_i_allocate(instance,size(lons),size(lats))        ! Allocate arrays appropriately
    call glimmer_load_sigma(instance%model,unit)                   ! Load the sigma file
    call openall_out(instance%model)                            ! Initialise output files
    call calc_lats(instance%proj,instance%model%climate%lati)   ! Initialise the local latitude array. 
                                                                ! This may be redundant, though.

    call index_global_boxes(instance%gboxx,instance%gboxy, &    ! Index global boxes
                            instance%gboxn,lons,lats,lonb, &
                            latb,instance%proj)

    call calc_coverage(instance%proj,instance%gboxx,&           ! Calculate coverage map
                       instance%gboxy,dlon,latb, &
                       instance%proj%dx,instance%proj%dy, &
                       radea,instance%frac_coverage)

    call testinisthk(instance%model,unit,instance%first)         ! Load in initial surfaces

    call timeevoltemp(instance%model,0,instance%global_orog)    ! calculate initial temperature distribution
    instance%newtemps = .true.                      ! we have new temperatures

    call calcflwa(instance%model%numerics,        &                 ! Calculate Glen's A
                  instance%model%velowk,          &
                  instance%model%paramets%fiddle, &
                  instance%model%temper%flwa,     &
                  instance%model%temper%temp,     &
                  instance%model%geometry%thck,   &
                  instance%model%options%whichflwa)

    if (present(start_time)) then
      instance%model%numerics%time = start_time       ! Initialise the counter.
    else                                              ! Despite being in the GLIMMER framework,
      instance%model%numerics%time = 0.0              ! each instance has a copy of the counter
    endif                                             ! for simplicity.

    call writeall(instance%model)

  end subroutine glimmer_i_initialise

!++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

  subroutine glimmer_i_allocate(instance,nxg,nyg,re_alloc)

    !*FD Allocate top-level arrays in
    !*FD the model instance, and ice model arrays.

    use glimmer_setup

    type(glimmer_instance),intent(inout) :: instance    !*FD Instance whose elements are to be allocated.
    integer,            intent(in)    :: nxg         !*FD Longitudinal size of global grid (grid-points).
    integer,            intent(in)    :: nyg         !*FD Latitudinal size of global grid (grid-points).
    logical,optional,   intent(in)    :: re_alloc    !*FD Set if we need to de-allocate first.

    ! First deallocate if necessary

    if (present(re_alloc)) then
      if (re_alloc) then
        if (associated(instance%xwind))         deallocate(instance%xwind)
        if (associated(instance%ywind))         deallocate(instance%ywind)
        if (associated(instance%global_orog))   deallocate(instance%global_orog) 
        if (associated(instance%local_orog))    deallocate(instance%local_orog) 
        if (associated(instance%gboxx))         deallocate(instance%gboxx) 
        if (associated(instance%gboxy))         deallocate(instance%gboxy) 
        if (associated(instance%gboxn))         deallocate(instance%gboxn)  
        if (associated(instance%frac_coverage)) deallocate(instance%frac_coverage)
      endif
    endif

    ! Then reallocate...
    ! Wind field arrays

    allocate(instance%xwind(instance%model%general%ewn,instance%model%general%nsn)) 
    allocate(instance%ywind(instance%model%general%ewn,instance%model%general%nsn))

    ! Local-global orog

    allocate(instance%global_orog(instance%model%general%ewn,instance%model%general%nsn))

    ! Local-local orog

    allocate(instance%local_orog(instance%model%general%ewn,instance%model%general%nsn))

    ! Global box indices and number of points contained therein

    allocate(instance%gboxx(instance%model%general%ewn,instance%model%general%nsn))
    allocate(instance%gboxy(instance%model%general%ewn,instance%model%general%nsn))     
    allocate(instance%gboxn(nxg,nyg))

    ! Fractional coverage map

    allocate(instance%frac_coverage(nxg,nyg)) ! allocate fractional coverage map

    ! Allocate the model arrays - use original ice model code

    call allocarr(instance%model)

  end subroutine glimmer_i_allocate

!++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

  subroutine glimmer_i_tstep(unit,logunit,time,instance,lats,lons,g_temp,g_temp_range, &
                          g_precip,g_zonwind,g_merwind,g_orog,g_orog_out,g_albedo,g_ice_frac,&
                          g_fw_flux,out_f)

    !*FD Performs time-step of an ice model instance. Note that this 
    !*FD code will need to be altered to take account of the 
    !*FD energy-balance mass-balance model when it is completed.

    use glimmer_isot
    use glimmer_thck
    use glimmer_velo
    use glimmer_temp
    use glimmer_setup
    use glimmer_ncfile
    use glimmer_interp
    use glimmer_mbal
    use paramets

    ! ------------------------------------------------------------------------  
    ! Arguments
    ! ------------------------------------------------------------------------  

    integer,                intent(in)   :: unit         !*FD Logical file unit to be used for write operations
    integer,                intent(in)   :: logunit      !*FD Unit for log file
    real(rk),               intent(in)   :: time         !*FD Current time in years
    type(glimmer_instance), intent(inout):: instance     !*FD Model instance
    real(rk),dimension(:),  intent(in)   :: lats         !*FD Latitudes of global grid points (degrees north)
    real(rk),dimension(:),  intent(in)   :: lons         !*FD Longitudes of global grid points (degrees east)
    real(rk),dimension(:,:),intent(in)   :: g_temp       !*FD Global annual mean surface temperature field (
    real(rk),dimension(:,:),intent(in)   :: g_temp_range !*FD Global annual surface temperature range field ($^{\circ}$C)
    real(rk),dimension(:,:),intent(in)   :: g_precip     !*FD Global annual precip field total (mm/a)
    real(rk),dimension(:,:),intent(in)   :: g_zonwind    !*FD Global annual mean surface zonal wind (m/s)
    real(rk),dimension(:,:),intent(in)   :: g_merwind    !*FD Global annual mean surface meridonal wind (m/s)
    real(rk),dimension(:,:),intent(in)   :: g_orog       !*FD Input global orography (m)
    real(rk),dimension(:,:),intent(out)  :: g_orog_out   !*FD Output orography (m)
    real(rk),dimension(:,:),intent(out)  :: g_albedo     !*FD Output surface albedo (m)
    real(rk),dimension(:,:),intent(out)  :: g_ice_frac   !*FD Output ice fraction
    real(rk),dimension(:,:),intent(out)  :: g_fw_flux    !*FD Output freshwater flux
    type(output_flags),     intent(in)   :: out_f        !*FD Flags to tell us whether to do output       

    ! ------------------------------------------------------------------------  
    ! Internal variables
    ! ------------------------------------------------------------------------  

    real(rk),dimension(:,:),allocatable :: upscale_temp  ! temporary array for upscaling
    real(rk) :: f1 ! Scaling factor for converting precip and run-off amounts.

    f1 = scyr * thk0 / tim0

    ! Allocate temporary upscaling array -------------------------------------

    allocate(upscale_temp(instance%model%general%ewn,instance%model%general%nsn))

    ! ------------------------------------------------------------------------  
    ! Update internal clock
    ! ------------------------------------------------------------------------  

    instance%model%numerics%time=time  

    ! ------------------------------------------------------------------------  
    ! Downscale input fields, but only if required by options selected
    ! ------------------------------------------------------------------------  

    ! Temperature downscaling ------------------------------------------------

    select case(instance%model%options%whichartm)
    case(7)
      call interp_to_local(instance%proj,  &
                           g_temp,         &
                           lats,           &
                           lons,           &
                           instance%downs, &
                           localsp=instance%model%climate%g_artm)

      call interp_to_local(instance%proj,  &
                           g_temp_range,   &
                           lats,           &
                           lons,           &
                           instance%downs, &
                           localsp=instance%model%climate%g_arng)
    end select

    ! Precip downscaling -----------------------------------------------------

    select case(instance%model%options%whichprecip)
    case(1,2)
      call interp_to_local(instance%proj,  &
                           g_precip,       &
                           lats,           &
                           lons,           &
                           instance%downs, &
                           localsp=instance%model%climate%prcp)
    end select

    ! Orography downscaling --------------------------------------------------

    call interp_to_local(instance%proj,    &
                         g_orog,           &
                         lats,             &
                         lons,             &
                         instance%downs,   &
                         localdp=instance%global_orog)

    ! Wind downscaling -------------------------------------------------------

    select case(instance%model%options%whichprecip)
    case(2)
      call interp_wind_to_local(instance%proj,    &
                                g_zonwind,        &
                                g_merwind,        &
                                lats,             &
                                lons,             &
                                instance%downs,   &
                                instance%xwind,instance%ywind)
    end select

    ! ------------------------------------------------------------------------  
    ! Sort out some local orography - scale orography by correct amount
    ! ------------------------------------------------------------------------  

    instance%local_orog=instance%model%geometry%usrf*thk0

    ! Remove bathymetry. This relies on the point 1,1 being underwater.
    ! However, it's a better method than just setting all points < 0.0 to zero

    call glimmer_remove_bath(instance%local_orog,1,1)

    ! ------------------------------------------------------------------------  
    ! Calculate the surface temperature and range, if none are currently
    ! available 
    ! ------------------------------------------------------------------------  
  
    if (instance%first) then
      call calcartm(instance%model,                       &
                    instance%model%options%whichartm,     &
                    instance%model%geometry%usrf,         &
                    instance%model%climate%lati,          &
                    instance%model%climate%artm,          &
                    instance%model%climate%arng,          &
                    g_orog=instance%global_orog,          &
                    g_artm=instance%model%climate%g_artm, &
                    g_arng=instance%model%climate%g_arng)
    endif

    ! ------------------------------------------------------------------------  
    ! Calculate the precipitation field 
    ! ------------------------------------------------------------------------  

    select case(instance%model%options%whichprecip)

    case(0)   ! Uniform precipitation ----------------------------------------

      instance%model%climate%prcp=instance%model%climate%uprecip_rate/f1

    case(1)   ! Large scale precip -------------------------------------------
              ! Note that we / by 1000 to convert to m yr^{-1}, and then by
              ! f1 for scaling in the model.

      instance%model%climate%prcp=instance%model%climate%prcp/(1000.0*f1)

    case(2)   ! Precip parameterization --------------------------------------

      call glimmer_precip(instance%model%climate%prcp, &
                          instance%xwind,&
                          instance%ywind,&
                          instance%model%climate%artm,&
                          instance%local_orog,&
                          instance%proj%dx,&
                          instance%proj%dy,&
                          fixed_a=.true.)
      instance%model%climate%prcp=instance%model%climate%prcp/(1000.0*f1)

    case(3)   ! Prescribed small-scale precip from file, ---------------------
              ! adjusted for temperature

      instance%model%climate%prcp = instance%model%climate%presprcp * &
             pfac ** (instance%model%climate%artm - &
                      instance%model%climate%presartm)

    end select

    ! ------------------------------------------------------------------------  
    ! If first step, use as seed...
    ! ------------------------------------------------------------------------  

    if (instance%first) then
      call calcacab(instance%model%numerics, &
                    instance%model%paramets, &
                    instance%model%pddcalc,  &
                    instance%model%options%  whichacab, &
                    instance%model%geometry% usrf,      &
                    instance%model%climate%  artm,      &
                    instance%model%climate%  arng,      &
                    instance%model%climate%  prcp,      &
                    instance%model%climate%  ablt,      &
                    instance%model%climate%  lati,      &
                    instance%model%climate%  acab)
      instance%model%geometry%thck = max(0.0d0, &
                                         instance%model%climate%acab* &
                                         instance%model%numerics%dt)

      call calclsrf(instance%model%geometry%thck, &
                    instance%model%geometry%topg, &
                    instance%model%geometry%lsrf)
      instance%model%geometry%usrf = instance%model%geometry%thck + &
                                     instance%model%geometry%lsrf
      instance%first=.false.
    endif

    ! ------------------------------------------------------------------------ 
    ! Calculate isostasy
    ! ------------------------------------------------------------------------ 

    call isosevol(instance%model%numerics,            & 
                  instance%model%paramets,            &
                  instance%model%isotwk,              &                                      
                  instance%model%options%  whichisot, &
                  instance%model%geometry% thck,      &
                  instance%model%geometry% topg,      &
                  instance%model%geometry% relx)

    ! ------------------------------------------------------------------------ 
    ! Calculate various derivatives...
    ! ------------------------------------------------------------------------ 

    call stagvarb(instance%model%geometry% thck, &
                  instance%model%geomderv% stagthck,&
                  instance%model%general%  ewn, &
                  instance%model%general%  nsn)

    call geomders(instance%model%numerics, &
                  instance%model%geometry% usrf, &
                  instance%model%geomderv% stagthck, &
                  instance%model%geomderv% dusrfdew, &
                  instance%model%geomderv% dusrfdns)

    call geomders(instance%model%numerics, &
                  instance%model%geometry% thck, &
                  instance%model%geomderv% stagthck, &
                  instance%model%geomderv% dthckdew, &
                  instance%model%geomderv% dthckdns)

    ! ------------------------------------------------------------------------ 
    ! Do velocity calculation if necessary
    ! ------------------------------------------------------------------------ 

    if (instance%model%numerics%tinc > &
        mod(instance%model%numerics%time,instance%model%numerics%nvel) .or. &
        instance%model%numerics%time == instance%model%numerics%tinc ) then
           
      call slipvelo(instance%model%numerics, &
                    instance%model%velowk,   &
                    instance%model%paramets, &
                    instance%model%geomderv, &
                    (/instance%model%options%whichslip,&
                      instance%model%options%whichbtrc/), &
                    instance%model%temper%   bwat,     &
                    instance%model%velocity% btrc,     &
                    instance%model%geometry% relx,     &
                    instance%model%velocity% ubas,     &
                    instance%model%velocity% vbas)

      call zerovelo(instance%model%velowk,             &
                    instance%model%numerics%sigma,     &
                    0,                                 &
                    instance%model%geomderv% stagthck, &
                    instance%model%geomderv% dusrfdew, &
                    instance%model%geomderv% dusrfdns, &
                    instance%model%temper%   flwa,     &
                    instance%model%velocity% ubas,     &
                    instance%model%velocity% vbas,     &
                    instance%model%velocity% uvel,     &
                    instance%model%velocity% vvel,     &
                    instance%model%velocity% uflx,     &
                    instance%model%velocity% vflx,     &
                    instance%model%velocity% diffu)
    end if

    ! ------------------------------------------------------------------------ 
    ! Calculate ablation, and thus mass-balance
    ! ------------------------------------------------------------------------ 

    call calcacab(instance%model%numerics, &
                  instance%model%paramets, &
                  instance%model%pddcalc,  &
                  instance%model%options%  whichacab, &
                  instance%model%geometry% usrf,      &
                  instance%model%climate%  artm,      &
                  instance%model%climate%  arng,      &
                  instance%model%climate%  prcp,      &
                  instance%model%climate%  ablt,      &
                  instance%model%climate%  lati,      &
                  instance%model%climate%  acab)

    call maskthck(instance%model%options%  whichthck, &
                  instance%model%geometry% thck,      &
                  instance%model%climate%  acab,      &
                  instance%model%geometry% dom,       &
                  instance%model%geometry% mask,      &
                  instance%model%geometry% totpts,    &
                  instance%model%geometry% empty)

    ! ------------------------------------------------------------------------
    ! At this point we need to do the freshwater flux calculation, as the 
    ! limits of the ice-sheet may change before we get to the end of the
    ! subroutine, where the other outputs are calculated
    ! ------------------------------------------------------------------------

    if (out_f%fresh_water) then

      where (instance%model%geometry%thck>0.0)
        upscale_temp=f1*instance%model%climate%ablt
      elsewhere
        upscale_temp=0.0
      endwhere

      call mean_to_global(instance%proj, &
                          upscale_temp, &
                          instance%gboxx, &
                          instance%gboxy, &
                          instance%gboxn, &
                          g_fw_flux)

    endif

    ! ------------------------------------------------------------------------ 
    ! Calculate temperature evolution and Glenn's A, if necessary
    ! ------------------------------------------------------------------------ 

    if ( instance%model%numerics%tinc >  &
         mod(instance%model%numerics%time,instance%model%numerics%ntem) ) then
      call timeevoltemp(instance%model, &
                        instance%model%options%whichtemp, &
                        instance%global_orog)
      call calcflwa(instance%model%numerics,         & 
                    instance%model%velowk,           &
                    instance%model%paramets% fiddle, &
                    instance%model%temper%   flwa,   &
                    instance%model%temper%   temp,   &
                    instance%model%geometry% thck,   &
                    instance%model%options%  whichflwa) 
      instance%newtemps = .true.
    end if

    ! ------------------------------------------------------------------------ 
    ! Calculate flow evolution by various different methods
    ! ------------------------------------------------------------------------ 

    select case(instance%model%options%whichevol)
    case(0) ! Use precalculated uflx, vflx -----------------------------------

      call timeevolthck(instance%model, &
                        instance%model%options%  whichthck, &
                        instance%model%geometry% usrf,      &
                        instance%model%geometry% thck,      &
                        instance%model%geometry% lsrf,      &
                        instance%model%climate%  acab,      &
                        instance%model%geometry% mask,      &
                        instance%model%velocity% uflx,      &
                        instance%model%velocity% vflx,      &
                        instance%model%geomderv% dusrfdew,  &
                        instance%model%geomderv% dusrfdns,  &
                        instance%model%geometry% totpts,    &
                        logunit)

    case(1) ! Use explicit leap frog method with uflx,vflx -------------------

      call stagleapthck(instance%model, &
                        instance%model%velocity% uflx, &
                        instance%model%velocity% vflx, &
                        instance%model%geometry% thck, &
                        instance%model%geometry% usrf, &
                        instance%model%geometry% lsrf, &
                        instance%model%climate%  acab)

    case(2) ! Use non-linear calculation that incorporates velocity calc -----

      call nonlevolthck(instance%model, &
                        instance%model%options%whichthck, &
                        instance%newtemps,logunit)

    end select

    ! ------------------------------------------------------------------------ 
    ! Remove ice which is either floating, or is present below prescribed
    ! depth, depending on value of whichmarn
    ! ------------------------------------------------------------------------ 

    call marinlim(instance%model%options%  whichmarn, &
                  instance%model%options%  whichthck, &
                  instance%model%geometry% thck,      &
                  instance%model%geometry% usrf,      &
                  instance%model%geometry% relx,      &
                  instance%model%geometry% topg,      &
                  instance%model%climate%  lati,      &
                  instance%model%numerics%mlimit)

    ! ------------------------------------------------------------------------ 
    ! Calculate the lower surface elevation
    ! ------------------------------------------------------------------------ 

    call calclsrf(instance%model%geometry%thck, &
                  instance%model%geometry%topg, &
                  instance%model%geometry%lsrf)

    ! ------------------------------------------------------------------------ 
    ! Do outputs if necessary
    ! ------------------------------------------------------------------------ 

    call writeall(instance%model)

    instance%newtemps = .false.

    print *, "* completed time ", instance%model%numerics%time

    ! ------------------------------------------------------------------------ 
    ! Upscaling of output
    ! ------------------------------------------------------------------------ 

    ! Upscale the output orography field, and re-dimensionalise --------------

    if (out_f%orog) then
      call mean_to_global(instance%proj, &
                          instance%model%geometry%usrf, &
                          instance%gboxx, &
                          instance%gboxy, &
                          instance%gboxn, &
                          g_orog_out)
      g_orog_out=thk0*g_orog_out
    endif

    ! Use thickness to calculate albedo and ice fraction ---------------------

    if (out_f%albedo.or.out_f%ice_frac.or.out_f%fresh_water) then

      ! First, ice coverage on local grid 
  
      where (instance%model%geometry%thck>0.0)
        upscale_temp=1.0
      elsewhere
        upscale_temp=0.0
      endwhere

      ! Upscale it...

      call mean_to_global(instance%proj, &
                          upscale_temp, &
                          instance%gboxx, &
                          instance%gboxy, &
                          instance%gboxn, &
                          g_albedo)

      ! Copy to ice fraction

      g_ice_frac=g_albedo

    endif

    ! Calculate albedo -------------------------------------------------------

    if (out_f%albedo) then 
      where (g_ice_frac>0.0)
        g_albedo=instance%model%climate%ice_albedo
      elsewhere
        g_albedo=0.0
      endwhere
    endif

    ! Tidy up ----------------------------------------------------------------

    deallocate(upscale_temp)

  end subroutine glimmer_i_tstep

!+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

  subroutine glimmer_i_end(model,unit)

    !*FD Performs tidying-up for an ice model. Logically, this 
    !*FD should take type {\tt glimmer\_instance} as
    !*FD input, rather than {\tt glimmer\_global\_type}, but it doesn't!

    use glimmer_setup
    use glimmer_ncfile
    use glimmer_ncinfile

    ! Arguments

    type(glimmer_global_type),intent(inout) :: model !*FD Model to be tidyed-up.
    integer,               intent(in)    :: unit  !*FD Logical file unit to use for writing.

    ! Beginning of code

    call writeall(model,.true.)
    call closeall_out(model)
    call closeall_in(model)

  end subroutine glimmer_i_end

!++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

  subroutine get_instance_params(unit,instance,filename)

    !*FD Read namelist of parameters 
    !*FD for each instance.

    implicit none

    ! Arguments

    integer,            intent(in)    :: unit     !*FD Logical file unit to use
    type(glimmer_instance),intent(inout) :: instance !*FD Instance being initialised
    character(*),       intent(in)    :: filename !*FD Filename of namelist file

    ! Internal variables

    integer  :: nx,ny
    real(rk) :: dx,dy,cpx,cpy,latc,lonc

    ! Namelist definition

    namelist /project/ nx,ny,dx,dy,cpx,cpy,latc,lonc

    ! Beginning of code

    instance%paramfile=filename

    open(unit,file=filename)
    read(unit,nml=project)
    close(unit)

    instance%proj%nx=nx
    instance%proj%ny=ny
    instance%proj%dx=dx
    instance%proj%dy=dy
    instance%proj%cpx=cpx
    instance%proj%cpy=cpy
    instance%proj%latc=latc
    instance%proj%lonc=lonc

  end subroutine get_instance_params

!+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

  subroutine index_global_boxes(gbx,gby,gbn,glon,glat,glon_bound,glat_bound,proj)

    !*FD Compiles an index of which global grid box contains a given
    !*FD grid box on the projected grid.

    ! Arguments

    integer,dimension(:,:),intent(out) :: gbx        !*FD Longitudinal index of global 
                                                     !*FD grid-box containing this point.
    integer,dimension(:,:),intent(out) :: gby        !*FD Latitudinal index of global
                                                     !*FD grid-box containing this point
    integer,dimension(:,:),intent(out) :: gbn        !*FD Number of projected grid boxes in each global box
    real(rk),dimension(:), intent(in)  :: glon       !*FD Longitudinal location of global 
                                                     !*FD grid points (degrees)
    real(rk),dimension(:), intent(in)  :: glat       !*FD Latitudinal location of global 
                                                     !*FD grid points (degrees)
    real(rk),dimension(:), intent(in)  :: glon_bound !*FD Longitudinal boundaries of global 
                                                     !*FD grid boxes (degrees)
    real(rk),dimension(:), intent(in)  :: glat_bound !*FD Latitudinal boundaries of global 
                                                     !*FD grid boxes (degrees)
    type(projection),      intent(in)  :: proj       !*FD Projection being used
    
    ! Internal variables

    integer :: i,j,ii,jj,nx,ny,gnx,gny
    real(rk) :: plon,plat
    integer,dimension(size(gbx,1),size(gbx,2)) :: tempmask
    
    ! Beginning of code

    gnx=size(glon) ; gny=size(glat)
    nx=proj%nx ; ny=proj%ny

    gbx=0 ; gby=0

    do i=1,nx
      do j=1,ny
        call xy_to_ll(plon,plat,real(i,rk),real(j,rk),proj)
        ii=1 ; jj=1
        do
          gbx(i,j)=ii
          if (ii>gnx) then
            print*,'global index failure'
            stop
          endif  
          if (lon_between(glon_bound(ii),glon_bound(ii+1),plon)) exit
          ii=ii+1
        enddo

        jj=1

        do
          gby(i,j)=jj
          if (jj>gny) then
            print*,'global index failure'
            stop
          endif  
          if ((glat_bound(jj)>=plat).and.(plat>glat_bound(jj+1))) exit
          jj=jj+1
        enddo

      enddo
    enddo

    tempmask=0
    gbn=0

    do i=1,gnx
      do j=1,gny
        where (gbx==i.and.gby==j) 
          tempmask=1
        elsewhere
          tempmask=0
        endwhere
        gbn(i,j)=sum(tempmask)
      enddo
    enddo

  end subroutine index_global_boxes

!++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

  subroutine calc_coverage(proj,gboxx,gboxy,dlon,latb,dx,dy,radea,frac_coverage)

    !*FD Calculates the fractional
    !*FD coverage of the global grid-boxes by the ice model
    !*FD domain.

    use glimmer_project
    use gmt, only: D2R

    ! Arguments

    type(projection),       intent(in)  :: proj         !*FD Projection to be used
    integer,dimension(:,:), intent(in)  :: gboxx        !*FD Local-to-global grid-box conversion indices ($x$)
    integer,dimension(:,:), intent(in)  :: gboxy        !*FD Local-to-global grid-box conversion indices ($y$)
    real(rk),dimension(:),  intent(in)  :: latb         !*FD Latitudinal boundaries of grid-boxes (degrees)
    real(rk),               intent(in)  :: dlon         !*FD Longitudinal grid-box size (degrees)
    real(rk),               intent(in)  :: dx           !*FD $x$-size of grid-boxes
    real(rk),               intent(in)  :: dy           !*FD $y$-size of grid-boxes
    real(rk),               intent(in)  :: radea        !*FD Radius of the earth (m)
    real(rk),dimension(:,:),intent(out) :: frac_coverage !*FD Map of fractional coverage of global by local grid-boxes

    ! Internal variables

    integer,dimension(size(gboxx,1),size(gboxx,2)) :: tempmask
    integer :: nxg,nyg,i,j
    real(rk) :: stm

    ! Beginning of code

    nxg=size(frac_coverage,1) ; nyg=size(frac_coverage,2)

    tempmask=0

    do i=1,nxg
      do j=1,nyg
        where (gboxx==i.and.gboxy==j)
          tempmask=1
        elsewhere
          tempmask=0
        endwhere
        stm=sum(tempmask)
        if (stm==0) then
          frac_coverage(i,j)=0.0
        else
          frac_coverage(i,j)=stm*dx*dy
          frac_coverage(i,j)=frac_coverage(i,j)/ &
                 (dlon*D2R*radea**2*    &
                 (sin(latb(j)*D2R)-sin(latb(j+1)*D2R)))
        endif
      enddo
    enddo  

    ! Fix points that should be 1.0 by checking thir surroundings

    ! Interior points first

    do i=2,nxg-1
      do j=2,nyg-1
        if ((frac_coverage(i,j).ne.0).and. &
            (frac_coverage(i+1,j).ne.0).and. &
            (frac_coverage(i,j+1).ne.0).and. &
            (frac_coverage(i-1,j).ne.0).and. &
            (frac_coverage(i,j-1).ne.0)) &
                        frac_coverage(i,j)=1.0
      enddo
    enddo

    ! top and bottom edges

    do i=2,nxg/2
      if ((frac_coverage(i,1).ne.0).and. &
          (frac_coverage(i+1,1).ne.0).and. &
          (frac_coverage(i,2).ne.0).and. &
          (frac_coverage(i-1,1).ne.0).and. &
          (frac_coverage(i+nxg/2,1).ne.0)) &
                      frac_coverage(i,1)=1.0
    enddo

    do i=nxg/2+1,nxg-1
      if ((frac_coverage(i,1).ne.0).and. &
          (frac_coverage(i+1,1).ne.0).and. &
          (frac_coverage(i,2).ne.0).and. &
          (frac_coverage(i-1,1).ne.0).and. &
          (frac_coverage(i-nxg/2,1).ne.0)) &
                      frac_coverage(i,1)=1.0
    enddo

    do i=2,nxg/2
      if ((frac_coverage(i,nyg).ne.0).and. &
          (frac_coverage(i+1,nyg).ne.0).and. &
          (frac_coverage(i+nxg/2,nyg).ne.0).and. &
          (frac_coverage(i-1,nyg).ne.0).and. &
          (frac_coverage(i,nyg-1).ne.0)) &
                      frac_coverage(i,nyg)=1.0
    enddo

    do i=nxg/2+1,nxg-1
      if ((frac_coverage(i,nyg).ne.0).and. &
          (frac_coverage(i+1,nyg).ne.0).and. &
          (frac_coverage(i-nxg/2,nyg).ne.0).and. &
          (frac_coverage(i-1,nyg).ne.0).and. &
          (frac_coverage(i,nyg-1).ne.0)) &
                      frac_coverage(i,nyg)=1.0
    enddo
 
    ! left and right edges

    do j=2,nyg-1
      if ((frac_coverage(1,j).ne.0).and. &
          (frac_coverage(2,j).ne.0).and. &
          (frac_coverage(1,j+1).ne.0).and. &
          (frac_coverage(nxg,j).ne.0).and. &
          (frac_coverage(1,j-1).ne.0)) &
                      frac_coverage(1,j)=1.0
      if ((frac_coverage(nxg,j).ne.0).and. &
          (frac_coverage(1,j).ne.0).and. &
          (frac_coverage(nxg,j+1).ne.0).and. &
          (frac_coverage(nxg-1,j).ne.0).and. &
          (frac_coverage(nxg,j-1).ne.0)) &
                      frac_coverage(nxg,j)=1.0
    enddo

    ! corners

    if ((frac_coverage(1,1).ne.0).and. &
        (frac_coverage(2,1).ne.0).and. &
        (frac_coverage(1,2).ne.0).and. &
        (frac_coverage(nxg,1).ne.0).and. &
        (frac_coverage(nxg/2+1,1).ne.0)) &
                    frac_coverage(1,1)=1.0

    if ((frac_coverage(1,nyg).ne.0).and. &
        (frac_coverage(2,nyg).ne.0).and. &
        (frac_coverage(nxg/2+1,nyg).ne.0).and. &
        (frac_coverage(nxg,nyg).ne.0).and. &
        (frac_coverage(1,nyg-1).ne.0)) &
                    frac_coverage(1,nyg)=1.0

    if ((frac_coverage(nxg,1).ne.0).and. &
        (frac_coverage(1,1).ne.0).and. &
        (frac_coverage(nxg,2).ne.0).and. &
        (frac_coverage(nxg-1,1).ne.0).and. &
        (frac_coverage(nxg/2,1).ne.0)) &
                   frac_coverage(nxg,1)=1.0

    if ((frac_coverage(nxg,nyg).ne.0).and. &
        (frac_coverage(1,nyg).ne.0).and. &
        (frac_coverage(nxg/2,nyg).ne.0).and. &
        (frac_coverage(nxg-1,nyg).ne.0).and. &
        (frac_coverage(nxg,nyg-1).ne.0)) &
                   frac_coverage(nxg,nyg)=1.0

    ! Finally fix any rogue points > 1.0

    where (frac_coverage>1.0) frac_coverage=1.0

  end subroutine calc_coverage

!+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

  logical function lon_between(a,b,x)

    !*FD Checks to see whether a 
    !*FD longitudinal coordinate is between two bounds,
    !*FD taking into account the periodic boundary conditions.
    !*RV Returns \texttt{.true.} if $\mathtt{x}\geq \mathtt{a}$ and $\mathtt{x}<\mathtt{b}$.

    ! Arguments

    real(rk),intent(in) :: a  !*FD Lower bound on interval for checking
    real(rk),intent(in) :: b  !*FD Upper bound on interval for checking
    real(rk),intent(in) :: x  !*FD Test value (degrees)

    ! Internal variables

    real(rk) :: ta,tb

    ! Beginning of code

    if (a<b) then
      lon_between=((x>=a).and.(x<b))
    else
      if (x<a) then
        ta=a-360.0
        tb=b
      else 
        ta=a
        tb=b+360.0
      endif
      lon_between=((x>=ta).and.(x<tb))
    endif

  end function lon_between

!+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

  subroutine glimmer_load_sigma(model,unit)

    !*FD Loads a file containing
    !*FD sigma vertical coordinates.

    ! Arguments

    type(glimmer_global_type),intent(inout) :: model !*FD Ice model to use
    integer,               intent(in)    :: unit  !*FD Logical file unit to use. 
                                                  !*FD The logical file unit specified 
                                                  !*FD must not already be in use

    ! Internal variables

    integer :: up,upn
    logical :: there

    ! Beginning of code

    upn=model%general%upn

    inquire (exist=there,file=model%funits%sigfile)
  
    if (there) then
      open(unit,file=model%funits%sigfile)
      read(unit,'(f5.2)',err=10,end=10) (model%numerics%sigma(up), up=1,upn)
      close(unit)
      return
    end if

10  print *, 'something wrong with sigma coord file'
 
    stop

  end subroutine glimmer_load_sigma

!+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

  subroutine glimmer_remove_bath(orog,x,y)

    !*FD Sets ocean areas to zero height, working recursively from
    !*FD a known ocean point.

    real(rk),dimension(:,:),intent(inout) :: orog !*FD Orography --- used for input and output
    integer,                intent(in)    :: x,y  !*FD Location of starting point (index)

    integer :: nx,ny

    nx=size(orog,1) ; ny=size(orog,2)

    if (orog(x,y).lt.0.0) orog(x,y)=0.0
    call glimmer_find_bath(orog,x,y,nx,ny)

  end subroutine glimmer_remove_bath

!+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

  recursive subroutine glimmer_find_bath(orog,x,y,nx,ny)

    !*FD Recursive subroutine called by {\tt glimmer\_remove\_bath}.

    real(rk),dimension(:,:),intent(inout) :: orog  !*FD Orography --- used for input and output
    integer,                intent(in)    :: x,y   !*FD Starting point
    integer,                intent(in)    :: nx,ny !*FD Size of array {\tt orography}

    integer,dimension(4) :: xi=(/ -1,1,0,0 /)
    integer,dimension(4) :: yi=(/ 0,0,-1,1 /)
    integer :: ns=4,i

    do i=1,ns
      if (x+xi(i).le.nx.and.x+xi(i).gt.0.and. &
          y+yi(i).le.ny.and.y+yi(i).gt.0) then
        if (orog(x+xi(i),y+yi(i)).lt.0.0) then
          orog(x+xi(i),y+yi(i))=0.0
          call glimmer_find_bath(orog,x+xi(i),y+yi(i),nx,ny)
        endif
      endif
    enddo

  end subroutine glimmer_find_bath

end module glimmer_object
