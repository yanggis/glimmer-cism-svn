
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
! GLIMMER is hosted on NeSCForge:
!
! http://forge.nesc.ac.uk/projects/glimmer/
!
! +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

module glimmer_velo

  !*FD Contains routines which handle various aspects of velocity in the model,
  !*FD not only the bulk ice velocity, but also basal sliding, and vertical grid velocities,
  !*FD etc.

  use glimmer_types

  private vertintg, patebudd, calcbtrc

contains

  subroutine slipvelo(numerics,velowk,params,geomderv,flag,bwat,btrc,relx,ubas,vbas)

    !*FD Calculate the basal slip velocity and the value of $B$, the free parameter
    !*FD in the basal velocity equation (though I'm not sure that $B$ is used anywhere 
    !*FD else).

    use glimmer_global, only : dp
    use physcon, only : rhoi, grav
    use glide_messages

    implicit none

    !------------------------------------------------------------------------------------
    ! Subroutine arguments
    !------------------------------------------------------------------------------------

    type(glimmer_numerics), intent(in)    :: numerics !*FD Ice model numerics parameters
    type(glimmer_velowk),   intent(inout) :: velowk   !*FD Velocity work arrays.
    type(glimmer_paramets), intent(in)    :: params   !*FD Ice model parameters.
    type(glimmer_geomderv), intent(in)    :: geomderv !*FD Horizontal and temporal derivatives of 
                                                      !*FD ice model thickness and upper surface
                                                      !*FD elevation.
    integer, dimension(2),  intent(in)    :: flag     !*FD \texttt{flag(1)} sets the calculation
                                                      !*FD method to use for the basal velocity
                                                      !*FD (corresponds to \texttt{whichslip} elsewhere
                                                      !*FD in the model. \texttt{flag(2)} controls the
                                                      !*FD calculation of the basal slip coefficient $B$,
                                                      !*FD which corresponds to \texttt{whichbtrc} elsewhere.
    real(dp),dimension(:,:),intent(in)    :: bwat     !*FD Basal melt rate.
    real(dp),dimension(:,:),intent(out)   :: btrc     !*FD The basal slip coefficient.
    real(dp),dimension(:,:),intent(in)    :: relx     !*FD The relaxed topography (scaled)
    real(dp),dimension(:,:),intent(out)   :: ubas     !*FD The $x$ basal velocity (scaled)
    real(dp),dimension(:,:),intent(out)   :: vbas     !*FD The $y$ basal velocity (scaled)

    !------------------------------------------------------------------------------------
    ! Internal variables
    !------------------------------------------------------------------------------------

    real(dp), parameter :: c = - rhoi * grav
    integer :: nsn,ewn

    ! Get array sizes -------------------------------------------------------------------

    ewn=size(btrc,1) ; nsn=size(btrc,2)    

    ! Allocate work array if this is the first call -------------------------------------

    if (velowk%first1) then
       allocate(velowk%fslip(ewn,nsn))
       velowk%first1 = .false.
    end if

    !------------------------------------------------------------------------------------
    ! Main calculation starts here
    !------------------------------------------------------------------------------------

    select case(flag(1))
    case(0)  

       ! Linear function of gravitational driving stress ---------------------------------

       call calcbtrc(velowk,params,flag(2),bwat,relx,btrc(1:ewn-1,1:nsn-1))

       where (numerics%thklim < geomderv%stagthck(1:ewn-1,1:nsn-1))
          ubas(1:ewn-1,1:nsn-1) = btrc(1:ewn-1,1:nsn-1) * c * &
               geomderv%stagthck(1:ewn-1,1:nsn-1) * &
               geomderv%dusrfdew(1:ewn-1,1:nsn-1)
          vbas(1:ewn-1,1:nsn-1) = btrc(1:ewn-1,1:nsn-1) * c * &
               geomderv%stagthck(1:ewn-1,1:nsn-1) * &
               geomderv%dusrfdns(1:ewn-1,1:nsn-1)
       elsewhere
          ubas(1:ewn-1,1:nsn-1) = 0.0d0
          vbas(1:ewn-1,1:nsn-1) = 0.0d0
       end where

    case(1)

       ! *tp* option to be used in picard iteration for thck
       ! *tp* start by find constants which dont vary in iteration

       call calcbtrc(velowk,params,flag(2),bwat,relx,btrc(1:ewn-1,1:nsn-1))

       velowk%fslip(1:ewn-1,1:nsn-1) = c * btrc(1:ewn-1,1:nsn-1)

    case(2)

       ! *tp* option to be used in picard iteration for thck
       ! *tp* called once per non-linear iteration, set uvel to ub * H /(ds/dx) which is
       ! *tp* a diffusivity for the slip term (note same in x and y)

       where (numerics%thklim < geomderv%stagthck(1:ewn-1,1:nsn-1))
          ubas(1:ewn-1,1:nsn-1) = velowk%fslip(1:ewn-1,1:nsn-1) * geomderv%stagthck(1:ewn-1,1:nsn-1)**2  
       elsewhere
          ubas(1:ewn-1,1:nsn-1) = 0.0d0
       end where

    case(3)

       ! *tp* option to be used in picard iteration for thck
       ! *tp* finally calc ub and vb from diffusivities

       where (numerics%thklim < geomderv%stagthck(1:ewn-1,1:nsn-1))
          vbas(1:ewn-1,1:nsn-1) = ubas(1:ewn-1,1:nsn-1) *  &
               geomderv%dusrfdns(1:ewn-1,1:nsn-1) / &
               geomderv%stagthck(1:ewn-1,1:nsn-1)
          ubas(1:ewn-1,1:nsn-1) = ubas(1:ewn-1,1:nsn-1) *  &
               geomderv%dusrfdew(1:ewn-1,1:nsn-1) / &
               geomderv%stagthck(1:ewn-1,1:nsn-1)
       elsewhere
          ubas(1:ewn-1,1:nsn-1) = 0.0d0
          vbas(1:ewn-1,1:nsn-1) = 0.0d0
       end where

    case(4)

       ! Set to zero everywhere

       ubas(1:ewn-1,1:nsn-1) = 0.0d0
       vbas(1:ewn-1,1:nsn-1) = 0.0d0

    case default

       call glide_msg(GM_FATAL,__FILE__,__LINE__,'Unrecognised value of whichslip')

    end select

  end subroutine slipvelo

!------------------------------------------------------------------------------------------

  subroutine zerovelo(velowk,sigma,flag,stagthck,dusrfdew,dusrfdns,flwa,ubas,vbas,uvel,vvel,uflx,vflx,diffu)

    !*FD Performs the velocity calculation. This subroutine is called with
    !*FD different values of \texttt{flag}, depending on exactly what we want to calculate.

    use glimmer_global, only : dp
    use glimmer_utils, only : hsum
    use physcon, only : rhoi, grav, gn
    use paramets, only : thk0, len0, vis0, vel0

    implicit none

    !------------------------------------------------------------------------------------
    ! Subroutine arguments
    !------------------------------------------------------------------------------------

    type(glimmer_velowk),     intent(inout) :: velowk
    real(dp),dimension(:),    intent(in)    :: sigma
    integer,                  intent(in)    :: flag
    real(dp),dimension(:,:),  intent(in)    :: stagthck
    real(dp),dimension(:,:),  intent(in)    :: dusrfdew
    real(dp),dimension(:,:),  intent(in)    :: dusrfdns
    real(dp),dimension(:,:,:),intent(in)    :: flwa
    real(dp),dimension(:,:),  intent(in)    :: ubas
    real(dp),dimension(:,:),  intent(in)    :: vbas
    real(dp),dimension(:,:,:),intent(out)   :: uvel
    real(dp),dimension(:,:,:),intent(out)   :: vvel
    real(dp),dimension(:,:),  intent(out)   :: uflx
    real(dp),dimension(:,:),  intent(out)   :: vflx
    real(dp),dimension(:,:),  intent(out)   :: diffu

    !------------------------------------------------------------------------------------
    ! Internal variables
    !------------------------------------------------------------------------------------

    integer, parameter :: p1 = gn+1
    integer, parameter :: p2 = gn-1
    integer, parameter :: p3 = 2*gn+1
    integer, parameter :: p4 = gn+2
    real(dp),parameter :: c = -2.0d0*vis0*(rhoi*grav)**gn*thk0**p3/(8.0d0*vel0*len0**gn)

    real(dp),dimension(size(sigma)) :: hrzflwa, intflwa 
    real(dp),dimension(3)           :: const

    integer :: ew,ns,up,ewn,nsn,upn

    !------------------------------------------------------------------------------------

    upn=size(sigma) ; ewn=size(ubas,1) ; nsn=size(ubas,2)

    !------------------------------------------------------------------------------------

    if (velowk%first2) then

      allocate(velowk%depth(upn))
      allocate(velowk%dintflwa(ewn,nsn))

      velowk%depth = (/ (((sigma(up+1)+sigma(up))/2.0d0)**gn*(sigma(up+1)-sigma(up)),up=1,upn-1),0.0d0 /)
      velowk%first2 = .false.
    end if

    !------------------------------------------------------------------------------------

    select case(flag)
    case(0)

      do ns = 1,nsn-1
        do ew = 1,ewn-1

          if (stagthck(ew,ns) /= 0.0d0) then

            ! Set velocity to zero at base of column

            uvel(upn,ew,ns) = 0.0d0
            vvel(upn,ew,ns) = 0.0d0

            ! Get column profile of Glenn's A

            hrzflwa = hsum(flwa(:,ew:ew+1,ns:ns+1))

            ! Calculate coefficient for integration

            const(1) = c * stagthck(ew,ns)**p1 * sqrt(dusrfdew(ew,ns)**2 + dusrfdns(ew,ns)**2)**p2  

            ! Do first step of finding u according to (8) in Payne and Dongelmans 

            do up = upn-1, 1, -1
              uvel(up,ew,ns) = uvel(up+1,ew,ns) + const(1) * &
                    velowk%depth(up) * sum(hrzflwa(up:up+1)) 
            end do

            ! Calculate u diffusivity (?)

            diffu(ew,ns) = vertintg(velowk,sigma,uvel(:,ew,ns)) * stagthck(ew,ns)

            ! Complete calculation of u and v

            vvel(:,ew,ns) = uvel(:,ew,ns) * dusrfdns(ew,ns) + vbas(ew,ns)
            uvel(:,ew,ns) = uvel(:,ew,ns) * dusrfdew(ew,ns) + ubas(ew,ns)

            ! Calculate ice fluxes

            uflx(ew,ns) = diffu(ew,ns) * dusrfdew(ew,ns) + ubas(ew,ns) * stagthck(ew,ns)
            vflx(ew,ns) = diffu(ew,ns) * dusrfdns(ew,ns) + vbas(ew,ns) * stagthck(ew,ns)

          else 

            ! Where there is no ice, set everything to zero.

            uvel(:,ew,ns) = 0.0d0
            vvel(:,ew,ns) = 0.0d0
            uflx(ew,ns)   = 0.0d0
            vflx(ew,ns)   = 0.0d0
            diffu(ew,ns)  = 0.0d0

          end if

        end do
      end do

    case(1)

      do ns = 1,nsn-1
        do ew = 1,ewn-1
          if (stagthck(ew,ns) /= 0.0d0) then

            hrzflwa = hsum(flwa(:,ew:ew+1,ns:ns+1))  
            intflwa(upn) = 0.0d0

            do up = upn-1, 1, -1
               intflwa(up) = intflwa(up+1) + velowk%depth(up) * sum(hrzflwa(up:up+1)) 
            end do

            velowk%dintflwa(ew,ns) = c * vertintg(velowk,sigma,intflwa)

          else 

            velowk%dintflwa(ew,ns) = 0.0d0

          end if
        end do
      end do

    case(2)

      where (0.0d0 /= stagthck(1:ewn-1,1:nsn-1))
        diffu(1:ewn-1,1:nsn-1) = velowk%dintflwa(1:ewn-1,1:nsn-1) * stagthck(1:ewn-1,1:nsn-1)**p4 * &
              sqrt(dusrfdew(1:ewn-1,1:nsn-1)**2 + dusrfdns(1:ewn-1,1:nsn-1)**2)**p2 
      elsewhere
        diffu(1:ewn-1,1:nsn-1) = 0.0d0
      end where

    case(3)

      do ns = 1,nsn-1
        do ew = 1,ewn-1
          if (stagthck(ew,ns) /= 0.0d0) then

            vflx(ew,ns) = diffu(ew,ns) * dusrfdns(ew,ns) + vbas(ew,ns) * stagthck(ew,ns)
            uflx(ew,ns) = diffu(ew,ns) * dusrfdew(ew,ns) + ubas(ew,ns) * stagthck(ew,ns)

            uvel(upn,ew,ns) = ubas(ew,ns)
            vvel(upn,ew,ns) = vbas(ew,ns)

            hrzflwa = hsum(flwa(:,ew:ew+1,ns:ns+1))  

            if (velowk%dintflwa(ew,ns) /= 0.0d0) then
               const(2) = c * diffu(ew,ns) / velowk%dintflwa(ew,ns)
               const(3) = const(2) * dusrfdns(ew,ns)  
               const(2) = const(2) * dusrfdew(ew,ns) 
            else
               const(2:3) = 0.0d0
            end if

            do up = upn-1, 1, -1
              const(1) = velowk%depth(up) * sum(hrzflwa(up:up+1)) 
              uvel(up,ew,ns) = uvel(up+1,ew,ns) + const(1) * const(2)
              vvel(up,ew,ns) = vvel(up+1,ew,ns) + const(1) * const(3) 
            end do

          else 

            uvel(:,ew,ns) = 0.0d0
            vvel(:,ew,ns) = 0.0d0
            uflx(ew,ns) = 0.0d0
            vflx(ew,ns) = 0.0d0 

          end if
        end do
      end do

    end select

  end subroutine zerovelo

!------------------------------------------------------------------------------------------

  subroutine gridwvel(sigma,thklim,uvel,vvel,geomderv,thck,wgrd)

    !*FD Calculates the vertical velocity of the grid, and returns it in \texttt{wgrd}. This
    !*FD is necessary because the model uses a sigma coordinate system.
    !*FD The equation for grid velocity is:
    !*FD \[
    !*FD \mathtt{wgrd}(x,y,\sigma)=\frac{\partial s}{\partial t}+\mathbf{U}\cdot\nabla s
    !*FD -\sigma\left(\frac{\partial H}{\partial t}+\mathbf{U}\cdot\nabla H\right)
    !*FD \]
    !*FD Compare this with equation A1 in {\em Payne and Dongelmans}.

    use glimmer_global, only : dp
    use glimmer_utils, only: hsum 

    implicit none 

    !------------------------------------------------------------------------------------
    ! Subroutine arguments
    !------------------------------------------------------------------------------------

    real(dp),dimension(:),    intent(in)  :: sigma     !*FD Array holding values of sigma
                                                       !*FD at each vertical level
    real(dp),                 intent(in)  :: thklim    !*FD Minimum thickness to be considered
                                                       !*FD when calculating the grid velocity.
                                                       !*FD This is in m, divided by \texttt{thk0}.
    real(dp),dimension(:,:,:),intent(in)  :: uvel      !*FD The $x$-velocity field (scaled). Velocity
                                                       !*FD is on the staggered grid
    real(dp),dimension(:,:,:),intent(in)  :: vvel      !*FD The $y$-velocity field (scaled). Velocity
                                                       !*FD is on the staggered grid
    type(glimmer_geomderv),   intent(in)  :: geomderv  !*FD Derived type holding temporal
                                                       !*FD and horizontal derivatives of
                                                       !*FD ice-sheet thickness and upper
                                                       !*FD surface elevation
    real(dp),dimension(:,:),  intent(in)  :: thck      !*FD Ice-sheet thickness (divided by 
                                                       !*FD \texttt{thk0})
    real(dp),dimension(:,:,:),intent(out) :: wgrd      !*FD The grid velocity at each point. This
                                                       !*FD is the output.

    !------------------------------------------------------------------------------------
    ! Internal variables
    !------------------------------------------------------------------------------------

    integer :: ns,ew,nsn,ewn

    !------------------------------------------------------------------------------------

    ewn=size(wgrd,2) ; nsn=size(wgrd,3)

    do ns = 2,nsn
      do ew = 2,ewn
        if (thck(ew,ns) > thklim) then
          wgrd(:,ew,ns) = geomderv%dusrfdtm(ew,ns) - sigma * geomderv%dthckdtm(ew,ns) + & 
                      (hsum(uvel(:,ew-1:ew,ns-1:ns)) * &
                      (sum(geomderv%dusrfdew(ew-1:ew,ns-1:ns)) - sigma * &
                       sum(geomderv%dthckdew(ew-1:ew,ns-1:ns))) + &
                       hsum(vvel(:,ew-1:ew,ns-1:ns)) * &
                      (sum(geomderv%dusrfdns(ew-1:ew,ns-1:ns)) - sigma * &
                       sum(geomderv%dthckdns(ew-1:ew,ns-1:ns)))) / 16.0d0
        else
          wgrd(:,ew,ns) = 0.0d0
        end if
      end do
    end do

  end subroutine gridwvel

!------------------------------------------------------------------------------------------

  subroutine wvelintg(uvel,vvel,geomderv,numerics,velowk,wgrd,thck,bmlt,wvel)

    !*FD Calculates the vertical velocity field, which is returned in \texttt{wvel}.
    !*FD This is found by doing this integration:
    !*FD \[
    !*FD w(\sigma)=-\int_{1}^{\sigma}\left[\frac{\partial \mathbf{U}}{\partial \sigma}
    !*FD (\sigma) \cdot (\nabla s - \sigma \nabla H) +H\nabla \cdot \mathbf{U}(\sigma)\right]d\sigma
    !*FD + w(1)
    !*FD \]
    !*FD (This is equation 13 in {\em Payne and Dongelmans}.) Note that this is only 
    !*FD done if the thickness is greater than the threshold given by \texttt{numerics\%thklim}.

    use glimmer_global, only : dp
    use glimmer_utils, only : hsum 

    implicit none

    !------------------------------------------------------------------------------------
    ! Subroutine arguments
    !------------------------------------------------------------------------------------

    real(dp),dimension(:,:,:), intent(in)    :: uvel      !*FD The $x$-velocity on the
                                                          !*FD staggered grid (scaled)
    real(dp),dimension(:,:,:), intent(in)    :: vvel      !*FD The $y$-velocity on the
                                                          !*FD staggered grid (scaled)
    real(dp),dimension(:,:),   intent(in)    :: thck      !*FD The ice thickness, divided
                                                          !*FD by \texttt{thk0}
    type(glimmer_geomderv),    intent(in)    :: geomderv  !*FD Derived type holding the
                                                          !*FD horizontal and temporal derivatives
                                                          !*FD of the thickness and upper surface
                                                          !*FD elevation.
    type(glimmer_numerics),    intent(in)    :: numerics  !*FD Derived type holding numerical
                                                          !*FD parameters, including sigma values.
    type(glimmer_velowk),      intent(inout) :: velowk    !*FD Derived type holding working arrays
                                                          !*FD used by the subroutine
    real(dp),dimension(:,:),   intent(in)    :: wgrd      !*FD The grid vertical velocity at
                                                          !*FD the lowest model level.
    real(dp),dimension(:,:),   intent(in)    :: bmlt      !*FD Basal melt-rate (scaled?) This
                                                          !*FD is required in the basal boundary
                                                          !*FD condition. See {\em Payne and Dongelmans}
                                                          !*FD equation 14.
    real(dp),dimension(:,:,:), intent(out)   :: wvel      !*FD The vertical velocity field.

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

    !------------------------------------------------------------------------------------
    ! Do initial set-up, if not already done before
    !------------------------------------------------------------------------------------

    if (velowk%first4) then

      ! Allocate some arrays in velowk --------------------------------------------------

      allocate(velowk%dupsw (upn))
      allocate(velowk%depthw(upn))
      allocate(velowk%suvel (upn))
      allocate(velowk%svvel (upn))

      ! Calculate the differences between adjacent sigma levels -------------------------

      velowk%dupsw  = (/ (numerics%sigma(up+1)-numerics%sigma(up), up=1,upn-1), 0.0d0 /) 

      ! Calculate the value of sigma for the levels between the standard ones -----------

      velowk%depthw = (/ ((numerics%sigma(up+1)+numerics%sigma(up)) / 2.0d0, up=1,upn-1), 0.0d0 /)

      ! Set flag to show the initialisation has been completed --------------------------

      velowk%first4 = .false.

    end if

    ! Multiply grid-spacings by 16 -----------------------------------------------------

    dew16 = 16.0d0 * numerics%dew
    dns16 = 16.0d0 * numerics%dns

    ! ----------------------------------------------------------------------------------
    ! Main loop over each grid-box
    ! ----------------------------------------------------------------------------------

    do ns = 2,nsn
      do ew = 2,ewn
        if (thck(ew,ns) > numerics%thklim) then
  
          ! Set the bottom boundary condition ------------------------------------------

          wvel(upn,ew,ns) = wgrd(ew,ns) - bmlt(ew,ns)

          ! Calculate temporary local values of thickness and surface ------------------
          ! elevation derivatives.

          cons(1) = sum(geomderv%dusrfdew(ew-1:ew,ns-1:ns)) / 16.0d0
          cons(2) = sum(geomderv%dthckdew(ew-1:ew,ns-1:ns)) / 16.0d0
          cons(3) = sum(geomderv%dusrfdns(ew-1:ew,ns-1:ns)) / 16.0d0
          cons(4) = sum(geomderv%dthckdns(ew-1:ew,ns-1:ns)) / 16.0d0
          cons(5) = sum(geomderv%stagthck(ew-1:ew,ns-1:ns)) / dew16
          cons(6) = sum(geomderv%stagthck(ew-1:ew,ns-1:ns)) / dns16
          ! * better? (an alternative from TP's original code)
          ! cons(5) = (thck(ew-1,ns)+2.0d0*thck(ew,ns)+thck(ew+1,ns)) / dew16
          ! cons(6) = (thck(ew,ns-1)+2.0d0*thck(ew,ns)+thck(ew,ns+1)) / dns16

          velowk%suvel = hsum(uvel(:,ew-1:ew,ns-1:ns))
          velowk%svvel = hsum(vvel(:,ew-1:ew,ns-1:ns))

          ! Loop over each model level, starting from the bottom ----------------------

          do up = upn-1, 1, -1
            wvel(up,ew,ns) = wvel(up+1,ew,ns) &
                       - velowk%dupsw(up) * cons(5) * (sum(uvel(up:up+1,ew,ns-1:ns)) &
                       - sum(uvel(up:up+1,ew-1,ns-1:ns))) &
                       - velowk%dupsw(up) * cons(6) * (sum(vvel(up:up+1,ew-1:ew,ns)) &
                       - sum(vvel(up:up+1,ew-1:ew,ns-1))) &
                       - (velowk%suvel(up+1) &
                        - velowk%suvel(up)) * (cons(1) &
                        - velowk%depthw(up) * cons(2)) &
                       - (velowk%svvel(up+1) &
                        - velowk%svvel(up)) * (cons(3) &
                        - velowk%depthw(up) * cons(4)) 
          end do
        else 

          ! If there isn't enough ice, set velocities to zero ----------------------------

          wvel(:,ew,ns) = 0.0d0  

        end if
      end do
    end do

  end subroutine wvelintg

!------------------------------------------------------------------------------------------

  subroutine calcflwa(numerics,velowk,fiddle,flwa,temp,thck,flag)

    !*FD Calculates Glenn's $A$ over the three-dimensional domain,
    !*FD using one of three possible methods.
    !*FD \textbf{I'm unsure how this ties in with the documentation, since}
    !*FD \texttt{fiddle}\ \textbf{is set to 3.0. This needs checking} 

    use glimmer_global, only : dp
    use physcon, only : grav, rhoi, pmlt
    use paramets, only : thk0

    implicit none

    !------------------------------------------------------------------------------------
    ! Subroutine arguments
    !------------------------------------------------------------------------------------

    type(glimmer_numerics),     intent(in)    :: numerics  !*FD Derived type containing
                                                           !*FD model numerics parameters
    type(glimmer_velowk),       intent(inout) :: velowk    !*FD Derived type containing
                                                           !*FD work arrays for this module
    real(dp),                   intent(in)    :: fiddle    !*FD Tuning parameter for the
                                                           !*FD Paterson-Budd relationship
    real(dp),dimension(:,:,:),  intent(out)   :: flwa      !*FD The calculated values of $A$
    real(dp),dimension(:,0:,0:),intent(in)    :: temp      !*FD The 3D temperature field
    real(dp),dimension(:,:),    intent(in)    :: thck      !*FD The ice thickness
    integer,                    intent(in)    :: flag      !*FD Flag to select the method
                                                           !*FD of calculation:
    !*FD \begin{description}
    !*FD \item[0] {\em Paterson and Budd} relationship.
    !*FD \item[1] {\em Paterson and Budd} relationship, with temperature set to
    !*FD -5$^{\circ}$C.
    !*FD \item[2] Set constant, {\em but not sure how this works at the moment\ldots}
    !*FD \end{description}

    !------------------------------------------------------------------------------------
    ! Internal variables
    !------------------------------------------------------------------------------------

    real(dp), parameter :: fact = grav * rhoi * pmlt * thk0
    real(dp), parameter :: contemp = -5.0d0  
    real(dp), dimension(size(numerics%sigma)) :: tempcor

    integer :: ew,ns,up,ewn,nsn,upn

    !------------------------------------------------------------------------------------
    
    upn=size(flwa,1) ; ewn=size(flwa,2) ; nsn=size(flwa,3)

    !------------------------------------------------------------------------------------

    select case(flag)
    case(0)

      ! This is the Paterson and Budd relationship

      do ns = 1,nsn
        do ew = 1,ewn
          if (thck(ew,ns) > numerics%thklim) then
            
            ! Calculate the corrected temperature

            tempcor = min(0.0d0, temp(:,ew,ns) + thck(ew,ns) * fact * numerics%sigma)
            tempcor = max(-50.0d0, tempcor)

            ! Calculate Glenn's A

            call patebudd(tempcor,flwa(:,ew,ns),velowk%fact,velowk%first5,fiddle) 
          else
            flwa(:,ew,ns) = fiddle
          end if
        end do
      end do

    case(1)

      ! This is the Paterson and Budd relationship, but with the temperature held constant
      ! at -5 deg C

      do ns = 1,nsn
        do ew = 1,ewn
          if (thck(ew,ns) > numerics%thklim) then

            ! Calculate Glenn's A with a fixed temperature.

            call patebudd((/(contemp, up=1,upn)/),flwa(:,ew,ns),velowk%fact,velowk%first5,fiddle) 
          else
            flwa(:,ew,ns) = fiddle
          end if
        end do
      end do

    case default 

      ! Set A equal to the value of fiddle. According to the documentation, this
      ! option means A=10^-16 yr^-1 Pa^-n, but I'm not sure how this squares with
      ! the value of fiddle, which is currently set to three.

      flwa = fiddle
  
    end select

  end subroutine calcflwa 

!------------------------------------------------------------------------------------------

  subroutine chckwvel(numerics,geomderv,uvel,vvel,wvel,thck,acab)

    !*FD Constrain the vertical velocity field to obey a kinematic upper boundary 
    !*FD condition.

    use glimmer_global, only : dp, sp 

    implicit none

    !------------------------------------------------------------------------------------
    ! Subroutine arguments
    !------------------------------------------------------------------------------------

    type(glimmer_numerics),   intent(in)    :: numerics !*FD Numerical parameters of model
    type(glimmer_geomderv),   intent(in)    :: geomderv !*FD Temporal and horizontal derivatives
                                                        !*FD of thickness and upper ice surface
                                                        !*FD elevation.
    real(dp),dimension(:,:),  intent(in)    :: uvel     !*FD $x$ velocity field at top model
                                                        !*FD level (scaled, on staggered grid).
    real(dp),dimension(:,:),  intent(in)    :: vvel     !*FD $y$ velocity field at top model
                                                        !*FD level (scaled, on staggered grid).
    real(dp),dimension(:,:,:),intent(inout) :: wvel     !*FD Vertical velocity field, 
    real(dp),dimension(:,:),  intent(in)    :: thck     !*FD Ice thickness (scaled)
    real(sp),dimension(:,:),  intent(in)    :: acab     !*FD Mass-balance (scaled)

    !------------------------------------------------------------------------------------
    ! Internal variables
    !------------------------------------------------------------------------------------

    real(dp),dimension(:,:),allocatable :: wchk
    real(dp) :: tempcoef
    integer  :: ns,ew,nsn,ewn

    ! Get array sizes -------------------------------------------------------------------

    ewn=size(thck,1) ; nsn=size(thck,2)

    ! Allocate temporary work array -----------------------------------------------------

    allocate(wchk(ewn,nsn))

    ! Loop over all grid-boxes ----------------------------------------------------------

    do ns = 2,nsn
      do ew = 2,ewn
        if (thck(ew,ns) > numerics%thklim) then

          wchk(ew,ns) = geomderv%dusrfdtm(ew,ns) &
                      - acab(ew,ns) &
                      + (sum(uvel(ew-1:ew,ns-1:ns)) * sum(geomderv%dusrfdew(ew-1:ew,ns-1:ns)) &
                       + sum(vvel(ew-1:ew,ns-1:ns)) * sum(geomderv%dusrfdns(ew-1:ew,ns-1:ns))) &
                      / 16.0d0

          tempcoef = wchk(ew,ns) / wvel(1,ew,ns)

          wvel(:,ew,ns) = wvel(:,ew,ns) * tempcoef * (1.0d0 - numerics%sigma) 
        else
          wchk(ew,ns) = 0.0d0
        end if
      end do
    end do

    deallocate(wchk)

  end subroutine chckwvel

!------------------------------------------------------------------------------------------
! PRIVATE subroutines
!------------------------------------------------------------------------------------------

  function vertintg(velowk,sigma,in)

    !*FD Performs a depth integral using the trapezium rule.
    !*RV The value of in integrated over depth.

    use glimmer_global, only : dp 

    implicit none

    !------------------------------------------------------------------------------------
    ! Subroutine arguments
    !------------------------------------------------------------------------------------

    type(glimmer_velowk), intent(inout) :: velowk !*FD Work arrays and things for this module
    real(dp),dimension(:),intent(in)    :: sigma  !*FD The model's sigma values
    real(dp),dimension(:),intent(in)    :: in     !*FD Input array of vertical velocities (size = upn)
    real(dp) :: vertintg

    !------------------------------------------------------------------------------------
    ! Internal variables
    !------------------------------------------------------------------------------------

    integer :: up, upn

    ! Set up array of sigma intervals, if not done already ------------------------------

    upn=size(in)

    if (velowk%first3) then
      allocate(velowk%dups(upn)) 
      velowk%dups = (/ (sigma(up+1) - sigma(up), up=1,upn-1),0.0d0 /)
      velowk%first3 = .false.
    end if

    ! Do integration --------------------------------------------------------------------

    vertintg = 0.0d0

    do up = upn-1, 1, -1
      vertintg = vertintg + sum(in(up:up+1)) * velowk%dups(up)                   
    end do

    vertintg = vertintg / 2.0d0

  end function vertintg


!------------------------------------------------------------------------------------------

  subroutine patebudd(tempcor,calcga,fact,first,fiddle)

    !*FD Calculates the value of Glenn's $A$ for the temperature values in a one-dimensional
    !*FD array. The input array is usually a vertical temperature profile. The equation used
    !*FD is from \emph{Paterson and Budd} [1982]:
    !*FD \[
    !*FD A(T^{*})=a \exp \left(\frac{-Q}{RT^{*}}\right)
    !*FD \]
    !*FD This is equation 9 in {\em Payne and Dongelmans}. $a$ is a constant of proportionality,
    !*FD $Q$ is the activation energy for for ice creep, and $R$ is the universal gas constant.
    !*FD The pressure-corrected temperature, $T^{*}$ is given by:
    !*FD \[
    !*FD T^{*}=T-T_{\mathrm{pmp}}+T_0
    !*FD \] 
    !*FD \[
    !*FD T_{\mathrm{pmp}}=T_0-\sigma \rho g H \Phi
    !*FD \]
    !*FD $T$ is the ice temperature, $T_{\mathrm{pmp}}$ is the pressure melting point 
    !*FD temperature, $T_0$ is the triple point of water, $\rho$ is the ice density, and 
    !*FD $\Phi$ is the (constant) rate of change of melting point temperature with pressure.

    use glimmer_global, only : dp
    use physcon, only : trpt, arrmll, arrmlh, gascon, actenl, actenh
    use paramets, only : vis0

    implicit none

    !------------------------------------------------------------------------------------
    ! Subroutine arguments
    !------------------------------------------------------------------------------------

    real(dp),dimension(:), intent(in)    :: tempcor  !*FD Input temperature profile. This is 
                                                     !*FD {\em not} $T^{*}$, as it has $T_0$
                                                     !*FD added to it later on; rather it is
                                                     !*FD $T-T_{\mathrm{pmp}}$.
    real(dp),dimension(:), intent(out)   :: calcga   !*FD The output values of Glenn's $A$.
    real(dp),dimension(4), intent(inout) :: fact     !*FD Constants for the calculation. These
                                                     !*FD are set when the subroutine is first
                                                     !*FD called.
    logical,               intent(inout) :: first    !*FD Should be set to \texttt{.true.} on the
                                                     !*FD first call.
    real(dp),              intent(in)    :: fiddle   !*FD A tuning parameter ($a$ is multiplied 
                                                     !*FD by it).

    !------------------------------------------------------------------------------------

    if (first) then

      ! Need to set up constants for calculation, if not done before --------------------

      fact = (/ fiddle * arrmlh / vis0, &   ! Value of a when T* is above -263K
                fiddle * arrmll / vis0, &   ! Value of a when T* is below -263K
               -actenh / gascon,        &   ! Value of -Q/R when T* is above -263K
               -actenl / gascon         /)  ! Value of -Q/R when T* is below -263K
      first = .false.
    end if

    ! Actual calculation is done here - constants depend on temperature -----------------

    where (tempcor >= -10.0d0)         
      calcga = fact(1) * exp(fact(3) / (tempcor + trpt))
    elsewhere
      calcga = fact(2) * exp(fact(4) / (tempcor + trpt))
    end where

  end subroutine patebudd

!------------------------------------------------------------------------------------------

  subroutine calcbtrc(velowk,params,flag,bwat,relx,btrc)

    !*FD Calculate the value of $B$ used for basal sliding calculations.

    use glimmer_global, only : dp 
    use paramets, only : thk0, vel0, len0
    use physcon, only : scyr
 
    implicit none

    !------------------------------------------------------------------------------------
    ! Subroutine arguments
    !------------------------------------------------------------------------------------

    type(glimmer_velowk),   intent(inout) :: velowk   !*FD Work arrays for this module.
    type(glimmer_paramets), intent(in)    :: params   !*FD Model parameters.
    integer,                intent(in)    :: flag     !*FD Flag to select method of
                                                      !*FD calculation. $\mathtt{flag}=0$ means
                                                      !*FD use full calculation, otherwise set $B=0$.
    real(dp),dimension(:,:),intent(in)    :: bwat     !*FD Basal melt-rate (scaled?)
    real(dp),dimension(:,:),intent(in)    :: relx     !*FD Elevation of relaxed topography
                                                      !*FD (scaled?)
    real(dp),dimension(:,:),intent(out)   :: btrc     !*FD Array of values of $B$.
                                                      !*FD {\bf N.B. This array is smaller
                                                      !*FD in each dimension than the other two}
                                                      !*FD (\texttt{bwat} and \texttt{relx}) {\bf by
                                                      !*FD one.} So its dimensions are (ewn-1,nsn-1).

    !------------------------------------------------------------------------------------
    ! Internal variables
    !------------------------------------------------------------------------------------
 
    real(dp) :: stagbwat 
    integer :: ew,ns,nsn,ewn

    !------------------------------------------------------------------------------------
  
    ewn=size(bwat,1) ; nsn=size(bwat,2)

    !------------------------------------------------------------------------------------

    if (velowk%first6) then
      velowk%watwd  = params%bpar(1) / params%bpar(2)
      velowk%watct  = params%bpar(2) 
      velowk%trcmin = params%bpar(3) / scyr
      velowk%trcmax = params%bpar(4) / scyr
      velowk%marine = params%bpar(5)
      velowk%trc0   = vel0 * len0 / (thk0**2)
      velowk%trcmax = velowk%trcmax / velowk%trc0
      velowk%trcmin = velowk%trcmin / velowk%trc0
      velowk%c(1)   = (velowk%trcmax - velowk%trcmin) / 2.0d0 + velowk%trcmin
      velowk%c(2)   = (velowk%trcmax - velowk%trcmin) / 2.0d0
      velowk%c(3)   = velowk%watwd * thk0 / 4.0d0
      velowk%c(4)   = velowk%watct * 4.0d0 / thk0 
      velowk%first6 = .false. 
    end if

    !------------------------------------------------------------------------------------

    select case(flag)
    case(0)

      do ns = 1,nsn-1
        do ew = 1,ewn-1
          stagbwat = sum(bwat(ew:ew+1,ns:ns+1))

          if (0.0d0 < stagbwat) then
            btrc(ew,ns) = velowk%c(2) * tanh(velowk%c(3) * &
                          (stagbwat - velowk%c(4))) + velowk%c(1)
            if (0.0d0 > sum(relx(ew:ew+1,ns:ns+1))) then
              btrc(ew,ns) = btrc(ew,ns) * velowk%marine  
            end if
          else
            btrc(ew,ns) = 0.0d0
          end if
        end do
      end do

    case default
      btrc = 0.0d0
    end select

  end subroutine calcbtrc

end module glimmer_velo
