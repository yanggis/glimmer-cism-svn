! +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
! +                                                           +
! +  eis_forcing.f90 - part of the GLIMMER ice model          + 
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

module eis_forcing
  !*FD climate forcing similar to the old Edinburgh Ice Sheet model
  !*FD Magnus Hagdorn, June 2004
  
  use eis_types
  
contains
  subroutine eis_initialise(climate,config,model)
    !*FD initialise EIS climate
    use glide_types
    use glimmer_config
    use eis_io
    implicit none
    type(eis_climate_type) :: climate      !*FD structure holding EIS climate
    type(ConfigSection), pointer :: config !*FD structure holding sections of configuration file   
    type(glide_global_type) :: model       !*FD model instance

    ! read config
    call eis_readconfig(climate,config)
    ! print config
    call eis_printconfig(climate)
    ! create eis variables
    call eis_io_createall(model)

    ! initialise subsystems
    call eis_init_cony(climate%cony,model)
    call eis_init_ela(climate%ela,model)
    call eis_init_temp(climate%temp)
    call eis_init_slc(climate%slc)

    ! and read first time slice
    call eis_io_readall(climate,model)

    ! calculate shape of ELA (lat and EW dependence)
    call eis_calc_ela(climate%ela,model)
  end subroutine eis_initialise

  subroutine eis_readconfig(climate,config)
    !*FD read EIS configuration
    use glimmer_config
    implicit none
    type(eis_climate_type) :: climate    !*FD structure holding EIS climate
    type(ConfigSection), pointer :: config  !*FD structure holding sections of configuration file   
 
    call eis_cony_config(config,climate%cony)
    call eis_ela_config(config,climate%ela)
    call eis_temp_config(config,climate%temp)
    call eis_slc_config(config,climate%slc)
  end subroutine eis_readconfig

  subroutine eis_printconfig(climate)
    !*FD print EIS configuration
    use glimmer_log
    implicit none
    type(eis_climate_type) :: climate  !*FD structure holding EIS climate
    
    call write_log_div
    call write_log('Edinburgh Ice Model')
    call eis_cony_printconfig(climate%cony)
    call eis_ela_printconfig(climate%ela)
    call eis_temp_printconfig(climate%temp)
    call eis_slc_printconfig(climate%slc)
  end subroutine eis_printconfig

  subroutine eis_climate(climate,model,time)
    !*FD do the EIS climate forcing
    use glide_types
    use glimmer_global, only : rk    
    implicit none
    type(eis_climate_type) :: climate  !*FD structure holding EIS climate
    type(glide_global_type)   :: model !*FD model instance
    real(kind=rk), intent(in) :: time  !*FD current time
    
    call eis_eus(climate%slc,model,time)
    call eis_continentality(climate%cony,model,time)
    call eis_massbalance(climate%ela,climate%cony,model,time)
    call eis_surftemp(climate%temp,model,time)
  end subroutine eis_climate
    
end module eis_forcing
