! +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
! +                                                           +
! +  glimmer_thck.f90 - part of the GLIMMER ice model         + 
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

#include "glide_nan.inc"

module glide_thck

  use glide_types
  use glide_velo_higher
  use glimmer_sparse
  use glimmer_sparse_type
  use glide_grids

  !DEBUG ONLY, these should be deleted eventually
  use glide_stop
  use xls
  use glide_io
  private
  public :: init_thck, thck_nonlin_evolve, thck_lin_evolve, timeders, &
            stagleapthck, geometry_derivs, &
            geometry_derivs_unstag 

#ifdef DEBUG_PICARD
  ! debugging Picard iteration
  integer, private, parameter :: picard_unit=101
  real, private, parameter    :: picard_interval=500.
  integer, private            :: picard_max=0
#endif

contains

  subroutine init_thck(model)
    !*FD initialise work data for ice thickness evolution
    use glimmer_log
    implicit none
    type(glide_global_type) :: model

    
    model%pcgdwk%fc2 = (/ model%numerics%alpha * model%numerics%dt / (2.0d0 * model%numerics%dew * model%numerics%dew), &
                          model%numerics%dt, &
                          (1.0d0-model%numerics%alpha) / model%numerics%alpha, &
                          1.0d0 / model%numerics%alpha, &
                          model%numerics%alpha * model%numerics%dt / &
                          (2.0d0 * model%numerics%dns * model%numerics%dns), &
                          0.0d0 /) 

#ifdef DEBUG_PICARD
    call write_log('Logging Picard iterations')
    open(picard_unit,name='picard_info.data',status='unknown')
    write(picard_unit,*) '#time    max_iter'
#endif

    ! allocate memory for ADI scheme
    if (model%options%whichevol.eq.1) then
       allocate(model%thckwk%alpha(max(model%general%ewn, model%general%nsn)))
       allocate(model%thckwk%beta (max(model%general%ewn, model%general%nsn)))
       allocate(model%thckwk%gamma(max(model%general%ewn, model%general%nsn)))
       allocate(model%thckwk%delta(max(model%general%ewn, model%general%nsn)))
    end if
  end subroutine init_thck

!---------------------------------------------------------------------------------

  subroutine thck_lin_evolve(model,newtemps)

    !*FD this subroutine solves the linearised ice thickness equation by computing the
    !*FD diffusivity from quantities of the previous time step

    use glide_velo
    use glide_thckmask
    implicit none
    ! subroutine arguments
    type(glide_global_type) :: model
    logical, intent(in) :: newtemps                     !*FD true when we should recalculate Glen's A

    if (model%geometry%empty) then

       model%geometry%thck = dmax1(0.0d0,model%geometry%thck + model%climate%acab * model%pcgdwk%fc2(2))
#ifdef DEBUG       
       print *, "* thck empty - net accumulation added", model%numerics%time
#endif
    else

       call geometry_derivs(model)

       ! calculate basal velos
       if (newtemps) then
          call slipvelo(model,                &
               1,                             &
               model%velocity% btrc,          &
               model%velocity% ubas,          &
               model%velocity% vbas)
          ! calculate Glen's A if necessary
          call velo_integrate_flwa(model%velowk,model%geomderv%stagthck,model%temper%flwa)
       end if

       call slipvelo(model,                &
            2,                             &
            model%velocity% btrc,          &
            model%velocity% ubas,          &
            model%velocity% vbas)

       ! calculate diffusivity
       call velo_calc_diffu(model%velowk,model%geomderv%stagthck,model%geomderv%dusrfdew, &
            model%geomderv%dusrfdns,model%velocity%diffu)

       !Calculate higher-order velocities if the user asked for them
       if (model%options%which_ho_diagnostic /= 0 ) then
            call geometry_derivs_unstag(model)
            call run_ho_diagnostic(model)                          
       end if

       if (model%options%diagnostic_run == 1) then
          call glide_finalise_all(.true.)
          stop
       end if

       if (model%options%which_ho_prognostic == HO_PROG_SIAONLY) then
       ! get new thicknesses
            call thck_evolve(model,model%velocity%diffu, model%velocity%diffu, .true.,model%geometry%thck,model%geometry%thck)
       else if (model%options%which_ho_prognostic == HO_PROG_PATTYN) then
            call thck_evolve(model,model%velocity_hom%diffu_x, model%velocity_hom%diffu_y, .true.,& 
                  model%geometry%thck, model%geometry%thck)
    
       end if

       ! calculate horizontal velocity field
       ! (These calls must appear after thck_evolve, as thck_evolve uses ubas,
       ! which slipvelo mutates)
       call slipvelo(model,                &
            3,                             &
            model%velocity%btrc,           &
            model%velocity%ubas,           &
            model%velocity%vbas)
       call velo_calc_velo(model%velowk,model%geomderv%stagthck,model%geomderv%dusrfdew, &
            model%geomderv%dusrfdns,model%temper%flwa,model%velocity%diffu,model%velocity%ubas, &
            model%velocity%vbas,model%velocity%uvel,model%velocity%vvel,model%velocity%uflx,model%velocity%vflx,&
            model%velocity%surfvel)
    end if
  end subroutine thck_lin_evolve

!---------------------------------------------------------------------------------

  subroutine thck_nonlin_evolve(model,newtemps)

    !*FD this subroutine solves the ice thickness equation by doing an outer, 
    !*FD non-linear iteration to update the diffusivities and in inner, linear
    !*FD iteration to calculate the new ice thickness distrib

    use glimmer_global, only : dp
    use glide_velo
    use glide_setup
    use glide_thckmask
    use glide_nonlin !For unstable manifold correction
    implicit none
    ! subroutine arguments
    type(glide_global_type) :: model
    logical, intent(in) :: newtemps                     !*FD true when we should recalculate Glen's A

    ! local variables
    integer, parameter :: pmax=50                       !*FD maximum Picard iterations
    real(kind=dp), parameter :: tol=1.0d-6
    real(kind=dp) :: residual
    integer p
    logical first_p

#ifdef USE_UNSTABLE_MANIFOLD
    ! local variables used by unstable manifold correction
    real(kind=dp), dimension(model%general%ewn*model%general%nsn) :: umc_new_vec   
    real(kind=dp), dimension(model%general%ewn*model%general%nsn) :: umc_old_vec 
    real(kind=dp), dimension(model%general%ewn*model%general%nsn) :: umc_correction_vec
    logical :: umc_continue_iteration
    integer :: linearize_start

    umc_correction_vec = 0
    umc_new_vec = 0
    umc_old_vec = 0
#endif

    if (model%geometry%empty) then

       model%geometry%thck = dmax1(0.0d0,model%geometry%thck + model%climate%acab * model%pcgdwk%fc2(2))
#ifdef DEBUG
       print *, "* thck empty - net accumulation added", model%numerics%time
#endif
    else

       ! calculate basal velos
       if (newtemps) then
          call slipvelo(model,                &
               1,                             &
               model%velocity% btrc,          &
               model%velocity% ubas,          &
               model%velocity% vbas)
          ! calculate Glen's A if necessary
          call velo_integrate_flwa(model%velowk,model%geomderv%stagthck,model%temper%flwa)
       end if

       first_p = .true.
       model%thckwk%oldthck = model%geometry%thck
       ! do Picard iteration
       model%thckwk%oldthck2 = model%geometry%thck
       do p=1,pmax
          
          call geometry_derivs(model)

          call slipvelo(model,                &
               2,                             &
               model%velocity% btrc,          &
               model%velocity% ubas,          &
               model%velocity% vbas)

          ! calculate diffusivity
          call velo_calc_diffu(model%velowk,model%geomderv%stagthck,model%geomderv%dusrfdew, &
               model%geomderv%dusrfdns,model%velocity%diffu)

       !Calculate higher-order velocities if the user asked for them
       if (model%options%which_ho_diagnostic /= 0 ) then
            call geometry_derivs_unstag(model)
            call run_ho_diagnostic(model)                          
       end if

 
       if (model%options%which_ho_prognostic == HO_PROG_SIAONLY) then
       ! get new thicknesses
            call thck_evolve(model,model%velocity%diffu, model%velocity%diffu, .true.,model%geometry%thck,model%geometry%thck)
       else if (model%options%which_ho_prognostic == HO_PROG_PATTYN) then
            

            call thck_evolve(model,model%velocity_hom%diffu_x, model%velocity_hom%diffu_y, .true.,& 
                  model%geometry%thck, model%geometry%thck)
    
       end if

          first_p = .false.
#ifdef USE_UNSTABLE_MANIFOLD
          linearize_start = 1
          call linearize_2d(umc_new_vec, linearize_start, model%geometry%thck)
          linearize_start = 1
          call linearize_2d(umc_old_vec, linearize_start, model%thckwk%oldthck2)
          umc_continue_iteration = unstable_manifold_correction(umc_new_vec, umc_old_vec, &
                                                                umc_correction_vec, size(umc_correction_vec),&
                                                                tol)
          !Only the old thickness might change as a result of this call
           linearize_start = 1
           call delinearize_2d(umc_old_vec, linearize_start, model%thckwk%oldthck2)
          
          if (umc_continue_iteration) then
            exit
          end if
#else
          residual = maxval(abs(model%geometry%thck-model%thckwk%oldthck2))
          if (residual.le.tol) then
             exit
          end if
          model%thckwk%oldthck2 = model%geometry%thck
#endif

       end do
#ifdef DEBUG_PICARD
       picard_max=max(picard_max,p)
       if (model%numerics%tinc > mod(model%numerics%time,picard_interval)) then
          write(picard_unit,*) model%numerics%time,p
          picard_max = 0
       end if
#endif

       ! calculate horizontal velocity field
       call slipvelo(model,                &
            3,                             &
            model%velocity%btrc,           &
            model%velocity%ubas,           &
            model%velocity%vbas)
       call velo_calc_velo(model%velowk,model%geomderv%stagthck,model%geomderv%dusrfdew, &
            model%geomderv%dusrfdns,model%temper%flwa,model%velocity%diffu,model%velocity%ubas, &
            model%velocity%vbas,model%velocity%uvel,model%velocity%vvel,model%velocity%uflx,model%velocity%vflx,&
            model%velocity%surfvel)


    end if
  end subroutine thck_nonlin_evolve

!---------------------------------------------------------------------------------

  
  subroutine thck_evolve(model,diffu_x, diffu_y,calc_rhs,old_thck,new_thck)

    !*FD set up sparse matrix and solve matrix equation to find new ice thickness distribution
    !*FD this routine does not override the old thickness distribution

    use glide_setup, only: glide_calclsrf
    use glimmer_global, only : dp
    use glide_stop
    use glimmer_log
#if DEBUG
    use glimmer_paramets, only: vel0, thk0
#endif
    implicit none

    ! subroutine arguments -------------------------------------------------------------

    type(glide_global_type) :: model
    logical,intent(in) :: calc_rhs                      !*FD set to true when rhs should be calculated 
                                                        !*FD i.e. when doing lin solution or first picard iteration
    real(dp), intent(in), dimension(:,:) :: diffu_x
    real(dp), intent(in), dimension(:,:) :: diffu_y
    real(dp), intent(in), dimension(:,:) :: old_thck    !*FD contains ice thicknesses from previous time step
    real(dp), intent(inout), dimension(:,:) :: new_thck !*FD on entry contains first guess for new ice thicknesses
                                                        !*FD on exit contains ice thicknesses of new time step

    ! local variables ------------------------------------------------------------------

    real(dp), dimension(5) :: sumd 
    real(dp) :: err
    integer :: linit
    integer :: ew,ns

    ! Zero the arrays holding the sparse matrix
    call sparse_clear(model%pcgdwk%matrix)

    ! Set the order of the matrix
    model%pcgdwk%matrix%order = model%geometry%totpts
    
    ! Boundary Conditions ---------------------------------------------------------------
    ! lower and upper BC
    do ew = 1,model%general%ewn
       ns=1
       if (model%geometry%mask(ew,ns) /= 0) then
          call sparse_insert_val(model%pcgdwk%matrix, model%geometry%mask(ew,ns), model%geometry%mask(ew,ns), 1d0)
          if (calc_rhs) then
             model%pcgdwk%rhsd(model%geometry%mask(ew,ns)) = old_thck(ew,ns) 
          end if
          model%pcgdwk%answ(model%geometry%mask(ew,ns)) = new_thck(ew,ns)
       end if
       ns=model%general%nsn
       if (model%geometry%mask(ew,ns) /= 0) then
          call sparse_insert_val(model%pcgdwk%matrix, model%geometry%mask(ew,ns), model%geometry%mask(ew,ns), 1d0)
          if (calc_rhs) then
             model%pcgdwk%rhsd(model%geometry%mask(ew,ns)) = old_thck(ew,ns) 
          end if
          model%pcgdwk%answ(model%geometry%mask(ew,ns)) = new_thck(ew,ns)
       end if
    end do

    !left and right BC
    if (model%options%periodic_ew) then
       do ns=2,model%general%nsn-1
          ew = 1
          if (model%geometry%mask(ew,ns) /= 0) then
             call findsums(model%general%ewn-2,model%general%ewn-1,ns-1,ns)
             call generate_row(model%general%ewn-2,ew,ew+1,ns-1,ns,ns+1)
          end if
          ew=model%general%ewn
          if (model%geometry%mask(ew,ns) /= 0) then
             call findsums(1,2,ns-1,ns)
             call generate_row(ew-1,ew,3,ns-1,ns,ns+1)
          end if
       end do
    else
       do ns=2,model%general%nsn-1
          ew=1
          if (model%geometry%mask(ew,ns) /= 0) then
             call sparse_insert_val(model%pcgdwk%matrix, model%geometry%mask(ew,ns), model%geometry%mask(ew,ns), 1d0)
             if (calc_rhs) then
                model%pcgdwk%rhsd(model%geometry%mask(ew,ns)) = old_thck(ew,ns) 
             end if
             model%pcgdwk%answ(model%geometry%mask(ew,ns)) = new_thck(ew,ns)
          end if
          ew=model%general%ewn
          if (model%geometry%mask(ew,ns) /= 0) then
             call sparse_insert_val(model%pcgdwk%matrix, model%geometry%mask(ew,ns), model%geometry%mask(ew,ns), 1d0)
             if (calc_rhs) then
                model%pcgdwk%rhsd(model%geometry%mask(ew,ns)) = old_thck(ew,ns) 
             end if
             model%pcgdwk%answ(model%geometry%mask(ew,ns)) = new_thck(ew,ns)
          end if
       end do
    end if

    ! ice body -------------------------------------------------------------------------

    do ns = 2,model%general%nsn-1
       do ew = 2,model%general%ewn-1
          if (model%geometry%mask(ew,ns) /= 0) then
                
             call findsums(ew-1,ew,ns-1,ns)
             call generate_row(ew-1,ew,ew+1,ns-1,ns,ns+1)

          end if
       end do
    end do

    ! Solve the system using SLAP
    call sparse_easy_solve(model%pcgdwk%matrix, model%pcgdwk%rhsd, model%pcgdwk%answ, &
                           err, linit)
    
    ! Rejig the solution onto a 2D array
    do ns = 1,model%general%nsn
       do ew = 1,model%general%ewn 
          if (model%geometry%mask(ew,ns) /= 0) then
             new_thck(ew,ns) = model%pcgdwk%answ(model%geometry%mask(ew,ns))
          end if

       end do
    end do

    new_thck = max(0.0d0, new_thck)

#ifdef DEBUG
    print *, "* thck ", model%numerics%time, linit, model%geometry%totpts, &
         real(thk0*new_thck(model%general%ewn/2+1,model%general%nsn/2+1)), &
         real(vel0*maxval(abs(model%velocity%ubas))), real(vel0*maxval(abs(model%velocity%vbas))) 
#endif

    ! calculate upper and lower surface
    call glide_calclsrf(model%geometry%thck, model%geometry%topg, model%climate%eus, model%geometry%lsrf)
    model%geometry%usrf = max(0.d0,model%geometry%thck + model%geometry%lsrf)

  contains

    subroutine generate_row(ewm,ew,ewp,nsm,ns,nsp)
      ! calculate row of sparse matrix equation
      implicit none
      integer, intent(in) :: ewm,ew,ewp  ! ew index to left, central, right node
      integer, intent(in) :: nsm,ns,nsp  ! ns index to lower, central, upper node

      !fill matrix using the new API
      call sparse_insert_val(model%pcgdwk%matrix, model%geometry%mask(ew,ns), model%geometry%mask(ewm,ns), sumd(1)) ! point (ew-1,ns)
      call sparse_insert_val(model%pcgdwk%matrix, model%geometry%mask(ew,ns), model%geometry%mask(ewp,ns), sumd(2)) ! point (ew+1,ns)
      call sparse_insert_val(model%pcgdwk%matrix, model%geometry%mask(ew,ns), model%geometry%mask(ew,nsm), sumd(3)) ! point (ew,ns-1)
      call sparse_insert_val(model%pcgdwk%matrix, model%geometry%mask(ew,ns), model%geometry%mask(ew,nsp), sumd(4)) ! point (ew,ns+1)
      call sparse_insert_val(model%pcgdwk%matrix, model%geometry%mask(ew,ns), model%geometry%mask(ew,ns),  1d0 + sumd(5))! point (ew,ns)

      ! calculate RHS
      if (calc_rhs) then
         model%pcgdwk%rhsd(model%geometry%mask(ew,ns)) =                    &
              old_thck(ew,ns) * (1.0d0 - model%pcgdwk%fc2(3) * sumd(5))     &
            - model%pcgdwk%fc2(3) * (old_thck(ewm,ns) * sumd(1)             &
                                   + old_thck(ewp,ns) * sumd(2)             &
                                   + old_thck(ew,nsm) * sumd(3)             &
                                   + old_thck(ew,nsp) * sumd(4))            &
            - model%pcgdwk%fc2(4) * (model%geometry%lsrf(ew,ns)  * sumd(5)  &
                                   + model%geometry%lsrf(ewm,ns) * sumd(1)  &
                                   + model%geometry%lsrf(ewp,ns) * sumd(2)  &
                                   + model%geometry%lsrf(ew,nsm) * sumd(3)  &
                                   + model%geometry%lsrf(ew,nsp) * sumd(4)) &
            + model%climate%acab(ew,ns) * model%pcgdwk%fc2(2)
      end if

      model%pcgdwk%answ(model%geometry%mask(ew,ns)) = new_thck(ew,ns)      

    end subroutine generate_row

    subroutine findsums(ewm,ew,nsm,ns)
      ! calculate diffusivities
      implicit none
      integer, intent(in) :: ewm,ew  ! ew index to left, right
      integer, intent(in) :: nsm,ns  ! ns index to lower, upper

      ! calculate sparse matrix elements
      sumd(1) = model%pcgdwk%fc2(1) * (&
           (diffu_x(ewm,nsm) + diffu_x(ewm,ns)) + &
           (model%velocity%ubas (ewm,nsm) + model%velocity%ubas (ewm,ns)))
      sumd(2) = model%pcgdwk%fc2(1) * (&
           (diffu_x(ew,nsm) + diffu_x(ew,ns)) + &
           (model%velocity%ubas (ew,nsm) + model%velocity%ubas (ew,ns)))
      sumd(3) = model%pcgdwk%fc2(5) * (&
           (diffu_y(ewm,nsm) + diffu_y(ew,nsm)) + &
           (model%velocity%ubas (ewm,nsm) + model%velocity%ubas (ew,nsm)))
      sumd(4) = model%pcgdwk%fc2(5) * (&
           (diffu_y(ewm,ns) + diffu_y(ew,ns)) + &
           (model%velocity%ubas (ewm,ns) + model%velocity%ubas (ew,ns)))
      sumd(5) = - (sumd(1) + sumd(2) + sumd(3) + sumd(4))
    end subroutine findsums
  end subroutine thck_evolve




!---------------------------------------------------------------

  subroutine geometry_derivs(model)
     use glide_mask, only: upwind_from_mask
     implicit none

     !*FD Computes derivatives of the ice and bed geometry, as well as averaging
     !*FD them onto the staggered grid
     type(glide_global_type), intent(inout) :: model

     call stagthickness(model%geometry% thck, &
               model%geomderv%stagthck,&
               model%general%ewn, &
               model%general%nsn, &
               model%geometry%usrf, &
               model%numerics%thklim, &
               model%geometry%thkmask)
      
     call stagvarb(model%geometry%lsrf, &
               model%geomderv%staglsrf,&
               model%general%ewn, &
               model%general%nsn)

     call stagvarb(model%geometry%topg, &
               model%geomderv%stagtopg,&
               model%general%ewn, &
               model%general%nsn)


     model%geomderv%stagusrf = model%geomderv%staglsrf + model%geomderv%stagthck

      
     call df_field_2d_staggered(model%geometry%usrf, &
                                     model%numerics%dew, model%numerics%dns, &
                                     model%geomderv%dusrfdew, & 
                                     model%geomderv%dusrfdns, &
                                     .false., .false.)

     call df_field_2d_staggered(model%geometry%thck, &
                                     model%numerics%dew, model%numerics%dns, &
                                     model%geomderv%dthckdew, &
                                     model%geomderv%dthckdns, &
                                     .false., .false.)
     
      !Make sure that the derivatives are 0 where staggered thickness is 0
      where (model%geomderv%stagthck == 0)
             model%geomderv%dusrfdew = 0
             model%geomderv%dusrfdns = 0
             model%geomderv%dthckdew = 0
             model%geomderv%dthckdns = 0
      endwhere

      !TODO: correct signs
      model%geomderv%dlsrfdew = model%geomderv%dusrfdew - model%geomderv%dthckdew
      model%geomderv%dlsrfdns = model%geomderv%dusrfdns - model%geomderv%dthckdns
        
      !Compute second derivatives.
      !TODO: Turn this on and off conditionally based on whether the computation
      !is requred
      
      !Compute seond derivatives
      !TODO: maybe turn this on and off conditionally?
      call d2f_field_stag(model%geometry%usrf, model%numerics%dew, model%numerics%dns, &
                          model%geomderv%d2usrfdew2, model%geomderv%d2usrfdns2, &
                          .false., .false.)

      call d2f_field_stag(model%geometry%thck, model%numerics%dew, model%numerics%dns, &
                          model%geomderv%d2thckdew2, model%geomderv%d2thckdns2, &
                          .false., .false.)
 
  end subroutine

  !*FD Computes derivatives of the geometry onto variables on a nonstaggered
  !*FD grid.  Used for some higher-order routines
  subroutine geometry_derivs_unstag(model)
     implicit none
     type(glide_global_type) :: model

     !Fields allow us to upwind derivatives at the ice sheet lateral boundaries
     !so that we're not differencing out of the domain
     real(dp), dimension(model%general%ewn, model%general%nsn) :: direction_x, direction_y

     call upwind_from_mask(model%geometry%thkmask, direction_x, direction_y)
     call write_xls("direction_x_unstag.txt", direction_x)
     call write_xls("direction_y_unstag.txt", direction_y)
     !Compute first derivatives of geometry
     call df_field_2d(model%geometry%usrf, model%numerics%dew, model%numerics%dns, &
                      model%geomderv%dusrfdew_unstag, model%geomderv%dusrfdns_unstag, &
                      .false., .false., direction_x, direction_y)

     call df_field_2d(model%geometry%lsrf, model%numerics%dew, model%numerics%dns, &
                      model%geomderv%dlsrfdew_unstag, model%geomderv%dlsrfdns_unstag, &
                      .false., .false., direction_x, direction_y)

     call df_field_2d(model%geometry%thck, model%numerics%dew, model%numerics%dns, &
                      model%geomderv%dthckdew_unstag, model%geomderv%dthckdns_unstag, &
                      .false., .false., direction_x, direction_y)

     call d2f_field(model%geometry%usrf, model%numerics%dew, model%numerics%dns, &
                          model%geomderv%d2usrfdew2_unstag, model%geomderv%d2usrfdns2_unstag, &
                          direction_x, direction_y)

     call d2f_field(model%geometry%thck, model%numerics%dew, model%numerics%dns, &
                          model%geomderv%d2thckdew2_unstag, model%geomderv%d2thckdns2_unstag, &
                          direction_x, direction_y)
  

  end subroutine

!---------------------------------------------------------------------------------

  subroutine timeders(thckwk,ipvr,opvr,mask,time,which)

    use glimmer_global, only : dp, sp
    use glimmer_paramets, only : conv

    implicit none 

    type(glide_thckwk) :: thckwk
    real(dp), intent(out), dimension(:,:) :: opvr 
    real(dp), intent(in), dimension(:,:) :: ipvr
    real(sp), intent(in) :: time 
    integer, intent(in), dimension(:,:) :: mask
    integer, intent(in) :: which

    real(sp) :: factor

    factor = (time - thckwk%oldtime)
    if (factor .eq.0) then
       opvr = 0.0d0
    else
       factor = 1./factor
       where (mask /= 0)
          opvr = conv * (ipvr - thckwk%olds(:,:,which)) * factor
       elsewhere
          opvr = 0.0d0
       end where
    end if

    thckwk%olds(:,:,which) = ipvr

    if (which == thckwk%nwhich) then
      thckwk%oldtime = time
    end if

  end subroutine timeders

!---------------------------------------------------------------------------------

  subroutine filterthck(thck,ewn,nsn)

    use glimmer_global, only : dp ! ew, ewn, ns, nsn

    implicit none

    real(dp), dimension(:,:), intent(inout) :: thck
    real(dp), dimension(:,:), allocatable :: smth
    integer :: ewn,nsn

    real(dp), parameter :: f = 0.1d0 / 16.0d0
    integer :: count
    integer :: ns,ew

    allocate(smth(ewn,nsn))
    count = 1

    do ns = 3,nsn-2
      do ew = 3,ewn-2

        if (all((thck(ew-2:ew+2,ns) > 0.0d0)) .and. all((thck(ew,ns-2:ns+2) > 0.0d0))) then
          smth(ew,ns) =  thck(ew,ns) + f * &
                        (thck(ew-2,ns) - 4.0d0 * thck(ew-1,ns) + 12.0d0 * thck(ew,ns) - &
                         4.0d0 * thck(ew+1,ns) + thck(ew+2,ns) + &
                         thck(ew,ns-2) - 4.0d0 * thck(ew,ns-1) - &
                         4.0d0 * thck(ew,ns+1) + thck(ew,ns+2))
          count = count + 1
        else
          smth(ew,ns) = thck(ew,ns)
        end if

      end do
    end do

    thck(3:ewn-2,3:nsn-2) = smth(3:ewn-2,3:nsn-2)
    print *, count

    deallocate(smth)            

  end subroutine filterthck

!----------------------------------------------------------------------

  subroutine swapbndh(bc,a,b,c,d)

    use glimmer_global, only : dp

    implicit none

    real(dp), intent(out), dimension(:) :: a, c
    real(dp), intent(in), dimension(:) :: b, d
    integer, intent(in) :: bc

    if (bc == 0) then
      a = b
      c = d
    end if

  end subroutine swapbndh

  !-----------------------------------------------------------------------------
  ! ADI routines
  !-----------------------------------------------------------------------------

  subroutine stagleapthck(model,newtemps)
    
    !*FD this subroutine solves the ice sheet thickness equation using the ADI scheme
    !*FD diffusivities are updated for each half time step

    use glide_setup, only: glide_calclsrf
    use glide_velo
    use glimmer_utils
    implicit none
    ! subroutine arguments
    type(glide_global_type) :: model
    logical, intent(in) :: newtemps                     !*FD true when we should recalculate Glen's A

    ! local variables
    integer ew,ns, n

    if (model%geometry%empty) then

       model%geometry%thck = dmax1(0.0d0,model%geometry%thck + model%climate%acab * model%pcgdwk%fc2(2))
#ifdef DEBUG       
       print *, "* thck empty - net accumulation added", model%numerics%time
#endif
    else

       ! calculate basal velos
       if (newtemps) then
          call slipvelo(model,                &
               1,                             &
               model%velocity% btrc,          &
               model%velocity% ubas,          &
               model%velocity% vbas)
          ! calculate Glen's A if necessary
          call velo_integrate_flwa(model%velowk,model%geomderv%stagthck,model%temper%flwa)
       end if
       call slipvelo(model,                &
            2,                             &
            model%velocity% btrc,          &
            model%velocity% ubas,          &
            model%velocity% vbas)

       ! calculate diffusivity
       call velo_calc_diffu(model%velowk,model%geomderv%stagthck,model%geomderv%dusrfdew, &
            model%geomderv%dusrfdns,model%velocity%diffu)

       model%velocity%total_diffu(:,:) = model%velocity%diffu(:,:) + model%velocity%ubas(:,:)

       ! first ADI step, solve thickness equation along rows j
       n = model%general%ewn
       do ns=2,model%general%nsn-1
          call adi_tri ( model%thckwk%alpha,                 &
                         model%thckwk%beta,                  &
                         model%thckwk%gamma,                 &
                         model%thckwk%delta,                 &
                         model%geometry%thck(:,ns),          &
                         model%geometry%lsrf(:,ns),          &
                         model%climate%acab(:,ns),           &
                         model%velocity%vflx(:,ns),          &
                         model%velocity%vflx(:,ns-1),        &
                         model%velocity%total_diffu(:,ns),   &
                         model%velocity%total_diffu(:,ns-1), &
                         model%numerics%dt,                  &
                         model%numerics%dew,                 &
                         model%numerics%dns )

          call tridiag(model%thckwk%alpha(1:n),    &
                       model%thckwk%beta(1:n),     &
                       model%thckwk%gamma(1:n),    &
                       model%thckwk%oldthck(:,ns), &
                       model%thckwk%delta(1:n))
       end do

       model%thckwk%oldthck(:,:) = max(model%thckwk%oldthck(:,:), 0.d0)

       ! second ADI step, solve thickness equation along columns i
       n = model%general%nsn
       do ew=2,model%general%ewn-1
          call adi_tri ( model%thckwk%alpha,                 &
                         model%thckwk%beta,                  &
                         model%thckwk%gamma,                 &
                         model%thckwk%delta,                 &
                         model%thckwk%oldthck(ew,:),         &
                         model%geometry%lsrf(ew, :),         &
                         model%climate%acab(ew, :),          &
                         model%velocity%uflx(ew,:),          &
                         model%velocity%uflx(ew-1,:),        &
                         model%velocity%total_diffu(ew,:),   &
                         model%velocity%total_diffu(ew-1,:), &
                         model%numerics%dt,                  &
                         model%numerics%dns,                 &
                         model%numerics%dew )

          call tridiag(model%thckwk%alpha(1:n),    &
                       model%thckwk%beta(1:n),     &
                       model%thckwk%gamma(1:n),    &
                       model%geometry%thck(ew, :), &
                       model%thckwk%delta(1:n))
       end do

       model%geometry%thck(:,:) = max(model%geometry%thck(:,:), 0.d0)

       ! Apply boundary conditions
       model%geometry%thck(1,:) = 0.0
       model%geometry%thck(model%general%ewn,:) = 0.0
       model%geometry%thck(:,1) = 0.0
       model%geometry%thck(:,model%general%nsn) = 0.0

       ! calculate horizontal velocity field
       call slipvelo(model,                &
            3,                             &
            model%velocity%btrc,           &
            model%velocity%ubas,           &
            model%velocity%vbas)
       call velo_calc_velo(model%velowk,model%geomderv%stagthck,model%geomderv%dusrfdew, &
            model%geomderv%dusrfdns,model%temper%flwa,model%velocity%diffu,model%velocity%ubas, &
            model%velocity%vbas,model%velocity%uvel,model%velocity%vvel,model%velocity%uflx,model%velocity%vflx,&
            model%velocity%surfvel)
    end if

    !------------------------------------------------------------
    ! calculate upper and lower surface
    !------------------------------------------------------------
    call glide_calclsrf(model%geometry%thck, model%geometry%topg, model%climate%eus, model%geometry%lsrf)
    model%geometry%usrf = max(0.d0,model%geometry%thck + model%geometry%lsrf)

  end subroutine stagleapthck

!---------------------------------------------------------------------------------

  subroutine adi_tri(a,b,c,d,thk,tpg,mb,flx_p,flx_m,dif_p,dif_m,dt,ds1, ds2)
    !*FD construct tri-diagonal matrix system for a column/row
    use glimmer_global, only : dp, sp
    implicit none
    
    real(dp), dimension(:), intent(out) :: a !*FD alpha (subdiagonal)
    real(dp), dimension(:), intent(out) :: b !*FD alpha (diagonal)
    real(dp), dimension(:), intent(out) :: c !*FD alpha (superdiagonal)
    real(dp), dimension(:), intent(out) :: d !*FD right-hand side
    
    real(dp), dimension(:), intent(in) :: thk   !*FD ice thickness
    real(dp), dimension(:), intent(in) :: tpg   !*FD lower surface of ice
    real(sp), dimension(:), intent(in) :: mb    !*FD mass balance
    real(dp), dimension(:), intent(in) :: flx_p !*FD flux +1/2
    real(dp), dimension(:), intent(in) :: flx_m !*FD flux -1/2
    real(dp), dimension(:), intent(in) :: dif_p !*FD diffusivity +1/2
    real(dp), dimension(:), intent(in) :: dif_m !*FD diffusivity -1/2
    
    real(dp), intent(in) :: dt !*FD time step
    real(dp), intent(in) :: ds1, ds2 !*FD spatial steps inline and transversal

    ! local variables
    real(dp) :: f1, f2, f3
    integer :: i,n
    
    n = size(thk)

    f1 = dt/(4*ds1*ds1)
    f2 = dt/(4*ds2)
    f3 = dt/2.

    a(:) = 0.
    b(:) = 0.
    c(:) = 0.
    d(:) = 0.

    a(1) = 0.
    do i=2,n
       a(i) = f1*(dif_m(i-1)+dif_p(i-1))
    end do
    do i=1,n-1
       c(i) = f1*(dif_m(i)+dif_p(i))
    end do
    c(n) = 0.
    b(:) = -(a(:)+c(:))

    ! calculate RHS
    do i=2,n-1
       d(i) = thk(i) - &
            f2 * (flx_p(i-1) + flx_p(i) - flx_m(i-1) - flx_m(i)) + &
            f3 * mb(i) - &
            a(i)*tpg(i-1) - b(i)*tpg(i) - c(i)*tpg(i+1)
    end do

    b(:) = 1.+b(:)

  end subroutine adi_tri

end module glide_thck

