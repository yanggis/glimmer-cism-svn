! +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
! +                                                           +
! +  eismint3_glide.f90 - part of the GLIMMER ice model       + 
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
#include <config.inc>
#endif

program eismint3_glide

  !*FD This is a simple GLIDE test driver. It can be used to run
  !*FD the EISMINT 3 Greenland test case. Adapted from simple_glide.f90

  use glimmer_global, only:rk,fname_length
  use glide
  use glimmer_log
  use glimmer_config
  use eismint3_forcing
  use eismint3_io
  implicit none

  type(glide_global_type) :: model        ! model instance
  type(eismint3_climate) :: climate
  type(ConfigSection), pointer :: config  ! configuration stuff
  character(len=fname_length) :: fname   ! name of paramter file
  real(kind=rk) time

  write(*,*) 'Enter name of GLIDE configuration file to be read'
  read(*,*) fname
  
  ! start logging
  call open_log(unit=50, fname=logname(fname))
  
  ! read configuration
  call ConfigRead(fname,config)

  ! initialise GLIDE
  call glide_config(model,config)
  call glide_initialise(model)
  call eismint3_initialise(climate,config,model)
  call eismint3_io_createall(model)
  call CheckSections(config)
  ! fill dimension variables
  call glide_nc_fillall(model)
  time = model%numerics%tstart

  do
     call eismint3_clim(climate,model)
     call glide_tstep_p1(model,time)
     call glide_tstep_p2(model)
     call glide_tstep_p3(model)
     call eismint3_io_writeall(climate,model)
     ! override masking stuff for now
     time = time + model%numerics%tinc
     if (time.gt.model%numerics%tend) exit
  end do

  ! finalise GLIDE
  call glide_finalise(model)
  call close_log

end program eismint3_glide
