! +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
! +                                                           +
! +  glide_stop.f90 - part of the GLIMMER ice model           + 
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

module glide_stop

  use glide_types
  use glimmer_log
  use remap_glamutils

  ! *sfp* added for summer modeling school
  use fo_upwind_advect, only : fo_upwind_advect_final

  ! *mb* added
  use glam_Basal_Proc, only : Basal_Proc_final

  implicit none
  !*FD module containing finalisation of glide
  !*FD this subroutine had to be split out from glide.f90 to avoid
  !*FD circular dependencies
  !*FD Updated by Tim Bocek to allow for several models to be
  !*FD registered and finalized with a single call without needing
  !*FD the model at call time

  integer, parameter :: max_models = 32

  type pmodel_type
    !*FD Contains a pointer to a model
    !*FD This is a hack to get around Fortran's lack of arrays of pointers
    type(glide_global_type), pointer :: p => null()
  end type pmodel_type

  !*FD Pointers to all registered models
  !*FD This has a fixed size at compile time
  type(pmodel_type), dimension(max_models), save :: registered_models

contains
  subroutine register_model(model)
    !*FD Registers a model, ensuring that it is finalised in the case of an error
    type(glide_global_type), target :: model
    integer :: i

    do i = 1, max_models
      if (.not. associated(registered_models(i)%p)) then
         registered_models(i)%p => model
         model%model_id = i
         return
      end if
    end do
    call write_log("Model was not registered, did you instantiate too many instances?", GM_FATAL)
  end subroutine

  subroutine deregister_model(model)
    !*FD Removes a model from the registry.  Normally this should only be done
    !*FD glide_finalise is called on the model, and is done automatically by
    !*FD that function
    type(glide_global_type) :: model

    if (model%model_id < 1 .or. model%model_id > max_models) then
        call write_log("Attempting to deregister a non-allocated model", GM_WARNING) 
    else
        registered_models(model%model_id)%p => null()
        model%model_id = 0
    end if
  end subroutine

  subroutine glide_finalise_all(crash_arg)
    !*FD Finalises all models in the model registry
    logical, optional :: crash_arg
    
    logical :: crash
    integer :: i

    if (present(crash_arg)) then
        crash = crash_arg
    else
        crash = .false.
    end if

    do i = 1,max_models
        if (associated(registered_models(i)%p)) then
            call glide_finalise(registered_models(i)%p, crash)
        end if
    end do 
  end subroutine

  subroutine glide_finalise(model,crash)
    !*FD finalise GLIDE model instance
    use glimmer_ncio
    use glide_io
    use profile
    implicit none
    type(glide_global_type) :: model        !*FD model instance
    logical, optional :: crash              !*FD set to true if the model died unexpectedly
    character(len=100) :: message

    ! force last write if crashed
    if (present(crash)) then
       if (crash) then
          call glide_io_writeall(model,model,.true.)
       end if
    end if

    call closeall_in(model)
    call closeall_out(model)
   
    ! *tjb** added; finalization of LANL incremental remapping subroutine for thickness evolution
    if (model%options%whichevol== EVOL_INC_REMAP ) then
        call horizontal_remap_final(model%remap_wk)
    endif 

   ! *sfp* added for summer modeling school
    if (model%options%whichevol== EVOL_FO_UPWIND ) then
        call fo_upwind_advect_final()
    endif

    ! *mb* added; finalization of Basal Proc module
    if (model%options%which_bmod == BAS_PROC_FULLCALC .or. &
        model%options%which_bmod == BAS_PROC_FASTCALC) then
        call Basal_Proc_final (model%basalproc)
    end if  

    call glide_deallocarr(model)
    call deregister_model(model)

    ! write some statistics
    call write_log('Some Stats')
    write(message,*) 'Maximum temperature iterations: ',model%temper%niter
    call write_log(message)

    ! close profile
#ifdef PROFILING
    call profile_close(model%profile)
#endif

  end subroutine glide_finalise
end module glide_stop
