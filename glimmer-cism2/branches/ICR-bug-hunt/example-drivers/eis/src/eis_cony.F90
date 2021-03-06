! +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
! +                                                           +
! +  eis_cony.f90 - part of the Glimmer-CISM ice model        + 
! +                                                           +
! +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
! 
! Copyright (C) 2005, 2006, 2007, 2008, 2009
! Glimmer-CISM contributors - see AUTHORS file for list of contributors
!
! This file is part of Glimmer-CISM.
!
! Glimmer-CISM is free software: you can redistribute it and/or modify
! it under the terms of the GNU General Public License as published by
! the Free Software Foundation, either version 2 of the License, or (at
! your option) any later version.
!
! Glimmer-CISM is distributed in the hope that it will be useful,
! but WITHOUT ANY WARRANTY; without even the implied warranty of
! MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
! GNU General Public License for more details.
!
! You should have received a copy of the GNU General Public License
! along with Glimmer-CISM.  If not, see <http://www.gnu.org/licenses/>.
!
! Glimmer-CISM is hosted on BerliOS.de:
! https://developer.berlios.de/projects/glimmer-cism/
!
! +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

#ifdef HAVE_CONFIG_H
#include "config.inc"
#endif

module eis_cony
  !*FD climate forcing similar to the old Edinburgh Ice Sheet model
  !*FD Magnus Hagdorn, June 2004
  
  !*FD This module reproduces the continentality forcing used to drive the 
  !*FD Edinburgh Ice Sheet model. 

  use searchcircle

  type eis_cony_type
     real :: period = 0.                          !*FD how often cony field should be updated, set to 0 to switch off
     real :: cony_radius = 600000                 !*FD continentality radius
     integer :: update_from_file = 0              !*FD load cony from file
     real :: next_update                          !*FD when the next update occurs
     real,dimension(:,:),pointer :: cony => null()!*FD cony field
     real,dimension(:,:),pointer :: topo => null()!*FD topography mask
     type(searchdata) :: sdata                    !*FD search circle structure
  end type eis_cony_type

contains  
  subroutine eis_cony_config(config,cony)
    !*FD get ELA configuration from config file
    use glimmer_config
    implicit none
    type(eis_cony_type)          :: cony    !*FD cony data
    type(ConfigSection), pointer :: config  !*FD structure holding sections of configuration file   
    ! local variables
    type(ConfigSection), pointer :: section

    call GetSection(config,section,'EIS CONY')
    if (associated(section)) then
       cony%period=500.
       call GetValue(section,'period',cony%period)
       call GetValue(section,'radius',cony%cony_radius)
       call GetValue(section,'file',cony%update_from_file)
       if (cony%update_from_file.eq.1) then
          cony%period = 0
       end if
    end if
  end subroutine eis_cony_config

  subroutine eis_cony_printconfig(cony)
    !*FD print configuration to log
    use glimmer_log
    implicit none
    type(eis_cony_type)      :: cony   !*FD cony data
    ! local variables
    character(len=100) :: message
    call write_log('EIS Continentality')
    call write_log('------------------')
    write(message,*) 'Update Period        : ',cony%period
    call write_log(message)
    write(message,*) 'Continentality radius: ',cony%cony_radius
    call write_log(message)
    if (cony%update_from_file.eq.1) then
       call write_log(' Load continentality from input netCDF file')
    end if
    call write_log('')
  end subroutine eis_cony_printconfig

  subroutine eis_init_cony(cony,model)
    !*FD initialise cony forcing
    use glide_types
    use glimmer_paramets, only: len0
    implicit none
    type(eis_cony_type)     :: cony  !*FD cony data
    type(glide_global_type) :: model !*FD model instance

    integer radius

    ! scale parameters
    cony%cony_radius = cony%cony_radius / len0

    cony%next_update = model%numerics%tstart

    ! allocate data
    allocate(cony%cony(model%general%ewn,model%general%nsn))
    cony%cony = 0.

    if (cony%period.gt.0) then
       allocate(cony%topo(model%general%ewn,model%general%nsn))
       ! initialise search circles
       radius = int(cony%cony_radius/sqrt(model%numerics%dew**2 + model%numerics%dns**2))
       cony%sdata = sc_initdata(radius,1,1,model%general%ewn,model%general%nsn)
    end if
  end subroutine eis_init_cony
  
  subroutine eis_continentality(cony,model,time)
    !*FD calculate continentality field
    use glide_types
    use glide_mask
    use glimmer_global, only : rk
    implicit none
    type(eis_cony_type)       :: cony  !*FD cony data
    type(glide_global_type)   :: model !*FD model instance
    real(kind=rk), intent(in) :: time  !*FD current time
    
    if (cony%period.gt.0 .and. cony%next_update.ge.time) then
       
       where (.not.is_ocean(model%geometry%thkmask) .and. .not.is_float(model%geometry%thkmask))
          cony%topo = 1.
       elsewhere
          cony%topo = 0.
       end where

       call sc_search(cony%sdata,cony%topo,cony%cony)

       where(cony%topo.eq.0.)
          cony%cony = 0.
       elsewhere
          cony%cony =2.*max(cony%cony/cony%sdata%total_area-0.5,0.)
       end where

       cony%next_update = cony%next_update+cony%period
    end if
  end subroutine eis_continentality
end module eis_cony
