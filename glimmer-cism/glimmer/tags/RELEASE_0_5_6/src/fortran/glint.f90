! +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
! +                                                           +
! +  glint.f90 - part of the GLIMMER ice model                + 
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

module glint_main

  !*FD  This is the main glimmer module, which contains the top-level 
  !*FD  subroutines and derived types comprising the glimmer ice model.

  use glimmer_global
  use glint_type
  use glint_global_grid
  use glint_constants

  ! ------------------------------------------------------------
  ! GLIMMER_PARAMS derived type definition
  ! This is where default values are set.
  ! ------------------------------------------------------------

  type glint_params 

     !*FD Derived type containing parameters relevant to all instances of 
     !*FD the model - i.e. those parameters which pertain to the global model. 

     ! Global grids used ----------------------------------------

     type(global_grid) :: g_grid      !*FD The main global grid, used for 
                                      !*FD input and most outputs
     type(global_grid) :: g_grid_orog !*FD Global grid used for orography output.

     ! Ice model instances --------------------------------------

     integer                                   :: ninstances = 1       !*FD Number of ice model instances
     type(glint_instance),pointer,dimension(:) :: instances  => null() !*FD Array of glimmer\_instances

     ! Global model parameters ----------------------------------

     real(rk) :: tstep_mbal = 1.0    !*FD Mass-balance timestep (hours)

     ! Averaging parameters -------------------------------------

     real(rk) :: av_start_time = 0.0 !*FD Holds the value of time from 
                                     !*FD the last occasion averaging was restarted (hours)
     integer  :: av_steps      = 0   !*FD Holds the number of times glimmer has 
                                     !*FD been called in current round of averaging.
     ! Averaging arrays -----------------------------------------

     real(rk),pointer,dimension(:,:) :: g_av_precip  => null()  !*FD globally averaged precip
     real(rk),pointer,dimension(:,:) :: g_av_temp    => null()  !*FD globally averaged temperature 
     real(rk),pointer,dimension(:,:) :: g_max_temp   => null()  !*FD global maximum temperature
     real(rk),pointer,dimension(:,:) :: g_min_temp   => null()  !*FD global minimum temperature
     real(rk),pointer,dimension(:,:) :: g_temp_range => null()  !*FD global temperature range
     real(rk),pointer,dimension(:,:) :: g_av_zonwind => null()  !*FD globally averaged zonal wind 
     real(rk),pointer,dimension(:,:) :: g_av_merwind => null()  !*FD globally averaged meridional wind 
     real(rk),pointer,dimension(:,:) :: g_av_humid   => null()  !*FD globally averaged humidity (%)
     real(rk),pointer,dimension(:,:) :: g_av_lwdown  => null()  !*FD globally averaged downwelling longwave (W/m^2)
     real(rk),pointer,dimension(:,:) :: g_av_swdown  => null()  !*FD globally averaged downwelling shortwave (W/m^2)
     real(rk),pointer,dimension(:,:) :: g_av_airpress => null() !*FD globally averaged surface air pressure (Pa)

     ! Fractional coverage information --------------------------

     real(rk),pointer,dimension(:,:) :: total_coverage  => null()     !*FD Fractional coverage by 
                                                                      !*FD all ice model instances.
     real(rk),pointer,dimension(:,:) :: cov_normalise   => null()     !*FD Normalisation values 
                                                                      !*FD for coverage calculation.
     real(rk),pointer,dimension(:,:) :: total_cov_orog  => null()     !*FD Fractional coverage by 
                                                                      !*FD all ice model instances (orog).
     real(rk),pointer,dimension(:,:) :: cov_norm_orog   => null()     !*FD Normalisation values 
                                                                      !*FD for coverage calculation (orog).
     logical                         :: coverage_calculated = .false. !*FD Have we calculated the
                                                                      !*FD coverage map yet?
     ! File information -----------------------------------------

     character(fname_length) :: paramfile      !*FD Name of global parameter file

     ! Start flag -----------------------------------------------

     logical :: first = .true. !*FD Set if this is the first call to glimmer - make sure we set up
                               !*FD start times correctly.

     ! Accumulation/averaging flags -----------------------------

     logical :: need_winds=.false. !*FD Set if we need the winds to be accumulated/downscaled
     logical :: enmabal=.false.    !*FD Set if we're using the energy balance mass balance model anywhere

  end type glint_params

  ! Private names -----------------------------------------------

  private glint_allocate_arrays,pi
  private glint_readconfig,calc_bounds,check_init_args

contains

  subroutine initialise_glint(params,lats,longs,paramfile,latb,lonb,orog,albedo, &
       ice_frac,veg_frac,snowice_frac,snowveg_frac,snow_depth,orog_lats,orog_longs,orog_latb,orog_lonb,output_flag, &
       daysinyear,snow_model,ice_dt,hotstart_files,hotstart_times)

    !*FD Initialises the model

    use glint_proj
    use glimmer_config
    use glint_initialise
    use glimmer_log
    implicit none

    ! Subroutine argument declarations --------------------------------------------------------

    type(glint_params),              intent(inout) :: params      !*FD parameters to be set
    real(rk),dimension(:),           intent(in)    :: lats,longs  !*FD location of gridpoints 
                                                                  !*FD in global data.
    character(*),                    intent(in)    :: paramfile   !*FD name of file containing 
                                                                  !*FD parameters for all required 
                                                                  !*FD instances. 
    real(rk),dimension(:),  optional,intent(in)    :: latb        !*FD Locations of the latitudinal 
                                                                  !*FD boundaries of the grid-boxes.
    real(rk),dimension(:),  optional,intent(in)    :: lonb        !*FD Locations of the longitudinal
                                                                  !*FD boundaries of the grid-boxes.
    real(rk),dimension(:,:),optional,intent(out)   :: orog        !*FD Initial global orography
    real(rk),dimension(:,:),optional,intent(out)   :: albedo      !*FD Initial albedo
    real(rk),dimension(:,:),optional,intent(out)   :: ice_frac    !*FD Initial ice fraction 
    real(rk),dimension(:,:),optional,intent(out)   :: veg_frac    !*FD Initial veg fraction
    real(rk),dimension(:,:),optional,intent(out)   :: snowice_frac !*FD Initial snow-covered ice fraction
    real(rk),dimension(:,:),optional,intent(out)   :: snowveg_frac !*FD Initial snow-covered veg fraction
    real(rk),dimension(:,:),optional,intent(out)   :: snow_depth  !*FD Initial snow depth 
    real(rk),dimension(:),  optional,intent(in)    :: orog_lats   !*FD Latitudinal location of gridpoints 
                                                                  !*FD for global orography output.
    real(rk),dimension(:),  optional,intent(in)    :: orog_longs  !*FD Longitudinal location of gridpoints 
                                                                  !*FD for global orography output.
    real(rk),dimension(:),  optional,intent(in)    :: orog_latb   !*FD Locations of the latitudinal 
                                                                  !*FD boundaries of the grid-boxes (orography).
    real(rk),dimension(:),  optional,intent(in)    :: orog_lonb   !*FD Locations of the longitudinal
                                                                  !*FD boundaries of the grid-boxes (orography).
    logical,                optional,intent(out)   :: output_flag !*FD Flag to show output set (provided for
                                                                  !*FD consistency)
    integer,                optional,intent(in)    :: daysinyear  !*FD Number of days in the year
    logical,                optional,intent(out)   :: snow_model  !*FD Set if the mass-balance scheme has a snow-depth model
    integer,                optional,intent(out)   :: ice_dt      !*FD Ice dynamics time-step in hours
    character(*),dimension(:),optional,intent(in) :: hotstart_files !*FD List of hotstart files for individual instances
    integer,dimension(:),optional,intent(in) :: hotstart_times !*FD List of hotstart time-slices

    ! Internal variables -----------------------------------------------------------------------

    type(ConfigSection), pointer :: global_config, instance_config, section  ! configuration stuff
    character(len=100) :: message                 ! For log-writing
    character(fname_length):: instance_fname      ! name of instance specific configuration file
    character(fname_length) :: hsfile
    integer,dimension(:),allocatable :: hstimes
    integer :: i,hst
    real(rk),dimension(:,:),allocatable :: orog_temp,if_temp,vf_temp,sif_temp,svf_temp,sd_temp,alb_temp ! Temporary output arrays
    integer,dimension(:),allocatable :: mbts,idts ! Array of mass-balance and ice dynamics timesteps

    ! Check optional hotstart arrays are same length or allocate accordingly  ------------------

    if (present(hotstart_files)) then
       if (present(hotstart_times)) then
          if (size(hotstart_files)/=size(hotstart_times)) then
             call write_log('Hotstart file list and time-slice list must be same length',GM_FATAL,__FILE__,__LINE__)
          else
             allocate(hstimes(size(hotstart_files)))
             hstimes=hotstart_times
          end if
       else
          allocate(hstimes(size(hotstart_files)))
          hstimes=1
       end if
    else
       hst=1
    end if

    ! Initialise year-length -------------------------------------------------------------------

    if (present(daysinyear)) then
       call glint_set_year_length(daysinyear)
    end if

    ! Initialise main global grid --------------------------------------------------------------

    call new_global_grid(params%g_grid,longs,lats,lonb=lonb,latb=latb)

    ! Initialise orography grid ------------------------------------

    call check_init_args(orog_lats,orog_longs,orog_latb,orog_lonb)

    if (present(orog_lats).and.present(orog_longs)) then
       call new_global_grid(params%g_grid_orog,orog_longs,orog_lats,lonb=orog_lonb,latb=orog_latb)
    else
       call copy_global_grid(params%g_grid,params%g_grid_orog)
    end if

    ! Allocate arrays -----------------------------------------------

    call glint_allocate_arrays(params)

    ! Initialise arrays ---------------------------------------------

    params%g_av_precip  = 0.0
    params%g_av_temp    = 0.0
    params%g_max_temp   = -1000.0
    params%g_min_temp   = 1000.0
    params%g_temp_range = 0.0
    params%g_av_zonwind = 0.0
    params%g_av_merwind = 0.0
    params%g_av_humid   = 0.0
    params%g_av_lwdown  = 0.0
    params%g_av_swdown  = 0.0
    params%g_av_airpress = 0.0

    ! ---------------------------------------------------------------
    ! Open the global configuration file and read in the parameters
    ! ---------------------------------------------------------------

    call ConfigRead(paramfile,global_config)    ! Load the configuration file into the linked list
    call glint_readconfig(params,global_config) ! Parse the list

    ! Allocate array of glimmer instances
    ! and the array of mass-balance timesteps

    allocate(params%instances(params%ninstances))
    allocate(mbts(params%ninstances),idts(params%ninstances))

    ! ---------------------------------------------------------------
    ! Zero coverage maps and normalisation fields for main grid and
    ! orography grid
    ! ---------------------------------------------------------------

    params%total_coverage=0.0
    params%total_cov_orog=0.0

    params%cov_normalise=0.0
    params%cov_norm_orog=0.0

    ! ---------------------------------------------------------------
    ! Read config files, and initialise instances accordingly
    ! ---------------------------------------------------------------

    call write_log('Reading instance configurations')
    call write_log('-------------------------------')

    ! First, see if there are multiple instances --------------------

    call GetSection(global_config,section,'GLINT instance')

    if (.not.associated(section)) then

       ! If there aren't any GLINT instance sections, then we must
       ! only have one instance. Otherwise, flag an error.

       if (params%ninstances.gt.1) then
          write(message,*) 'Must specify ',params%ninstances,' instance config files'
          call write_log(message,GM_FATAL,__FILE__,__LINE__)
       end if

       ! Deal with optional hotstart file

       if (present(hotstart_files)) then
          hsfile=hotstart_files(1)
          hst=hstimes(1)
       else
          hsfile=''
          hst=1
       end if

       ! In this situation, we write the name of the parameter file, and
       ! initialise the single instance

       call write_log(trim(paramfile))
       call glint_i_initialise(global_config,params%instances(1),params%g_grid,params%g_grid_orog, &
            mbts(1),idts(1),params%need_winds,params%enmabal,hs_file=hsfile,hs_time=hst)
       call write_log('')

       ! Update the coverage and normalisation fields


       params%total_coverage = params%instances(1)%frac_coverage
       params%total_cov_orog = params%instances(1)%frac_cov_orog

       where (params%total_coverage>0.0) params%cov_normalise=1.0
       where (params%total_cov_orog>0.0) params%cov_norm_orog=1.0

    else

       ! Otherwise, loop through instances (we do it this way since we've already got
       ! the first config section, but still need to get the remaining ones).

       i=1

       do 
          ! The section contains one element, 'name', which
          ! points to the config file for an individual instance.
          ! This is read in to instance_config, and passed to the initialisation
          ! for the instance

          instance_fname = ''
          call GetValue(section,'name',instance_fname)
          call write_log(trim(instance_fname))
          call ConfigRead(instance_fname,instance_config)
          ! Deal with optional hotstart file

          if (present(hotstart_files)) then
             hsfile=hotstart_files(i)
             hst=hstimes(i)
          else
             hsfile=''
             hst=1
          end if
          call glint_i_initialise(instance_config,params%instances(i),params%g_grid,params%g_grid_orog, &
               mbts(i),idts(i),params%need_winds,params%enmabal,hs_file=hsfile,hs_time=hst)

          params%total_coverage = params%total_coverage + params%instances(i)%frac_coverage
          params%total_cov_orog = params%total_cov_orog + params%instances(i)%frac_cov_orog

          where (params%total_coverage>0.0) params%cov_normalise=params%cov_normalise+1.0
          where (params%total_cov_orog>0.0) params%cov_norm_orog=params%cov_norm_orog+1.0

          ! If this is the last section, exit the loop. Otherwise, load the next one
          ! and go round again.
          
          if (i>=params%ninstances) exit
          i=i+1

          ! Get the next GLINT instance section, and if not present, flag an error

          call GetSection(section%next,section,'GLINT instance')
          if (.not.associated(section)) then
             write(message,*) 'Must specify ',params%ninstances,' instance config files'
             call write_log(message,GM_FATAL,__FILE__,__LINE__)
          end if
          ! check if we used all sections
          call CheckSections(instance_config)
       end do
    end if
    ! check if we used all sections
    call CheckSections(global_config)

    ! Check that all mass-balance time-steps are the same length and 
    ! assign that value to the top-level variable

    params%tstep_mbal=check_mbts(mbts)
    if (present(ice_dt)) then
       ice_dt=check_mbts(idts)
    end if

    ! Check we don't have coverage greater than one at any point.

    where (params%total_coverage>1.0) params%total_coverage=1.0
    where (params%total_cov_orog>1.0) params%total_cov_orog=1.0
    params%coverage_calculated=.true.

    ! Zero optional outputs, if present

    if (present(orog))     orog=0.0
    if (present(albedo))   albedo=0.0
    if (present(ice_frac)) ice_frac=0.0
    if (present(veg_frac)) veg_frac=0.0
    if (present(snowice_frac)) snowice_frac=0.0
    if (present(snowveg_frac)) snowveg_frac=0.0
    if (present(snow_depth)) snow_depth=0.0

    ! Allocate arrays

    allocate(orog_temp(params%g_grid_orog%nx,params%g_grid_orog%ny))
    allocate(alb_temp(params%g_grid%nx,params%g_grid%ny))
    allocate(if_temp(params%g_grid%nx,params%g_grid%ny))
    allocate(vf_temp(params%g_grid%nx,params%g_grid%ny))
    allocate(sif_temp(params%g_grid%nx,params%g_grid%ny))
    allocate(svf_temp(params%g_grid%nx,params%g_grid%ny))
    allocate(sd_temp(params%g_grid%nx,params%g_grid%ny))

    ! Get initial fields from instances, splice together and return

    do i=1,params%ninstances
       call get_i_upscaled_fields(params%instances(i),orog_temp, &
            alb_temp,if_temp,vf_temp,sif_temp,svf_temp,sd_temp)

       if (present(orog)) &
            orog=splice_field(orog,orog_temp,params%instances(i)%frac_cov_orog, &
            params%cov_norm_orog)

       if (present(albedo)) &
            albedo=splice_field(albedo,alb_temp,params%instances(i)%frac_coverage, &
            params%cov_normalise)

       if (present(ice_frac)) &
            ice_frac=splice_field(ice_frac,if_temp,params%instances(i)%frac_coverage, &
            params%cov_normalise)

       if (present(veg_frac)) &
            veg_frac=splice_field(veg_frac,vf_temp,params%instances(i)%frac_coverage, &
            params%cov_normalise)

       if (present(snowice_frac)) &
            snowice_frac=splice_field(snowice_frac,sif_temp,params%instances(i)%frac_coverage, &
            params%cov_normalise)

       if (present(snowveg_frac)) &
            snowveg_frac=splice_field(snowveg_frac,svf_temp,params%instances(i)%frac_coverage, &
            params%cov_normalise)

       if (present(snow_depth)) &
            snow_depth=splice_field(snow_depth,sd_temp,params%instances(i)%frac_coverage, &
            params%cov_normalise)
    end do

    ! Deallocate

    deallocate(orog_temp,alb_temp,if_temp,vf_temp,sif_temp,svf_temp,sd_temp)
    if (allocated(hstimes)) deallocate(hstimes)

    ! Sort out snow_model flag

    if (present(snow_model)) then
       snow_model=.false.
       do i=1,params%ninstances
          snow_model=(snow_model.or.glint_has_snow_model(params%instances(i)))
       end do
    end if

    ! Set output flag

    if (present(output_flag)) output_flag=.true.

  end subroutine initialise_glint

  !================================================================================

  subroutine glint(params,time,temp,precip,zonwind,merwind,orog,humid,lwdown,swdown,airpress, &
       output_flag,orog_out,albedo,ice_frac,veg_frac,snowice_frac,snowveg_frac,snow_depth,water_in, &
       water_out,total_water_in,total_water_out,ice_volume,skip_mbal,ice_tstep)

    !*FD Main Glimmer subroutine.
    !*FD
    !*FD This should be called daily or hourly, depending on
    !*FD the mass-balance scheme being used. It does all necessary 
    !*FD spatial and temporal averaging, and calls the dynamics 
    !*FD part of the model when required. 
    !*FD
    !*FD Input fields should be taken as means over the period since the last call.
    !*FD See the user documentation for more information.
    !*FD
    !*FD Note that the total ice volume returned is the total at the end of the time-step;
    !*FD the water fluxes are valid over the duration of the timestep. Thus the difference
    !*FD between \texttt{total\_water\_in} and \texttt{total\_water\_out} should be equal
    !*FD to the change in \texttt{ice\_volume}, after conversion between m$^3$ and kg.

    use glimmer_utils
    use glint_interp
    use glint_timestep
    use glimmer_log
    implicit none

    ! Subroutine argument declarations -------------------------------------------------------------

    type(glint_params),              intent(inout) :: params          !*FD parameters for this run
    integer,                         intent(in)    :: time            !*FD Current model time        (hours)
    real(rk),dimension(:,:),         intent(in)    :: temp            !*FD Surface temperature field (celcius)
    real(rk),dimension(:,:),         intent(in)    :: precip          !*FD Precipitation rate        (mm/s)
    real(rk),dimension(:,:),         intent(in)    :: zonwind,merwind !*FD Zonal and meridional components 
                                                                      !*FD of the wind field         (m/s)
    real(rk),dimension(:,:),         intent(inout) :: orog            !*FD The large-scale orography (m)
    real(rk),dimension(:,:),optional,intent(in)    :: humid           !*FD Surface humidity (%)
    real(rk),dimension(:,:),optional,intent(in)    :: lwdown          !*FD Downwelling longwave (W/m^2)
    real(rk),dimension(:,:),optional,intent(in)    :: swdown          !*FD Downwelling shortwave (W/m^2)
    real(rk),dimension(:,:),optional,intent(in)    :: airpress        !*FD surface air pressure (Pa)
    logical,                optional,intent(out)   :: output_flag     !*FD Set true if outputs set
    real(rk),dimension(:,:),optional,intent(inout) :: orog_out        !*FD The fed-back, output orography (m)
    real(rk),dimension(:,:),optional,intent(inout) :: albedo          !*FD surface albedo
    real(rk),dimension(:,:),optional,intent(inout) :: ice_frac        !*FD grid-box ice-fraction
    real(rk),dimension(:,:),optional,intent(inout) :: veg_frac        !*FD grid-box veg-fraction
    real(rk),dimension(:,:),optional,intent(inout) :: snowice_frac    !*FD grid-box snow-covered ice fraction
    real(rk),dimension(:,:),optional,intent(inout) :: snowveg_frac    !*FD grid-box snow-covered veg fraction
    real(rk),dimension(:,:),optional,intent(inout) :: snow_depth      !*FD grid-box mean snow depth (m water equivalent)
    real(rk),dimension(:,:),optional,intent(inout) :: water_in        !*FD Input water flux          (mm)
    real(rk),dimension(:,:),optional,intent(inout) :: water_out       !*FD Output water flux         (mm)
    real(rk),               optional,intent(inout) :: total_water_in  !*FD Area-integrated water flux in (kg)
    real(rk),               optional,intent(inout) :: total_water_out !*FD Area-integrated water flux out (kg)
    real(rk),               optional,intent(inout) :: ice_volume      !*FD Total ice volume (m$^3$)
    logical,                optional,intent(in)    :: skip_mbal       !*FD Set to skip mass-balance accumulation
    logical,                optional,intent(out)   :: ice_tstep       !*FD Set when an ice-timestep has been done, and
                                                                      !*FD water balance information is available

    ! Internal variables ----------------------------------------------------------------------------

    integer :: i
    real(rk),dimension(:,:),allocatable :: albedo_temp,if_temp,vf_temp,sif_temp,svf_temp,sd_temp,wout_temp,orog_out_temp,win_temp
    real(rk) :: twin_temp,twout_temp,icevol_temp
    type(output_flags) :: out_f
    logical :: skmb,icets

    if (present(skip_mbal)) then
       skmb=skip_mbal
    else
       skmb=.false.
    end if

    ! Check we have necessary input fields ----------------------------------------------------------

    if (params%enmabal) then
       if (.not.(present(humid).and.present(lwdown).and. &
            present(swdown).and.present(airpress))) &
            call write_log('Necessary fields not supplied for Energy Balance Mass Balance model',GM_FATAL,__FILE__,__LINE__)
    end if

    ! Set averaging start if necessary and return if this is not a mass-balance timestep
    ! Still not sure if this is the correct solution, but should prevent averaging of one-
    ! too-many steps at first

    if (params%first) then
       params%av_start_time=time
       params%first=.false.
       return
    endif

    ! Reset output flag

    if (present(output_flag)) output_flag=.false.
    if (present(ice_tstep))   ice_tstep=.false.

    ! ---------------------------------------------------------
    ! Do averaging and so on...
    ! Averages
    ! ---------------------------------------------------------

    params%g_av_temp    = params%g_av_temp    + temp
    params%g_av_precip  = params%g_av_precip  + precip

    if (params%need_winds) params%g_av_zonwind = params%g_av_zonwind + zonwind
    if (params%need_winds) params%g_av_merwind = params%g_av_merwind + merwind

    if (params%enmabal) then
       params%g_av_humid    = params%g_av_humid    + humid
       params%g_av_lwdown   = params%g_av_lwdown   + lwdown
       params%g_av_swdown   = params%g_av_swdown   + swdown
       params%g_av_airpress = params%g_av_airpress + airpress
    endif

    ! Ranges of temperature

    where (temp > params%g_max_temp) params%g_max_temp=temp
    where (temp < params%g_min_temp) params%g_min_temp=temp

    ! Increment step counter

    params%av_steps=params%av_steps+1

    ! ---------------------------------------------------------
    ! If this is a timestep, prepare global fields, and do a timestep
    ! for each model instance
    ! ---------------------------------------------------------

    if (time-params%av_start_time.ge.params%tstep_mbal) then

       ! Set output_flag

       ! At present, outputs are done for each mass-balance timestep, since
       ! that involved least change to the code. However, it might be good
       ! to change the output to occur with user-specified frequency.

       if (present(output_flag)) output_flag=.true.

       ! Allocate output fields

       allocate(orog_out_temp(size(orog_out,1),size(orog_out,2)))
       allocate(albedo_temp(size(orog,1),size(orog,2)))
       allocate(if_temp(size(orog,1),size(orog,2)))
       allocate(vf_temp(size(orog,1),size(orog,2)))
       allocate(sif_temp(size(orog,1),size(orog,2)))
       allocate(svf_temp(size(orog,1),size(orog,2)))
       allocate(sd_temp(size(orog,1),size(orog,2)))
       allocate(wout_temp(size(orog,1),size(orog,2)))
       allocate(win_temp(size(orog,1),size(orog,2)))

       ! Populate output flag derived type

       out_f%orog         = present(orog_out)
       out_f%albedo       = present(albedo)
       out_f%ice_frac     = present(ice_frac)
       out_f%veg_frac     = present(veg_frac)
       out_f%snowice_frac = present(snowice_frac)
       out_f%snowveg_frac = present(snowveg_frac)
       out_f%snow_depth   = present(snow_depth)
       out_f%water_out    = present(water_out)
       out_f%water_in     = present(water_in)
       out_f%total_win    = present(total_water_in)
       out_f%total_wout   = present(total_water_out)
       out_f%ice_vol      = present(ice_volume)

       ! Zero outputs if present

       if (present(orog_out))        orog_out        = 0.0
       if (present(albedo))          albedo          = 0.0
       if (present(ice_frac))        ice_frac        = 0.0
       if (present(veg_frac))        veg_frac        = 0.0
       if (present(snowice_frac))    snowice_frac    = 0.0
       if (present(snowveg_frac))    snowveg_frac    = 0.0
       if (present(snow_depth))      snow_depth      = 0.0
       if (present(water_out))       water_out       = 0.0
       if (present(water_in))        water_in        = 0.0
       if (present(total_water_in))  total_water_in  = 0.0
       if (present(total_water_out)) total_water_out = 0.0
       if (present(ice_volume))      ice_volume      = 0.0

       ! Calculate averages by dividing by number of steps elapsed
       ! since last model timestep.

       params%g_av_temp    = params%g_av_temp   /real(params%av_steps)
       params%g_av_precip  = params%g_av_precip /real(params%av_steps)
       if (params%need_winds) params%g_av_zonwind = params%g_av_zonwind/real(params%av_steps)
       if (params%need_winds) params%g_av_merwind = params%g_av_merwind/real(params%av_steps)
       if (params%enmabal) then
          params%g_av_humid    = params%g_av_humid   /real(params%av_steps)
          params%g_av_lwdown   = params%g_av_lwdown  /real(params%av_steps)
          params%g_av_swdown   = params%g_av_swdown  /real(params%av_steps)
          params%g_av_airpress = params%g_av_airpress/real(params%av_steps)
       endif

       ! Calculate total accumulated precipitation - multiply
       ! by time since last model timestep

       params%g_av_precip = params%g_av_precip*(time-params%av_start_time)*hours2seconds

       ! Calculate temperature half-range

       params%g_temp_range=(params%g_max_temp-params%g_min_temp)/2.0

       ! Do a timestep for each instance

       do i=1,params%ninstances
          call glint_i_tstep(time,&
               params%instances(i),          &
               params%g_av_temp,             &
               params%g_temp_range,          &
               params%g_av_precip,           &
               params%g_av_zonwind,          &
               params%g_av_merwind,          &
               params%g_av_humid,            &
               params%g_av_lwdown,           &
               params%g_av_swdown,           &
               params%g_av_airpress,         &
               orog,                         &
               orog_out_temp,                &
               albedo_temp,                  &
               if_temp,                      &
               vf_temp,                      &
               sif_temp,                     &
               svf_temp,                     &
               sd_temp,                      &
               win_temp,                     &
               wout_temp,                    &
               twin_temp,                    &
               twout_temp,                   &
               icevol_temp,                  &
               out_f,                        &
               .true.,                       &
               skmb,                         &
               icets)

          ! Add this contribution to the output orography

          if (present(orog_out)) orog_out=splice_field(orog_out,orog_out_temp, &
               params%instances(i)%frac_cov_orog,params%cov_norm_orog)

          if (present(albedo)) albedo=splice_field(albedo,albedo_temp, &
               params%instances(i)%frac_coverage,params%cov_normalise)

          if (present(ice_frac)) ice_frac=splice_field(ice_frac,if_temp, &
               params%instances(i)%frac_coverage,params%cov_normalise)

          if (present(veg_frac)) veg_frac=splice_field(veg_frac,vf_temp, &
               params%instances(i)%frac_coverage,params%cov_normalise)

          if (present(snowice_frac))snowice_frac=splice_field(snowice_frac,sif_temp, &
               params%instances(i)%frac_coverage,params%cov_normalise)

          if (present(snowveg_frac)) snowveg_frac=splice_field(snowveg_frac, &
               svf_temp,params%instances(i)%frac_coverage, params%cov_normalise)

          if (present(snow_depth)) snow_depth=splice_field(snow_depth, &
               sd_temp,params%instances(i)%frac_coverage,params%cov_normalise)

          if (present(water_in)) water_in=splice_field(water_in,win_temp, &
               params%instances(i)%frac_coverage,params%cov_normalise)

          if (present(water_out)) water_out=splice_field(water_out, &
               wout_temp, params%instances(i)%frac_coverage,params%cov_normalise)

          ! Add total water variables to running totals

          if (present(total_water_in))  total_water_in  = total_water_in  + twin_temp
          if (present(total_water_out)) total_water_out = total_water_out + twout_temp
          if (present(ice_volume))      ice_volume      = ice_volume      + icevol_temp

          ! Set flag
          if (present(ice_tstep)) then
             ice_tstep=(ice_tstep.or.icets)
          end if

       enddo

       ! Scale output water fluxes to be in mm/s

       if (present(water_in)) water_in=water_in/ &
            ((time-params%av_start_time)*hours2seconds)

       if (present(water_out)) water_out=water_out/ &
            ((time-params%av_start_time)*hours2seconds)

       ! ---------------------------------------------------------
       ! Reset averaging fields, flags and counters
       ! ---------------------------------------------------------

       params%g_av_temp    = 0.0
       params%g_av_precip  = 0.0
       params%g_av_zonwind = 0.0
       params%g_av_merwind = 0.0
       params%g_av_humid   = 0.0
       params%g_av_lwdown  = 0.0
       params%g_av_swdown  = 0.0
       params%g_av_airpress = 0.0
       params%g_temp_range = 0.0
       params%g_max_temp   = -1000.0
       params%g_min_temp   = 1000.0

       params%av_steps     = 0
       params%av_start_time = time

       deallocate(albedo_temp,if_temp,vf_temp,sif_temp,svf_temp,sd_temp,wout_temp,win_temp,orog_out_temp)

    endif

  end subroutine glint

  !===================================================================

  subroutine end_glint(params)

    !*FD perform tidying-up operations for glimmer
    use glint_initialise
    implicit none

    type(glint_params),intent(inout) :: params          !*FD parameters for this run

    integer i
    ! end individual instances

    do i=1,params%ninstances
       call glint_i_end(params%instances(i))
    enddo

  end subroutine end_glint

  !=====================================================

  integer function glint_coverage_map(params,coverage,cov_orog)

    !*FD Retrieve ice model fractional 
    !*FD coverage map. This function is provided so that glimmer may
    !*FD be restructured without altering the interface.
    !*RV Three return values are possible:
    !*RV \begin{description}
    !*RV \item[0 ---] Successful return
    !*RV \item[1 ---] Coverage map not calculated yet (fail)
    !*RV \item[2 ---] Coverage array is the wrong size (fail)
    !*RV \end{description}

    implicit none

    type(glint_params),intent(in) :: params         !*FD ice model parameters
    real(rk),dimension(:,:),intent(out) :: coverage !*FD array to hold coverage map
    real(rk),dimension(:,:),intent(out) :: cov_orog !*FD Orography coverage

    if (.not.params%coverage_calculated) then
       glint_coverage_map=1
       return
    endif

    if (size(coverage,1).ne.params%g_grid%nx.or. &
         size(coverage,2).ne.params%g_grid%ny) then
       glint_coverage_map=2
       return
    endif

    glint_coverage_map=0
    coverage=params%total_coverage
    cov_orog=params%total_cov_orog

  end function glint_coverage_map

  !----------------------------------------------------------------------
  ! PRIVATE INTERNAL GLIMMER SUBROUTINES FOLLOW.............
  !----------------------------------------------------------------------

  subroutine glint_allocate_arrays(params)

    !*FD allocates glimmer arrays

    implicit none

    type(glint_params),intent(inout) :: params !*FD ice model parameters

    allocate(params%g_av_precip (params%g_grid%nx,params%g_grid%ny))
    allocate(params%g_av_temp   (params%g_grid%nx,params%g_grid%ny))
    allocate(params%g_max_temp  (params%g_grid%nx,params%g_grid%ny))
    allocate(params%g_min_temp  (params%g_grid%nx,params%g_grid%ny))
    allocate(params%g_temp_range(params%g_grid%nx,params%g_grid%ny))
    allocate(params%g_av_zonwind(params%g_grid%nx,params%g_grid%ny))
    allocate(params%g_av_merwind(params%g_grid%nx,params%g_grid%ny))
    allocate(params%g_av_humid  (params%g_grid%nx,params%g_grid%ny))
    allocate(params%g_av_lwdown (params%g_grid%nx,params%g_grid%ny))
    allocate(params%g_av_swdown (params%g_grid%nx,params%g_grid%ny))
    allocate(params%g_av_airpress(params%g_grid%nx,params%g_grid%ny))

    allocate(params%total_coverage(params%g_grid%nx,params%g_grid%ny))
    allocate(params%cov_normalise (params%g_grid%nx,params%g_grid%ny))

    allocate(params%total_cov_orog(params%g_grid_orog%nx,params%g_grid_orog%ny))
    allocate(params%cov_norm_orog (params%g_grid_orog%nx,params%g_grid_orog%ny))

  end subroutine glint_allocate_arrays

  !========================================================

  function splice_field(global,local,coverage,normalise)

    !*FD Splices an upscaled field into a global field

    real(rk),dimension(:,:),intent(in) :: global    !*FD Field to receive the splice
    real(rk),dimension(:,:),intent(in) :: local     !*FD The field to be spliced in
    real(rk),dimension(:,:),intent(in) :: coverage  !*FD The coverage fraction
    real(rk),dimension(:,:),intent(in) :: normalise !*FD The normalisation field

    real(rk),dimension(size(global,1),size(global,2)) :: splice_field

    where (coverage==0.0)
       splice_field=global
    elsewhere
       splice_field=(global*(1-coverage/normalise))+(local*coverage/normalise)
    end where

  end function splice_field

  !========================================================

  subroutine glint_readconfig(params,config)

    !*FD read global parameters for GLINT model

    use glimmer_config
    use glimmer_log
    implicit none

    ! Arguments -------------------------------------------

    type(glint_params),intent(inout) :: params !*FD ice model parameters
    type(ConfigSection), pointer :: config     !*FD structure holding sections of configuration file

    ! Internal variables ----------------------------------

    type(ConfigSection), pointer :: section
    character(len=100) :: message

    ! -----------------------------------------------------
    ! If there's a section called 'GLINT' in the config file,
    ! then we use that information to overwrite the defaults.
    ! Otherwise, it's one instance with a timestep of one year.

    call GetSection(config,section,'GLINT')
    if (associated(section)) then
       call GetValue(section,'n_instance',params%ninstances)
    end if

    ! Print some configuration information

    call write_log('GLINT global')
    call write_log('------------')
    write(message,*) 'number of instances :',params%ninstances
    call write_log(message)
    call write_log('')

  end subroutine glint_readconfig

  !========================================================

  subroutine calc_bounds(lon,lat,lonb,latb)

    !*FD Calculates the boundaries between
    !*FD global grid-boxes. Note that we assume that the boundaries lie 
    !*FD half-way between the 
    !*FD points, both latitudinally and longitudinally, although 
    !*FD this isn't strictly true for a Gaussian grid.

    implicit none

    real(rk),dimension(:),intent(in) :: lon,lat    !*FD locations of global grid-points (degrees)
    real(rk),dimension(:),intent(out) :: lonb,latb !*FD boundaries of grid-boxes (degrees)

    real(rk) :: dlon

    integer :: nxg,nyg,i,j

    nxg=size(lon) ; nyg=size(lat)

    ! Latitudes first - we assume the boundaries of the first and 
    ! last boxes coincide with the poles. Not sure how to
    ! handle it if they don't...

    latb(1)=90.0
    latb(nyg+1)=-90.0

    do j=2,nyg
       latb(j)=lat(j-1)-(lat(j-1)-lat(j))/2.0
    enddo

    ! Longitudes

    if (lon(1)<lon(nxg)) then
       dlon=lon(1)-lon(nxg)+360.0
    else
       dlon=lon(1)-lon(nxg)
    endif
    lonb(1)=lon(nxg)+dlon/2
    lonb(1)=loncorrect(lonb(1))      

    lonb(nxg+1)=lonb(1)

    do i=2,nxg
       if (lon(i)<lon(i-1)) then
          dlon=lon(i)-lon(i-1)+360.0
       else
          dlon=lon(i)-lon(i-1)
       endif
       lonb(i)=lon(i-1)+dlon/2
       lonb(i)=loncorrect(lonb(i))      
    enddo

  end subroutine calc_bounds


  !========================================================

  real(rk) function check_mbts(timesteps)

    !*FD Checks to see that all mass-balance time-steps are
    !*FD the same. Flags a fatal error if not, else assigns that
    !*FD value to the output

    use glimmer_log

    implicit none

    integer,dimension(:) :: timesteps !*FD Array of mass-balance timsteps

    integer :: n,i

    n=size(timesteps)
    if (n==0) then
       check_mbts=0
       return
    endif

    check_mbts=timesteps(1)

    do i=2,n
       if (timesteps(i)/=check_mbts) then
          call write_log('All instances must have the same mass-balance and ice timesteps', &
               GM_FATAL,__FILE__,__LINE__)
       endif
    enddo

  end function check_mbts

  !========================================================

  subroutine check_init_args(orog_lats,orog_longs,orog_latb,orog_lonb)

    !*FD Checks which combination arguments have been supplied to
    !*FD define the global grid, and rejects unsuitable combinations

    use glimmer_log

    real(rk),dimension(:),optional,intent(in) :: orog_lats 
    real(rk),dimension(:),optional,intent(in) :: orog_longs 
    real(rk),dimension(:),optional,intent(in) :: orog_latb
    real(rk),dimension(:),optional,intent(in) :: orog_lonb 

    integer :: args
    integer,dimension(5) :: allowed=(/0,3,7,11,15/)

    args=0

    if (present(orog_lats))  args=args+1
    if (present(orog_longs)) args=args+2
    if (present(orog_latb))  args=args+4
    if (present(orog_lonb))  args=args+8

    if (.not.any(args==allowed)) then
       call write_log('Unexpected combination of arguments to initialise_glint', &
            GM_FATAL,__FILE__,__LINE__)
    end if

  end subroutine check_init_args

end module glint_main

