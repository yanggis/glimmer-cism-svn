! +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
! +                                                           +
! +  glimmer_velo.f90 - part of the GLIMMER ice model         + 
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

!> Contains routines which handle various aspects of velocity in the model,
!! not only the bulk ice velocity, but also basal sliding, and vertical grid 
!! velocities, etc.

module glide_velo
  
  use glimmer_global, only : dp,sp
  use physcon, only : rhoi, grav, gn
  use glimmer_paramets, only : thk0, len0, vis0, vel0, acc0
  use velo_types, only : velo_type

  private patebudd

  ! some private parameters
  integer, private, parameter :: p1 = gn+1
  integer, private, parameter :: p2 = gn-1
  integer, private, parameter :: p3 = 2*gn+1
  integer, private, parameter :: p4 = gn+2
  real(dp),private, parameter :: c = -2.0d0*vis0*(rhoi*grav)**gn*thk0**p3/(8.0d0*vel0*len0**gn)

contains

  !> initialise velocity module
  subroutine init_velo(velo,bpar)
    use physcon, only : scyr
    use glide_glenflow, only: glenflow_init
    implicit none
    type(velo_type) :: velo                      !< the derived type holding the velocity grid
    real(dp), dimension(5), intent(in) :: bpar   !< basal traction parameters
    

    integer up

    velo%depth = (/ (((velo%sigma_grid%sigma(up+1)+velo%sigma_grid%sigma(up))/2.0d0)**gn &
         *(velo%sigma_grid%sigma(up+1)-velo%sigma_grid%sigma(up)),up=1,velo%sigma_grid%upn-1),0.0d0 /)
    
    velo%dups = (/ (velo%sigma_grid%sigma(up+1) - velo%sigma_grid%sigma(up), up=1,velo%sigma_grid%upn-1),0.0d0 /)

    !++++++ N.B. The definition of DUPS here is NOT THE SAME as that used in the 
    !++++++ temperature vertical coordinate!!! You have been warned...

    ! Calculate the differences between adjacent sigma levels -------------------------

    velo%dupsw  = (/ (velo%sigma_grid%sigma(up+1)-velo%sigma_grid%sigma(up), up=1,velo%sigma_grid%upn-1), 0.0d0 /) 

    ! Calculate the value of sigma for the levels between the standard ones -----------

    velo%depthw = (/ ((velo%sigma_grid%sigma(up+1)+velo%sigma_grid%sigma(up)) / 2.0d0, up=1,velo%sigma_grid%upn-1), 0.0d0 /)

    velo%watwd  = bpar(1) / bpar(2)
    velo%watct  = bpar(2) 
    velo%trcmin = bpar(3) / scyr
    velo%trcmax = bpar(4) / scyr
    velo%marine = bpar(5)
    velo%trcmax = velo%trcmax / velo%trc0
    velo%trcmin = velo%trcmin / velo%trc0
    velo%c(1)   = (velo%trcmax - velo%trcmin) / 2.0d0 + velo%trcmin
    velo%c(2)   = (velo%trcmax - velo%trcmin) / 2.0d0
    velo%c(3)   = velo%watwd * thk0 / 4.0d0
    velo%c(4)   = velo%watct * 4.0d0 / thk0 

  end subroutine init_velo

  !*****************************************************************************
  ! new velo functions come here
  !*****************************************************************************

  !-------------------------------------------------------------------------

  !> Calculates the ice temperature - full solution
  subroutine calcVerticalVelocity(velo,timederivs,periodic_ew,whichwvel,thklim,thck,usrf, &
       stagthck,dthckdew,dthckdns,dusrfdew,dusrfdns,bmlt,acab,time, &
       uvel,vvel,wvel,wgrd)


    use glimmer_deriv_time, only: timeders_type, timeders
    implicit none

    !------------------------------------------------------------------------------------
    ! Subroutine arguments
    !------------------------------------------------------------------------------------

    type(velo_type) :: velo                            !< the derived type holding the velocity grid
    type(timeders_type) :: timederivs                  !< derived type holding time derivative data
    integer, intent(in) :: periodic_ew                 !< select EW periodic boundary conditions (0 - not periodic; 1 - periodic)
    integer, intent(in) :: whichwvel                   !< set to 1 if the Vertical integration constrained so that upper kinematic B.C. obeyed
    real(dp),                 intent(in)  :: thklim    !< Minimum thickness to be considered when calculating the grid velocity. This is in m, divided by \texttt{thk0}.
    real(dp),dimension(:,:),  intent(in)  :: thck      !< Ice-sheet thickness (divided by <tt>thk0</tt>)
    real(dp),dimension(:,:),  intent(in)  :: usrf      !< The elevation of the upper ice surface (divided by <tt>thk0</tt>)
    real(dp),dimension(:,:),  intent(in)  :: stagthck  !< ice thickness averaged onto the staggered grid.
    real(dp),dimension(:,:),  intent(in)  :: dthckdew  !< E-W derivative of ice thickness.
    real(dp),dimension(:,:),  intent(in)  :: dthckdns  !< N-S derivative of ice thickness.
    real(dp),dimension(:,:),  intent(in)  :: dusrfdew  !< E-W derivative of upper surface elevation.
    real(dp),dimension(:,:),  intent(in)  :: dusrfdns  !< N-S derivative of upper surface elevation.
    real(dp),dimension(:,:),  intent(in)  :: bmlt      !< Basal melt-rate (scaled?) This is required in the basal boundary condition. See <em>Payne and Dongelmans</em> equation 14.
    real(sp),dimension(:,:),  intent(in)  :: acab      !< surface Mass-balance (scaled)
    real(sp), intent(in)                  :: time      !< current time
    real(dp),dimension(:,:,:),  intent(inout) :: uvel  !< $x$ velocity field at top model level (scaled, on staggered grid).
    real(dp),dimension(:,:,:),  intent(inout) :: vvel  !< $y$ velocity field at top model level (scaled, on staggered grid).
    real(dp),dimension(:,:,:),intent(inout) :: wvel    !< Vertical velocity field, 
    real(dp),dimension(:,:,:),intent(inout) :: wgrd    !< The grid velocity at each point. This is the output.

    ! Calculate time-derivatives of thickness and upper surface elevation ------------

    call timeders(timederivs, thck, velo%dthckdtm, time, 1)

    call timeders(timederivs, usrf, velo%dusrfdtm, time, 2)

    ! Calculate the vertical velocity of the grid ------------------------------------

    call gridwvel(velo, thklim, uvel, vvel,   &
         dusrfdew, dusrfdns, dthckdew, dthckdns, &
         thck, wgrd)

    ! Calculate the actual vertical velocity ------------


    call wvelintg(velo, thklim, stagthck, &
         dusrfdew, dusrfdns, dthckdew, dthckdns, &
         uvel, vvel, wgrd(velo%sigma_grid%upn,:,:), &
         thck, bmlt, wvel)

    ! Vertical integration constrained so kinematic upper BC obeyed.

    if (whichwvel==1) then
       call chckwvel(velo,thklim, dusrfdew, dusrfdns, uvel(1,:,:), vvel(1,:,:), wvel, thck, acab)
    end if

    ! apply periodic ew BC
    if (periodic_ew.eq.1) then
       call wvel_ew(wgrd,wvel)
    end if

  end subroutine calcVerticalVelocity

  !*****************************************************************************
  ! old velo functions come here
  !*****************************************************************************

  !> Calculates the vertical velocity of the grid.
  !!
  !! This is necessary because the model uses a sigma coordinate system.
  !! The equation for grid velocity is:
  !! \f[
  !! \mathtt{wgrd}(x,y,\sigma)=\frac{\partial s}{\partial t}+\mathbf{U}\cdot\nabla s
  !! -\sigma\left(\frac{\partial H}{\partial t}+\mathbf{U}\cdot\nabla H\right)
  !! \f]
  !! Compare this with equation A1 in <em>Payne and Dongelmans</em>.
  subroutine gridwvel(velo,thklim,uvel,vvel,dusrfdew,dusrfdns,dthckdew,dthckdns,thck,wgrd)

    use glimmer_utils, only: hsum4 

    implicit none 

    !------------------------------------------------------------------------------------
    ! Subroutine arguments
    !------------------------------------------------------------------------------------

    type(velo_type) :: velo                            !< the derived type holding the velocity grid
    real(dp),                 intent(in)  :: thklim    !< Minimum thickness to be considered when calculating the grid velocity. This is in m, divided by \texttt{thk0}.
    real(dp),dimension(:,:,:),intent(in)  :: uvel      !< The $x$-velocity field (scaled). Velocity is on the staggered grid
    real(dp),dimension(:,:,:),intent(in)  :: vvel      !< The $y$-velocity field (scaled). Velocity is on the staggered grid
    real(dp),dimension(:,:),  intent(in)  :: dusrfdew  !< E-W derivative of upper surface elevation.
    real(dp),dimension(:,:),  intent(in)  :: dusrfdns  !< N-S derivative of upper surface elevation.
    real(dp),dimension(:,:),  intent(in)  :: dthckdew  !< E-W derivative of ice thickness.
    real(dp),dimension(:,:),  intent(in)  :: dthckdns  !< N-S derivative of ice thickness.
    real(dp),dimension(:,:),  intent(in)  :: thck      !< Ice-sheet thickness (divided by <tt>thk0</tt>)
    real(dp),dimension(:,:,:),intent(out) :: wgrd      !< The grid velocity at each point. This is the output.

    !------------------------------------------------------------------------------------
    ! Internal variables
    !------------------------------------------------------------------------------------

    integer :: ns,ew,nsn,ewn

    !------------------------------------------------------------------------------------

    ewn=size(wgrd,2) ; nsn=size(wgrd,3)

    do ns = 2,nsn-1
      do ew = 2,ewn-1
        if (thck(ew,ns) > thklim) then
          wgrd(:,ew,ns) = velo%dusrfdtm(ew,ns) - velo%sigma_grid%sigma * velo%dthckdtm(ew,ns) + & 
                      (hsum4(uvel(:,ew-1:ew,ns-1:ns)) * &
                      (sum(dusrfdew(ew-1:ew,ns-1:ns)) - velo%sigma_grid%sigma * &
                       sum(dthckdew(ew-1:ew,ns-1:ns))) + &
                       hsum4(vvel(:,ew-1:ew,ns-1:ns)) * &
                      (sum(dusrfdns(ew-1:ew,ns-1:ns)) - velo%sigma_grid%sigma * &
                       sum(dthckdns(ew-1:ew,ns-1:ns)))) / 16.0d0
        else
          wgrd(:,ew,ns) = 0.0d0
        end if
      end do
    end do

  end subroutine gridwvel

!------------------------------------------------------------------------------------------

  !> Calculates the vertical velocity field, which is returned in <tt>wvel</tt>.
  !!
  !! This is found by doing this integration:
  !! \f[
  !! w(\sigma)=\int_{1}^{\sigma}\left[\frac{\partial \mathbf{U}}{\partial \sigma}
  !! (\sigma) \cdot (\nabla s - \sigma \nabla H) +H\nabla \cdot \mathbf{U}(\sigma)\right]d\sigma
  !! + w(1)
  !! \f]
  !! (This is equation 13 in <em>Payne and Dongelmans</em>.) Note that this is only 
  !! done if the thickness is greater than the threshold given by <tt>thklim</tt>.

  subroutine wvelintg(velo,thklim,stagthck,dusrfdew,dusrfdns,dthckdew,dthckdns,uvel,vvel,wgrd,thck,bmlt,wvel)

    use glimmer_utils, only : hsum4 

    implicit none

    !------------------------------------------------------------------------------------
    ! Subroutine arguments
    !------------------------------------------------------------------------------------

    type(velo_type) :: velo                            !< the derived type holding the velocity grid
    real(dp),                 intent(in)   :: thklim   !< Minimum thickness to be considered when calculating the grid velocity. This is in m, divided by \texttt{thk0}.
    real(dp),dimension(:,:),  intent(in)   :: stagthck !< ice thickness averaged onto the staggered grid.
    real(dp),dimension(:,:),  intent(in)   :: dusrfdew !< E-W derivative of upper surface elevation.
    real(dp),dimension(:,:),  intent(in)   :: dusrfdns !< N-S derivative of upper surface elevation.
    real(dp),dimension(:,:),  intent(in)   :: dthckdew !< E-W derivative of ice thickness.
    real(dp),dimension(:,:),  intent(in)   :: dthckdns !< N-S derivative of ice thickness.
    real(dp),dimension(:,:,:),intent(in)   :: uvel     !< The $x$-velocity field (scaled). Velocity is on the staggered grid
    real(dp),dimension(:,:,:),intent(in)   :: vvel     !< The $y$-velocity field (scaled). Velocity is on the staggered grid
    real(dp),dimension(:,:),  intent(in)   :: thck     !< Ice-sheet thickness (divided by <tt>thk0</tt>)
    real(dp),dimension(:,:),intent(in)     :: wgrd     !< The grid velocity at each point. This is the output.
    real(dp),dimension(:,:),   intent(in)  :: bmlt     !< Basal melt-rate (scaled?) This is required in the basal boundary condition. See <em>Payne and Dongelmans</em> equation 14.
    real(dp),dimension(:,:,:), intent(out) :: wvel     !< The vertical velocity field.

    !------------------------------------------------------------------------------------
    ! Internal variables
    !------------------------------------------------------------------------------------

    real(dp) :: dew16, dns16        ! The grid-spacings multiplied by 16
    real(dp),dimension(6) :: cons   ! Holds temporary local values of derivatives
    integer :: ns,ew,up             ! Loop indicies
    integer :: nsn,ewn,upn          ! Domain sizes

    !------------------------------------------------------------------------------------
    ! Get some values for the domain size by checking sizes of input arrays
    !------------------------------------------------------------------------------------

    upn=size(uvel,1) ; ewn=size(uvel,2) ; nsn=size(uvel,3)


    ! Multiply grid-spacings by 16 -----------------------------------------------------

    dew16 = 1d0/(16.0d0 * velo%velo_grid%delta(1))
    dns16 = 1d0/(16.0d0 * velo%velo_grid%delta(2))

    ! ----------------------------------------------------------------------------------
    ! Main loop over each grid-box
    ! ----------------------------------------------------------------------------------

    do ns = 2,nsn
      do ew = 2,ewn
        if (thck(ew,ns) > thklim) then
  
          ! Set the bottom boundary condition ------------------------------------------

          wvel(upn,ew,ns) = wgrd(ew,ns) - bmlt(ew,ns)

          ! Calculate temporary local values of thickness and surface ------------------
          ! elevation derivatives.

          cons(1) = sum(dusrfdew(ew-1:ew,ns-1:ns)) / 16.0d0
          cons(2) = sum(dthckdew(ew-1:ew,ns-1:ns)) / 16.0d0
          cons(3) = sum(dusrfdns(ew-1:ew,ns-1:ns)) / 16.0d0
          cons(4) = sum(dthckdns(ew-1:ew,ns-1:ns)) / 16.0d0
          cons(5) = sum(stagthck(ew-1:ew,ns-1:ns))
          cons(6) = cons(5)*dns16
          cons(5) = cons(5)*dew16
          ! * better? (an alternative from TP's original code)
          !cons(5) = (thck(ew-1,ns)+2.0d0*thck(ew,ns)+thck(ew+1,ns)) * dew16
          !cons(6) = (thck(ew,ns-1)+2.0d0*thck(ew,ns)+thck(ew,ns+1)) * dns16

          velo%suvel = hsum4(uvel(:,ew-1:ew,ns-1:ns))
          velo%svvel = hsum4(vvel(:,ew-1:ew,ns-1:ns))

          ! Loop over each model level, starting from the bottom ----------------------

          do up = upn-1, 1, -1
            wvel(up,ew,ns) = wvel(up+1,ew,ns) &
                       - velo%dupsw(up) * cons(5) * (sum(uvel(up:up+1,ew,ns-1:ns))  - sum(uvel(up:up+1,ew-1,ns-1:ns))) &
                       - velo%dupsw(up) * cons(6) * (sum(vvel(up:up+1,ew-1:ew,ns))  - sum(vvel(up:up+1,ew-1:ew,ns-1))) &
                       - (velo%suvel(up+1) - velo%suvel(up)) * (cons(1) - velo%depthw(up) * cons(2)) &
                       - (velo%svvel(up+1) - velo%svvel(up)) * (cons(3) - velo%depthw(up) * cons(4)) 
          end do
        else 

          ! If there isn't enough ice, set velocities to zero ----------------------------

          wvel(:,ew,ns) = 0.0d0  

        end if
      end do
    end do

  end subroutine wvelintg

  !> set periodic EW boundary conditions
  subroutine wvel_ew(wgrd,wvel)
    implicit none
    real(dp),dimension(:,:,:) :: wvel 
    real(dp),dimension(:,:,:) :: wgrd

    integer :: ewn

    ewn = size(wgrd,2)

    wgrd(:,1,:)   = wgrd(:,ewn-1,:)
    wgrd(:,ewn,:) = wgrd(:,2,:)
    wvel(:,1,:)   = wvel(:,ewn-1,:)
    wvel(:,ewn,:) = wvel(:,2,:)
  end subroutine wvel_ew

!------------------------------------------------------------------------------------------

  !> Constrain the vertical velocity field to obey a kinematic upper boundary 
  !! condition.
  subroutine chckwvel(velo,thklim,dusrfdew,dusrfdns,uvel,vvel,wvel,thck,acab)

    use glimmer_global, only : sp 

    implicit none

    !------------------------------------------------------------------------------------
    ! Subroutine arguments
    !------------------------------------------------------------------------------------

    type(velo_type) :: velo                         !< the derived type holding the velocity grid
    real(dp), intent(in) :: thklim                  !< the ice thickness below which no computations are done
    real(dp),dimension(:,:), intent(in) :: dusrfdew !< E-W derivative of upper surface elevation.
    real(dp),dimension(:,:), intent(in) :: dusrfdns !< N-S derivative of upper surface elevation.
    real(dp),dimension(:,:),  intent(in)    :: uvel !< $x$ velocity field at top model level (scaled, on staggered grid).
    real(dp),dimension(:,:),  intent(in)    :: vvel !< $y$ velocity field at top model level (scaled, on staggered grid).
    real(dp),dimension(:,:,:),intent(inout) :: wvel !< Vertical velocity field, 
    real(dp),dimension(:,:),  intent(in)    :: thck !< Ice thickness (scaled)
    real(sp),dimension(:,:),  intent(in)    :: acab !< Mass-balance (scaled)

    !------------------------------------------------------------------------------------
    ! Internal variables
    !------------------------------------------------------------------------------------

    real(dp) :: wchk
    real(dp) :: tempcoef
    integer  :: ns,ew,nsn,ewn

    ! Get array sizes -------------------------------------------------------------------

    ewn=size(thck,1) ; nsn=size(thck,2)

    ! Allocate temporary work array -----------------------------------------------------


    ! Loop over all grid-boxes ----------------------------------------------------------

    do ns = 2,nsn-1
      do ew = 2,ewn-1
         if (thck(ew,ns) > thklim .and. wvel(1,ew,ns).ne.0) then

            wchk = velo%dusrfdtm(ew,ns) &
                 - acab(ew,ns) &
                 + (sum(uvel(ew-1:ew,ns-1:ns)) * sum(dusrfdew(ew-1:ew,ns-1:ns)) &
                 +  sum(vvel(ew-1:ew,ns-1:ns)) * sum(dusrfdns(ew-1:ew,ns-1:ns))) &
                 / 16.0d0

            
            tempcoef = wchk - wvel(1,ew,ns)

            wvel(:,ew,ns) = wvel(:,ew,ns) + tempcoef * (1.0d0 - velo%sigma_grid%sigma) 
         end if
      end do
    end do

  end subroutine chckwvel

!------------------------------------------------------------------------------------------
! PRIVATE subroutines
!------------------------------------------------------------------------------------------

!------------------------------------------------------------------------------------------

  !> Calculate the value of $B$ used for basal sliding calculations.
  subroutine calc_btrc(velo,flag,bed_softness,stagbwat,stagbtemp,stagbpmp,bmlt,relx,btrc)
    use glimmer_global, only : dp 
    implicit none

    type(velo_type) :: velo                               !< the derived type holding the velocity grid
    integer,                intent(in)    :: flag         !< Flag to select method of
    real(dp),dimension(:,:),intent(in)    :: bed_softness !< bed softness parameter
    real(dp),dimension(:,:),intent(in)    :: stagbwat     !< Basal water depth in velo grid
    real(dp),dimension(:,:),intent(in)    :: stagbtemp    !< Basal temperature on velo grid
    real(dp),dimension(:,:),intent(in)    :: stagbpmp     !< Basal pressure melting point on velo grid
    real(dp),dimension(:,:),intent(in)    :: bmlt         !< Basal melt-rate
    real(dp),dimension(:,:),intent(in)    :: relx         !< The elevation of the relaxed topography, by <tt>thck0</tt>.
    real(dp),dimension(:,:),intent(out)   :: btrc         !< Array of values of $B$.

    !------------------------------------------------------------------------------------
    ! Internal variables
    !------------------------------------------------------------------------------------

    real(dp) :: sbwat 
    integer :: ew,ns,nsn,ewn

    !------------------------------------------------------------------------------------

    ewn=velo%ice_grid%size(1)
    nsn=velo%ice_grid%size(2)

    !------------------------------------------------------------------------------------

    select case(flag)
    case(1)
       ! constant everywhere
       btrc = bed_softness
    case(2)
       ! constant where basal melt water is present
       do ns = 1,nsn-1
          do ew = 1,ewn-1
             if (0.0d0 < stagbwat(ew,ns)) then
                btrc(ew,ns) = bed_softness(ew,ns)
             else
                btrc(ew,ns) = 0.0d0
             end if
          end do
       end do
    case(3)
       ! function of basal water depth
       do ns = 1,nsn-1
          do ew = 1,ewn-1
             if (0.0d0 < stagbwat(ew,ns)) then
                btrc(ew,ns) = velo%c(2) * tanh(velo%c(3) * &
                     (sbwat - velo%c(4))) + velo%c(1)
                if (0.0d0 > sum(relx(ew:ew+1,ns:ns+1))) then
                   btrc(ew,ns) = btrc(ew,ns) * velo%marine  
                end if
             else
                btrc(ew,ns) = 0.0d0
             end if
          end do
       end do
    case(4)
       ! linear function of basal melt rate
       do ns = 1,nsn-1
          do ew = 1,ewn-1
             sbwat = 0.25*sum(bmlt(ew:ew+1,ns:ns+1))
             
             if (sbwat>0.d0) then
                btrc(ew,ns) = min(velo%btrac_max, bed_softness(ew,ns)+velo%btrac_slope*sbwat)
             else
                btrc(ew,ns) = 0.0d0
             end if
          end do
       end do
    case(5)
       ! constant where basal temperature equal to pressure melting point
       ! This is the actual EISMINT condition, which may not be the same
       ! as case(2) above, depending on the hydrology
       do ns = 1,nsn-1
          do ew = 1,ewn-1
             if (abs(stagbpmp(ew,ns) - stagbtemp(ew,ns))<0.001) then
                btrc(ew,ns) = bed_softness(ew,ns)
             else
                btrc(ew,ns) = 0.0d0
             end if
          end do
       end do
    case default
       ! zero everywhere
       btrc = 0.0d0
    end select

  end subroutine calc_btrc

  !> calculate basal shear stress: \f[tau_{(x,y)} = -ro_igH\frac{d(H+h)}{d{(x,y)}}\f]
  subroutine calc_basal_shear(stagthck,dusrfdew,dusrfdns,tau_x,tau_y)
    use physcon, only : rhoi,grav
    implicit none
    real(dp),dimension(:,:), intent(in) :: stagthck !< ice thickness averaged onto the staggered grid.
    real(dp),dimension(:,:), intent(in) :: dusrfdew !< E-W derivative of upper surface elevation.
    real(dp),dimension(:,:), intent(in) :: dusrfdns !< N-S derivative of upper surface elevation.
    real(dp),dimension(:,:), intent(out) :: tau_x   !< x component of basal shear stress
    real(dp),dimension(:,:), intent(out) :: tau_y   !< y component of basal shear stress

    tau_x = -rhoi*grav*stagthck
    tau_y = tau_x * dusrfdns
    tau_x = tau_x * dusrfdew
  end subroutine calc_basal_shear

end module glide_velo
