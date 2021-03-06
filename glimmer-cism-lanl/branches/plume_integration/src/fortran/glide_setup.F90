! +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
! +                                                           +
! +  glide_setup.f90 - part of the GLIMMER ice model        + 
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

#ifdef HAVE_CONFIG_H
#include "config.inc"
#endif

#include "glide_mask.inc"

module glide_setup
  use glimmer_global, only: dp
  !*FD Contains general routines for initialisation, etc, called
  !*FD from the top-level glimmer subroutines.

  private
  public :: glide_readconfig, glide_printconfig, glide_scale_params, &
       glide_calclsrf, glide_load_sigma, &
       glide_read_sigma, glide_calc_sigma

contains
  
  subroutine glide_readconfig(model,config)
    !*FD read GLIDE configuration file
    use glide_types
    use glimmer_config
    implicit none
    type(glide_global_type) :: model        !*FD model instance
    type(ConfigSection), pointer :: config  !*FD structure holding sections of configuration file
    
    ! local variables
    type(ConfigSection), pointer :: section

    ! read grid size  parameters
    call GetSection(config,section,'grid')
    if (associated(section)) then
       call handle_grid(section, model)
    end if
    ! read time parameters
    call GetSection(config,section,'time')
    if (associated(section)) then
       call handle_time(section, model)
    end if
    ! read options parameters
    call GetSection(config,section,'options')
    if (associated(section)) then
       call handle_options(section, model)
    end if
    !read options for higher-order computation
    call GetSection(config,section,'ho_options')
    if (associated(section)) then
        call handle_ho_options(section, model)
    end if

    ! read parameters
    call GetSection(config,section,'parameters')
    if (associated(section)) then
       call handle_parameters(section, model)
    end if
    ! read GTHF 
    call GetSection(config,section,'GTHF')
    if (associated(section)) then
       model%options%gthf = 1
       call handle_gthf(section, model)
    end if
  end subroutine glide_readconfig

  subroutine glide_printconfig(model)
    !*FD print model configuration to log
    use glimmer_log
    use glide_types
    implicit none
    type(glide_global_type)  :: model !*FD model instance

    call write_log_div
    call print_grid(model)
    call print_time(model)
    call print_options(model)
    call print_parameters(model)
    call print_gthf(model)
  end subroutine glide_printconfig
    
  subroutine glide_scale_params(model)
    !*FD scale parameters
    use glide_types
    use glimmer_physcon,  only: scyr, gn
    use glimmer_paramets, only: thk0,tim0,len0, vel0, vis0, acc0!, evs0
    implicit none
    type(glide_global_type)  :: model !*FD model instance

!    tau0 = (vel0/(vis0*len0))**(1.0/gn)    !*sfp* moved back to glimmer_paramets.F90
!    evs0 = tau0 * (len0/vel0)

    model%numerics%ntem = model%numerics%ntem * model%numerics%tinc
    model%numerics%nvel = model%numerics%nvel * model%numerics%tinc

    model%numerics%dt     = model%numerics%tinc * scyr / tim0
    model%numerics%dttem  = model%numerics%ntem * scyr / tim0 
    model%numerics%thklim = model%numerics%thklim  / thk0

    model%numerics%dew = model%numerics%dew / len0
    model%numerics%dns = model%numerics%dns / len0

    model%numerics%mlimit = model%numerics%mlimit / thk0

    model%velowk%trc0   = vel0 * len0 / (thk0**2)
    model%velowk%btrac_const = model%paramets%btrac_const/model%velowk%trc0/scyr
    model%velowk%btrac_max = model%paramets%btrac_max/model%velowk%trc0/scyr
    model%velowk%btrac_slope = model%paramets%btrac_slope*acc0/model%velowk%trc0

  end subroutine glide_scale_params

  subroutine glide_read_sigma(model,config)
    !*FD read sigma levels from configuration file
    use glide_types
    use glimmer_config
    implicit none
    type(glide_global_type) :: model        !*FD model instance
    type(ConfigSection), pointer :: config  !*FD structure holding sections of configuration file
        
    ! local variables
    type(ConfigSection), pointer :: section

    ! read grid size  parameters
    call GetSection(config,section,'sigma')
    if (associated(section)) then
       call handle_sigma(section, model)
    end if

  end subroutine glide_read_sigma

!-------------------------------------------------------------------------

!++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

  subroutine glide_calclsrf(thck,topg,eus,lsrf)

    !*FD Calculates the elevation of the lower surface of the ice, 
    !*FD by considering whether it is floating or not.

    use glimmer_global, only : dp
    use glimmer_physcon, only : rhoi, rhoo

    implicit none

    real(dp), intent(in),  dimension(:,:) :: thck !*FD Ice thickness
    real(dp), intent(in),  dimension(:,:) :: topg !*FD Bedrock topography elevation
    real, intent(in)                      :: eus  !*FD global sea level
    real(dp), intent(out), dimension(:,:) :: lsrf !*FD Lower ice surface elevation

    real(dp), parameter :: con = - rhoi / rhoo

    where (topg-eus < con * thck)
      lsrf = con * thck
    elsewhere
      lsrf = topg
    end where
  end subroutine glide_calclsrf

 !-------------------------------------------------------------------------


  subroutine glide_load_sigma(model,unit)

    !*FD Loads a file containing
    !*FD sigma vertical coordinates.
    use glide_types
    use glimmer_log
    use glimmer_filenames
    use glimmer_global, only: dp
    implicit none

    ! Arguments
    type(glide_global_type),intent(inout) :: model !*FD Ice model to use
    integer,               intent(in)    :: unit  !*FD Logical file unit to use. 
                                                  !*FD The logical file unit specified 
                                                  !*FD must not already be in use
    
    ! Internal variables

    integer  :: up,upn
    logical  :: there
    real(dp) :: level
    ! Beginning of code

    upn=model%general%upn

    
    select case(model%options%which_sigma)
    case(0)
       call write_log('Calculating sigma levels')
       do up=1,upn
          level = real(up-1)/real(upn-1)
          model%numerics%sigma(up) = glide_find_level(level, model%options%which_sigma_builtin, up, upn)
       end do
    case(1)
       inquire (exist=there,file=process_path(model%funits%sigfile))
       if (.not.there) then
          call write_log('Sigma levels file: '//trim(process_path(model%funits%sigfile))// &
               ' does not exist',GM_FATAL)
       end if
       call write_log('Reading sigma file: '//process_path(model%funits%sigfile))
       open(unit,file=process_path(model%funits%sigfile))
       read(unit,'(f9.7)',err=10,end=10) (model%numerics%sigma(up), up=1,upn)
       close(unit)
    case(2)
       call write_log('Using sigma levels from main configuration file')
    end select
    call print_sigma(model)
    return

10  call write_log('something wrong with sigma coord file',GM_FATAL)
    
  end subroutine glide_load_sigma

  function glide_find_level(level, scheme, up, upn)

  !Returns the sigma coordinate of one level using a specific builtin scheme

    use glide_types
    use glimmer_global, only: dp
    real(dp) :: level
    integer  :: scheme, up, upn
    real(dp) :: glide_find_level

    select case(scheme)
      case (SIGMA_BUILTIN_DEFAULT)
        glide_find_level = glide_calc_sigma(level,2D0)
      case (SIGMA_BUILTIN_EVEN)
        glide_find_level = level
      case (SIGMA_BUILTIN_PATTYN)
        if (up == 1) then
          glide_find_level = 0
        else if (up == upn) then
          glide_find_level = 1
        else
           glide_find_level = glide_calc_sigma_pattyn(level)
        end if
    end select
     
  end function glide_find_level

  function glide_calc_sigma(x,n)
      use glimmer_global, only:dp
      implicit none
      real(dp) :: glide_calc_sigma,x,n
      
      glide_calc_sigma = (1-(x+1)**(-n))/(1-2**(-n))
  end function glide_calc_sigma

  !Implements an alternate set of sigma levels that encourages better
  !convergance for higher-order velocities
  function glide_calc_sigma_pattyn(x)
        use glimmer_global, only:dp
        implicit none
        real(dp) :: glide_calc_sigma_pattyn, x

        glide_calc_sigma_pattyn=(-2.5641025641D-4)*(41D0*x)**2+3.5256410256D-2*(41D0*x)-&
          8.0047080075D-13
  end function glide_calc_sigma_pattyn

  !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
  ! private procedures
  !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
  ! grid sizes
  subroutine handle_grid(section, model)
    use glimmer_config
    use glide_types
    implicit none
    type(ConfigSection), pointer :: section
    type(glide_global_type)  :: model

    call GetValue(section,'ewn',model%general%ewn)
    call GetValue(section,'nsn',model%general%nsn)
    call GetValue(section,'upn',model%general%upn)
    call GetValue(section,'dew',model%numerics%dew)
    call GetValue(section,'dns',model%numerics%dns)
    call GetValue(section,'sigma_file',model%funits%sigfile)
    call GetValue(section,'sigma_builtin',model%options%which_sigma_builtin)

    ! We set this flag to one to indicate we've got a sigfile name.
    ! A warning/error is generated if sigma levels are specified in some other way
    if (trim(model%funits%sigfile)/='') then 
        model%options%which_sigma=1
    end if

  end subroutine handle_grid

  subroutine print_grid(model)
    use glide_types
    use glimmer_log
    implicit none
    type(glide_global_type)  :: model
    character(len=512) :: message
    call write_log('Grid specification')
    call write_log('------------------')
    write(message,*) 'ewn             : ',model%general%ewn
    call write_log(trim(message))
    write(message,*) 'nsn             : ',model%general%nsn
    call write_log(trim(message))
    write(message,*) 'upn             : ',model%general%upn
    call write_log(trim(message))
    write(message,*) 'EW grid spacing : ',model%numerics%dew
    call write_log(trim(message))
    write(message,*) 'NS grid spacing : ',model%numerics%dns
    call write_log(trim(message))
    call write_log(trim('sigma file      : '//model%funits%sigfile))
    call write_log('')
  end subroutine print_grid

  ! time
  subroutine handle_time(section, model)
    use glimmer_config
    use glide_types
    implicit none
    type(ConfigSection), pointer :: section
    type(glide_global_type)  :: model

    call GetValue(section,'tstart',model%numerics%tstart)
    call GetValue(section,'tend',model%numerics%tend)
    call GetValue(section,'dt',model%numerics%tinc)
    call GetValue(section,'ntem',model%numerics%ntem)
    call GetValue(section,'nvel',model%numerics%nvel)
    call GetValue(section,'profile',model%numerics%profile_period)
    call GetValue(section,'ndiag',model%numerics%ndiag)
  end subroutine handle_time
  
  subroutine print_time(model)
    use glide_types
    use glimmer_log
    implicit none
    type(glide_global_type)  :: model
    character(len=100) :: message

    call write_log('Time steps')
    call write_log('----------')
    write(message,*) 'start time        : ',model%numerics%tstart
    call write_log(message)
    write(message,*) 'end time          : ',model%numerics%tend
    call write_log(message)
    write(message,*) 'main time step    : ',model%numerics%tinc
    call write_log(message)
    write(message,*) 'thermal dt factor : ',model%numerics%ntem
    call write_log(message)
    write(message,*) 'velo dt factor    : ',model%numerics%nvel
    call write_log(message)
    write(message,*) 'profile frequency : ',model%numerics%profile_period
    call write_log(message)
    write(message,*) 'diag frequency    : ',model%numerics%ndiag
    call write_log(message) 
    call write_log('')
  end subroutine print_time

  ! options
  subroutine handle_options(section, model)
    use glimmer_config
    use glide_types
    implicit none
    type(ConfigSection), pointer :: section
    type(glide_global_type)  :: model

    call GetValue(section,'ioparams',model%funits%ncfile)
    call GetValue(section,'temperature',model%options%whichtemp)
    call GetValue(section,'flow_law',model%options%whichflwa)
    call GetValue(section,'basal_water',model%options%whichbwat)
    call GetValue(section,'marine_margin',model%options%whichmarn)
    call GetValue(section,'slip_coeff',model%options%whichbtrc)
    call GetValue(section,'evolution',model%options%whichevol)
    call GetValue(section,'vertical_integration',model%options%whichwvel)
    call GetValue(section,'topo_is_relaxed',model%options%whichrelaxed)
    call GetValue(section,'hotstart',model%options%hotstart)
    call GetValue(section,'periodic_ew',model%options%periodic_ew)
    call GetValue(section,'periodic_ns',model%options%periodic_ns)
    call GetValue(section,'diagnostic_run',model%options%diagnostic_run)
    call GetValue(section, 'use_plume',model%options%use_plume)
  end subroutine handle_options
  
  !Higher order options
  subroutine handle_ho_options(section, model)
    use glimmer_config
    use glide_types
    implicit none
    type(ConfigSection), pointer :: section
    type(glide_global_type) :: model
    
    call GetValue(section, 'diagnostic_scheme',  model%options%which_ho_diagnostic)
    call GetValue(section, 'prognostic_scheme',  model%options%which_ho_prognostic)
    call GetValue(section, 'basal_stress_input', model%options%which_ho_beta_in)
    call GetValue(section, 'basal_stress_type',  model%options%which_ho_bstress)
    call GetValue(section, 'guess_specified',    model%velocity_hom%is_velocity_valid)
    call GetValue(section, 'which_ho_source',    model%options%which_ho_source)
    call GetValue(section, 'include_thin_ice',   model%options%ho_include_thinice)
!whl - added Price-Payne higher-order (glam) options
    call GetValue(section, 'which_ho_babc',      model%options%which_ho_babc)
    call GetValue(section, 'which_ho_efvs',      model%options%which_ho_efvs)
    call GetValue(section, 'which_ho_resid',     model%options%which_ho_resid)
    call GetValue(section, 'which_ho_sparse',    model%options%which_ho_sparse)
    call GetValue(section, 'which_ho_sparse_fallback', model%options%which_ho_sparse_fallback)
  end subroutine handle_ho_options

  subroutine print_options(model)
    use glide_types
    use glimmer_log
    implicit none
    type(glide_global_type)  :: model
    character(len=500) :: message

    ! local variables
    character(len=*), dimension(0:1), parameter :: temperature = (/ &
         'isothermal', &
         'full      '/)
    character(len=*), dimension(0:2), parameter :: flow_law = (/ &
         'Patterson and Budd               ', &
         'Patterson and Budd (temp=-10degC)', &
         'const 1e-16a^-1Pa^-n             '/)
    character(len=*), dimension(0:3), parameter :: basal_water = (/ &
         'local water balance', &
         'local + const flux ', &
         'flux calculation   ', &
         'none               ' /)
    character(len=*), dimension(0:6), parameter :: marine_margin = (/ &
         'ignore            ', &
         'no ice shelf      ', &
         'threshold         ', &
         'const calving rate', &
         'edge threshold    ', &
         'van der Veen      ', &
         'Pattyn Grnd Line  '/)
    character(len=*), dimension(0:5), parameter :: slip_coeff = (/ &
         'zero        ', &
         'const       ', &
         'const if T>0', &
         '~basal water', &
         '~basal melt ', &
         'taub^3      ' /)
    character(len=*), dimension(0:4), parameter :: evolution = (/ &
         'pseudo-diffusion                      ', &
         'ADI scheme                            ', &
         'iterated diffusion                    ', &
         'remap thickness                       ', &   ! *sfp** added
         '1st order upwind                      ' /)   ! *sfp** added for summer modeling school 
    character(len=*), dimension(0:1), parameter :: vertical_integration = (/ &
         'standard     ', &
         'obey upper BC' /)
    character(len=*), dimension(0:3), parameter :: ho_diagnostic = (/ &
         'Do not compute higher-order velocities', &
         'Pattyn 2003 (on A-grid)               ', &
         'Pattyn 2003 (on B-grid)               ', &
         'Payne/Price (on B-grid)               ' /)    !*sfp** added
    character(len=*), dimension(0:3), parameter :: ho_prognostic = (/ &
         'Evolve ice with SIA only', &
         'Pattyn scheme           ', &
         'Pollard scheme          ', &
         'Bueler scheme           ' /)
    character(len=*), dimension(0:4), parameter :: ho_beta_in = (/ &
         'All NaN (ice glued to bed)', &
         '1/soft                    ', &
         '1/btrc                    ', &
         'beta field from input     ', &
         'slip ratio (ISMIP-HOM F)  '/)
    character(len=*), dimension(0:1), parameter :: ho_bstress = (/ &
         'Linear bed (betasquared)', &
         'Plastic bed (tau0)      ' /)

!whl - added Price-Payne higher-order (glam) options
    character(len=*), dimension(0:9), parameter :: ho_whichbabc = (/ &
         'constant betasquared    ', &
         'simple pattern          ', &
         'read map from file      ', &
         'simple till yield stress', &
         'yield stress from model ', &
         'simple 2D ice shelf     ', &
         'spatially periodic      ', &
         'circular ice shelf      ', &
         'frozen bed              ', &
         'B^2 passed from CISM    ' /)
    character(len=*), dimension(0:2), parameter :: ho_whichefvs = (/ &
         'from eff strain rate    ', &
         'constant value          ', &
         'minimum value           ' /)
    character(len=*), dimension(0:2), parameter :: ho_whichresid = (/ &
         'max value               ', &
         'max value ignoring ubas ', &
         'mean value              ' /)
    character(len=*), dimension(0:2), parameter :: ho_whichsource = (/ &
         'vertically averaged     ', &
         'vertically explicit     ', &
         'shelf front disabled    '/)
    character(len=*), dimension(0:3), parameter :: ho_whichsparse = (/ &
         'BiCG with LU precondition         ', &
         'GMRES with LU precondition        ', &
         'UMFPACK Unsymmetric Multifrontal  ',&
         'PARDISO Parllel Direct Method     '/)
    call write_log('GLIDE options')
    call write_log('-------------')
    write(message,*) 'I/O parameter file      : ',trim(model%funits%ncfile)
    call write_log(message)
    if (model%options%whichtemp.lt.0 .or. model%options%whichtemp.ge.size(temperature)) then
       call write_log('Error, temperature out of range',GM_FATAL)
    end if
    write(message,*) 'temperature calculation : ',model%options%whichtemp,temperature(model%options%whichtemp)
    call write_log(message)
    if (model%options%whichflwa.lt.0 .or. model%options%whichflwa.ge.size(flow_law)) then
       call write_log('Error, flow_law out of range',GM_FATAL)
    end if
    write(message,*) 'flow law                : ',model%options%whichflwa,flow_law(model%options%whichflwa)
    call write_log(message)
    if (model%options%whichbwat.lt.0 .or. model%options%whichbwat.ge.size(basal_water)) then
       call write_log('Error, basal_water out of range',GM_FATAL)
    end if
    write(message,*) 'basal_water             : ',model%options%whichbwat,basal_water(model%options%whichbwat)
    call write_log(message)
    if (model%options%whichmarn.lt.0 .or. model%options%whichmarn.ge.size(marine_margin)) then
       call write_log('Error, marine_margin out of range',GM_FATAL)
    end if
    write(message,*) 'marine_margin           : ', model%options%whichmarn, marine_margin(model%options%whichmarn)
    call write_log(message)
    if (model%options%whichbtrc.lt.0 .or. model%options%whichbtrc.ge.size(slip_coeff)) then
       call write_log('Error, slip_coeff out of range',GM_FATAL)
    end if
    write(message,*) 'slip_coeff              : ', model%options%whichbtrc, slip_coeff(model%options%whichbtrc)
    call write_log(message)
    if (model%options%whichevol.lt.0 .or. model%options%whichevol.ge.size(evolution)) then
       call write_log('Error, evolution out of range',GM_FATAL)
    end if
    write(message,*) 'evolution               : ', model%options%whichevol, evolution(model%options%whichevol)
    call write_log(message)
    if (model%options%whichwvel.lt.0 .or. model%options%whichwvel.ge.size(vertical_integration)) then
       call write_log('Error, vertical_integration out of range',GM_FATAL)
    end if
    write(message,*) 'vertical_integration    : ',model%options%whichwvel,vertical_integration(model%options%whichwvel)
    call write_log(message)
    if (model%options%whichrelaxed.eq.1) then
       call write_log('First topo time slice is relaxed')
    end if
    if (model%options%periodic_ew) then
       if (model%options%whichevol .eq. EVOL_ADI) then
          call write_log('Periodic boundary conditions not implemented in ADI scheme',GM_FATAL)
       end if
       call write_log('Periodic EW lateral boundary condition')
       call write_log('  Slightly cheated with how temperature is implemented.',GM_WARNING)
    end if
    if (model%options%hotstart.eq.1) then
       call write_log('Hotstarting model')
    end if
    if (model%options%use_plume.eq.1) then
       call write_log('Using plume model to calculate bmlt below floating ice')
    else
       call write_log('Using glimmer to calculate bmlt everywhere')
    end if

    !HO options
    call write_log("***Higher-order options:")
    if (model%options%which_ho_diagnostic < 0 .or. model%options%which_ho_diagnostic >= size(ho_diagnostic)) then
        call write_log('Error, diagnostic_scheme out of range', GM_FATAL)
    end if
    write(message,*) 'ho_diagnostic           :',model%options%which_ho_diagnostic, &
                       ho_diagnostic(model%options%which_ho_diagnostic)
    call write_log(message)
    
    if (model%options%which_ho_prognostic < 0 .or. model%options%which_ho_prognostic >= size(ho_prognostic)) then
        call write_log('Error, prognostic_scheme out of range', GM_FATAL)
    end if
    write(message,*) 'ho_prognostic           :',model%options%which_ho_prognostic, &
                       ho_prognostic(model%options%which_ho_prognostic)
    call write_log(message)
    
    if (model%options%which_ho_beta_in < 0 .or. model%options%which_ho_beta_in >= size(ho_beta_in)) then
        call write_log('Error, basal_stress_input out of range', GM_FATAL)
    end if
    write(message,*) 'basal_stress_input      :',model%options%which_ho_beta_in, &
                       ho_beta_in(model%options%which_ho_beta_in)
    call write_log(message)

    if (model%options%which_ho_bstress < 0 .or. model%options%which_ho_bstress >= size(ho_bstress)) then
        call write_log('Error, basal_stress_input out of range', GM_FATAL)
    end if
    write(message,*) 'basal_stress_type       :',model%options%which_ho_bstress, &
                       ho_bstress(model%options%which_ho_bstress)
    call write_log(message)

    if (model%options%which_ho_source < 0 .or. model%options%which_ho_source >= size(ho_whichsource)) then
        call write_log('Error, which_ho_source out of range', GM_FATAL)
    end if
    write(message,*) 'ice_shelf_source_term   :',model%options%which_ho_source, &
                       ho_whichsource(model%options%which_ho_source)
    call write_log(message)

!whl - added Payne-Price higher-order (glam) options
    write(message,*) 'ho_whichbabc          :',model%options%which_ho_babc,  &
                      ho_whichbabc(model%options%which_ho_babc)
    call write_log(message)
    if (model%options%which_ho_babc < 0 .or. model%options%which_ho_babc >= size(ho_whichbabc)) then
        call write_log('Error, HO basal BC input out of range', GM_FATAL)
    end if
    write(message,*) 'ho_whichefvs          :',model%options%which_ho_efvs,  &
                      ho_whichefvs(model%options%which_ho_efvs)
    call write_log(message)
    if (model%options%which_ho_efvs < 0 .or. model%options%which_ho_efvs >= size(ho_whichefvs)) then
        call write_log('Error, HO effective viscosity input out of range', GM_FATAL)
    end if
    write(message,*) 'ho_whichresid         :',model%options%which_ho_resid,  &
                      ho_whichresid(model%options%which_ho_resid)
    call write_log(message)
    if (model%options%which_ho_resid < 0 .or. model%options%which_ho_resid >= size(ho_whichresid)) then
        call write_log('Error, HO residual input out of range', GM_FATAL)
    end if

    write(message,*) 'ho_whichsparse        :',model%options%which_ho_sparse,  &
                      ho_whichsparse(model%options%which_ho_sparse)
    call write_log(message)
    if (model%options%which_ho_sparse < 0 .or. model%options%which_ho_sparse >= size(ho_whichsparse)) then
        call write_log('Error, HO sparse solver input out of range', GM_FATAL)
    end if


    call write_log('')
  end subroutine print_options

  ! parameters
  subroutine handle_parameters(section, model)
    use glimmer_config
    use glide_types
    use glimmer_log
    implicit none
    type(ConfigSection), pointer :: section
    type(glide_global_type)  :: model
    real, pointer, dimension(:) :: temp => NULL()
    integer :: loglevel

    loglevel = GM_levels-GM_ERROR

    call GetValue(section,'log_level',loglevel)
    call glimmer_set_msg_level(loglevel)
    call GetValue(section,'ice_limit',model%numerics%thklim)
    call GetValue(section,'marine_limit',model%numerics%mlimit)
    call GetValue(section,'calving_fraction',model%numerics%calving_fraction)
    call GetValue(section,'geothermal',model%paramets%geot)
    call GetValue(section,'flow_factor',model%paramets%flow_factor)
    call GetValue(section,'default_flwa',model%paramets%default_flwa)
    call GetValue(section,'hydro_time',model%paramets%hydtim)
    call GetValue(section,'basal_tract',temp,5)
    if (associated(temp)) then
       model%paramets%btrac_const=temp(1)
       deallocate(temp)
    end if
    call GetValue(section,'basal_tract_const',model%paramets%btrac_const)
    call GetValue(section,'basal_tract_max',model%paramets%btrac_max)
    call GetValue(section,'basal_tract_slope',model%paramets%btrac_slope)
    call GetValue(section,'stressin',model%climate%stressin)
    call GetValue(section,'stressout',model%climate%stressout)
    call GetValue(section,'sliding_constant',model%climate%slidconst)
  end subroutine handle_parameters

  subroutine print_parameters(model)
    use glide_types
    use glimmer_log
    implicit none
    type(glide_global_type)  :: model
    character(len=100) :: message

    call write_log('Parameters')
    call write_log('----------')
    write(message,*) 'ice limit             : ',model%numerics%thklim
    call write_log(message)
    write(message,*) 'marine depth limit    : ',model%numerics%mlimit
    call write_log(message)
    if (model%options%whichmarn.eq.3) then
       write(message,*) 'ice fraction lost due to calving :', model%numerics%calving_fraction
       call write_log(message)
    end if
    write(message,*) 'geothermal heat flux  : ',model%paramets%geot
    call write_log(message)
    write(message,*) 'flow enhancement      : ',model%paramets%flow_factor
    call write_log(message)
    write(message,*) 'basal hydro time const: ',model%paramets%hydtim
    call write_log(message)
    if (model%options%whichbtrc.eq.1 .or. model%options%whichbtrc.eq.2 .or. model%options%whichbtrc.eq.4) then
       write(message,*) 'basal traction param  : ',model%paramets%btrac_const
       call write_log(message)
    end if
    if (model%options%whichbtrc.eq.4) then
       write(message,*) 'basal traction max  : ',model%paramets%btrac_max
       call write_log(message)
       write(message,*) 'basal traction slope  : ',model%paramets%btrac_slope
       call write_log(message)
    end if
    if (model%options%whichbtrc.eq.3) then
       write(message,*) 'basal traction factors: ',model%paramets%bpar(1)
       call write_log(message)
       write(message,*) '                        ',model%paramets%bpar(2)
       call write_log(message)
       write(message,*) '                        ',model%paramets%bpar(3)
       call write_log(message)
       write(message,*) '                        ',model%paramets%bpar(4)
       call write_log(message)
       write(message,*) '                        ',model%paramets%bpar(5)
       call write_log(message)
    end if
    call write_log('')
  end subroutine print_parameters

  ! Sigma levels
  subroutine handle_sigma(section, model)
    use glimmer_config
    use glide_types
    use glimmer_log
    implicit none
    type(ConfigSection), pointer :: section
    type(glide_global_type)  :: model

    if (model%options%which_sigma==1) then
       call write_log('Sigma levels specified twice - use only'// &
            ' config file or separate file, not both',GM_FATAL)
    else
       model%options%which_sigma = 2
       call GetValue(section,'sigma_levels',model%numerics%sigma,model%general%upn)
    end if

  end subroutine handle_sigma

  subroutine print_sigma(model)
    use glide_types
    use glimmer_log
    implicit none
    type(glide_global_type)  :: model
    character(len=100) :: message,temp
    integer :: i

    call write_log('Sigma levels:')
    call write_log('------------------')
    message=''
    do i=1,model%general%upn
       write(temp,'(F5.2)') model%numerics%sigma(i)
       message=trim(message)//trim(temp)
    enddo
    call write_log(trim(message))
    call write_log('')
    
  end subroutine print_sigma

  ! geothermal heat flux calculations
  subroutine handle_gthf(section, model)
    use glimmer_config
    use glide_types
    implicit none
    type(ConfigSection), pointer :: section
    type(glide_global_type)  :: model

    call GetValue(section,'num_dim',model%lithot%num_dim)
    call GetValue(section,'nlayer',model%lithot%nlayer)
    call GetValue(section,'surft',model%lithot%surft)
    call GetValue(section,'rock_base',model%lithot%rock_base)
    call GetValue(section,'numt',model%lithot%numt)
    call GetValue(section,'rho',model%lithot%rho_r)
    call GetValue(section,'shc',model%lithot%shc_r)
    call GetValue(section,'con',model%lithot%con_r)
  end subroutine handle_gthf

  subroutine print_gthf(model)
    use glide_types
    use glimmer_log
    implicit none
    type(glide_global_type)  :: model
    character(len=100) :: message
    
    if (model%options%gthf.gt.0) then
       call write_log('GTHF configuration')
       call write_log('------------------')
       if (model%lithot%num_dim.eq.1) then
          call write_log('solve 1D diffusion equation')
       else if (model%lithot%num_dim.eq.3) then          
          call write_log('solve 3D diffusion equation')
       else
          call write_log('Wrong number of dimensions.',GM_FATAL,__FILE__,__LINE__)
       end if
       write(message,*) 'number of layers                     : ',model%lithot%nlayer
       call write_log(message)
       write(message,*) 'initial surface temperature          : ',model%lithot%surft
       call write_log(message)
       write(message,*) 'rock base                            : ',model%lithot%rock_base
       call write_log(message)
       write(message,*) 'density of rock layer                : ',model%lithot%rho_r
       call write_log(message)
       write(message,*) 'specific heat capacity of rock layer : ',model%lithot%shc_r
       call write_log(message)
       write(message,*) 'thermal conductivity of rock layer   : ',model%lithot%con_r
       call write_log(message)
       write(message,*) 'number of time steps for spin-up     : ',model%lithot%numt
       call write_log(message)
       call write_log('')
    end if
  end subroutine print_gthf

end module glide_setup
