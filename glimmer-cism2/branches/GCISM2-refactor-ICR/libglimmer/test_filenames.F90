! +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
! +                                                           +
! +  test_filenames.F90 - part of the GLIMMER ice model       + 
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
! GLIMMER is hosted on berliOS.de:
!
! https://developer.berlios.de/projects/glimmer-cism/
!
! +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

#ifdef HAVE_CONFIG_H
#include "config.inc"
#endif

!> testing glimmer_filenames.F90
!!
!! \author Magnus Hagdorn
!! \date September 2009
program test_filenames
  use glimmer_filenames
  implicit none

  character(len=*), parameter :: confname = 'afile.conf'
  character(len=*), parameter :: confdir  = '../adir/bdir/'
  character(len=*), parameter :: infile1 = 'infile1'
  character(len=*), parameter :: infile2 = '/infile2'
  character(len=*), parameter :: infile3 = 'test_filenames'
  character(len=fname_length) :: fname
  
  logical success

  success = .true.

  write(*,'(a)') '** Checking whether it works when not initialised'
  fname = filenames_inputname(infile1)
  write(*,fmt='(4a)',advance='no') '* checking ',trim(infile1),' == ',trim(fname)
  if (trim(fname).eq.trim(infile1)) then
     write(*,*) ' ok'
  else
     write(*,*) ' no'
     success = .false.
  end if
  fname = filenames_inputname(infile2)
  write(*,fmt='(4a)',advance='no') '* checking ',trim(infile2),' == ',trim(fname)
  if (trim(fname).eq.trim(infile2)) then
     write(*,*) ' ok'
  else
     write(*,*) ' no'
     success = .false.
  end if
  fname = filenames_inputname(infile3)
  write(*,fmt='(4a)',advance='no') '* checking ',trim(infile3),' == ',trim(fname)
  if (trim(fname).eq.trim(infile3)) then
     write(*,*) ' ok'
  else
     write(*,*) ' no'
     success = .false.
  end if
  write(*,*)

  write(*,'(a)') '** Checking when there is no path element in config dir'
  call filenames_init(confname)

  fname = filenames_inputname(infile1)
  write(*,fmt='(4a)',advance='no') '* checking ',trim(infile1),' == ',trim(fname)
  if (trim(fname).eq.trim(infile1)) then
     write(*,*) ' ok'
  else
     write(*,*) ' no'
     success = .false.
  end if
  fname = filenames_inputname(infile2)
  write(*,fmt='(4a)',advance='no') '* checking ',trim(infile2),' == ',trim(fname)
  if (trim(fname).eq.trim(infile2)) then
     write(*,*) ' ok'
  else
     write(*,*) ' no'
     success = .false.
  end if
  fname = filenames_inputname(infile3)
  write(*,fmt='(4a)',advance='no') '* checking ',trim(infile3),' == ',trim(fname)
  if (trim(fname).eq.trim(infile3)) then
     write(*,*) ' ok'
  else
     write(*,*) ' no'
     success = .false.
  end if
  write(*,*)

  ! checking in different directory
  write(*,'(a)') '** Checking when config name contains a path'
  call filenames_init(confdir//confname)

  fname = filenames_inputname(infile1)
  write(*,fmt='(4a)',advance='no') '* checking ',trim(confdir//infile1),' == ',trim(fname)
  if (trim(fname).eq.trim(confdir//infile1)) then
     write(*,*) ' ok'
  else
     write(*,*) ' no'
     success = .false.
  end if
  fname = filenames_inputname(infile2)
  write(*,fmt='(4a)',advance='no') '* checking ',trim(infile2),' == ',trim(fname)
  if (trim(fname).eq.trim(infile2)) then
     write(*,*) ' ok'
  else
     write(*,*) ' no'
     success = .false.
  end if
  fname = filenames_inputname(infile3)
  write(*,fmt='(4a)',advance='no') '* checking ',trim(infile3),' == ',trim(fname)
  if (trim(fname).eq.trim(infile3)) then
     write(*,*) ' ok'
  else
     write(*,*) ' no'
     success = .false.
  end if

  if (.not.success) then
     write(*,*) 'some of the tests failed'
     stop 1
  end if
  
end program test_filenames
