! +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
! +                                                           +
! +  erosion_sediment.f90 - part of the GLIMMER ice model     + 
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

module erosion_sediment
  !*FD module handling properties of deforming sediment layer

  use glimmer_global, only : dp

  private
  public :: er_sediment_init,er_sediment_tstep,er_sediment_finalise

contains
  subroutine er_sediment_init(seds,model)
    !*FD initialise deforming sediment layer
    use physcon, only : pi, scyr
    use paramets, only: vel0
    use glide_types
    use erosion_types
    implicit none

    type(er_sed_type) :: seds              !*FD sediment type
    type(glide_global_type) :: model       !*FD model instance

    ! allocate memory
    call coordsystem_allocate(model%general%velo_grid, seds%za)
    call coordsystem_allocate(model%general%velo_grid, seds%tau_mag)
    call coordsystem_allocate(model%general%velo_grid, seds%tau_dir)
    call coordsystem_allocate(model%general%velo_grid, seds%velx)
    call coordsystem_allocate(model%general%velo_grid, seds%vely)

    seds%alpha = 1./(seds%eff_press_grad*tan(seds%phi*pi/180.))
    seds%beta  = -(seds%effective_pressure+seds%c/tan(seds%phi*pi/180.))/seds%eff_press_grad

    ! scaling goes here
    seds%a = seds%a/(scyr * vel0)

    ! set up flow law parameters
    seds%params(2) = seds%a
    seds%params(3) = seds%n
    seds%params(4) = -seds%m
    seds%params(5) = seds%effective_pressure
    seds%params(6) = seds%eff_press_grad
    seds%params(7) = seds%c
    seds%params(8) = tan(seds%phi*pi/180.)

  end subroutine er_sediment_init

  subroutine er_sediment_tstep(erosion,model)
    !*FD calculate deforming sediment layer thickness and average velo
    use glide_types
    use erosion_types
    implicit none

    type(erosion_type) :: erosion          !*FD data structure holding erosion stuff
    type(glide_global_type) :: model       !*FD model instance

    ! transform basal shear from cartesian to radial components
    call er_trans_tau(erosion%sediment,model)

    ! calculate sediment thickness
    call calc_za(erosion%sediment)

    ! calculate sediment velocities
    call calc_velo(erosion,model)

    erosion%sediment%za = -erosion%sediment%za
  end subroutine er_sediment_tstep

  subroutine er_sediment_finalise(seds)
    !*FD deallocate memory, etc.
    use erosion_types
    implicit none
    type(er_sed_type) :: seds              !*FD sediment type
  
    deallocate(seds%za)
    deallocate(seds%tau_mag)
    deallocate(seds%tau_dir)
    deallocate(seds%velx)
    deallocate(seds%vely)
  end subroutine er_sediment_finalise

  ! ----------------------------------------------------------------------------
  ! private procedures
  ! ----------------------------------------------------------------------------

  subroutine er_trans_tau(seds,model)
    !*FD transform basal shear from cartesian to radial components
    !*FD and scale to kPa
    use paramets
    use glide_types
    use erosion_types
    implicit none

    type(er_sed_type) :: seds              !*FD sediment type
    type(glide_global_type) :: model       !*FD model instance

    real(kind=dp),parameter :: fact = 1e-3*thk0*thk0/len0
    integer ew,ns

    seds%tau_dir=0
    seds%tau_mag=0
    do ns=1,model%general%nsn-1
       do ew=1,model%general%ewn-1
          if (abs(model%velocity%ubas(ew,ns))+abs(model%velocity%vbas(ew,ns)) .gt. 0.) then
             seds%tau_dir(ew,ns) = atan2(model%velocity%tau_y(ew,ns),model%velocity%tau_x(ew,ns))
             seds%tau_mag(ew,ns) = sqrt(model%velocity%tau_y(ew,ns)**2+model%velocity%tau_x(ew,ns)**2)*fact
          end if
       end do
    end do
  end subroutine er_trans_tau

  subroutine calc_za(seds)
    !*FD calculate depth of deforming layer
    use glide_types
    use erosion_types
    implicit none

    type(er_sed_type) :: seds              !*FD sediment type

    where (seds%tau_mag.gt.0)
       seds%za = min(seds%alpha * seds%tau_mag + seds%beta,0.d0)
    elsewhere
       seds%za = 0
    end where
  end subroutine calc_za

  real(kind=dp) pure function calc_n(z,N0,Nz)
    !*FD calculate effective pressure
    implicit none
    real(kind=dp), intent(in) :: z  !*FD depth
    real(kind=dp), intent(in) :: N0 !*FD effective pressure at ice base
    real(kind=dp), intent(in) :: Nz !*FD effective pressure gradient
    
    calc_n = N0+Nz*z
  end function calc_n
  
  real(kind=dp) pure function calc_sigma(z,N0,Nz,tan_phi,cohesion)
    !*FD calculate yield stress
    implicit none
    real(kind=dp), intent(in) :: z  !*FD depth
    real(kind=dp), intent(in) :: N0 !*FD effective pressure at ice base
    real(kind=dp), intent(in) :: Nz !*FD effective pressure gradient
    real(kind=dp), intent(in) :: tan_phi !*FD tan of angle of internal friction
    real(kind=dp), intent(in) :: cohesion !*FD cohesion
    
    calc_sigma = calc_n(z,N0,Nz)*tan_phi+cohesion
  end function calc_sigma

  real(kind=dp) function flow_law(z,params)
    !*FD first sediment flow law depending only on the basal shear stress
    !*FD params(1) : taub
    !*FD params(2) : A
    !*FD params(3) : n
    !*FD params(4) : -m
    !*FD params(5) : N0
    !*FD params(6) : dN/dz
    !*FD params(7) : c
    !*FD params(8) : tan(phi)
    !*FD params(9) : za
    !*FD params(10): flowlaw
    !*FD params(11): avrg


    implicit none
    real(kind=dp),intent(in)  :: z
    real(kind=dp),dimension(:),intent(in) :: params


    flow_law = params(2)*abs(params(1)-calc_sigma(z,params(5),params(6),params(8),params(7)))**params(3) * &
         calc_n(z,params(5),params(6))**params(4)
    if (params(9).gt.0) then
       flow_law = (params(9)-z)*flow_law
    end if
  end function flow_law

  subroutine calc_velo(erosion,model)
    !*FD calculate sediment velocities by integrating one of the flow laws
    use erosion_types
    use glide_types
    use glimmer_integrate
    implicit none

    type(erosion_type) :: erosion     !*FD data structure holding erosion stuff
    type(glide_global_type) :: model       !*FD model instance
    
    integer ew,ns
    real(kind=dp) total,part

    erosion%sediment%params(10) = 1
    do ns=1,model%general%nsn-1
       do ew=1,model%general%ewn-1
          if (erosion%sediment%za(ew,ns).lt.0. .and. erosion%seds2(ew,ns).gt.0.) then
             erosion%sediment%params(1) = erosion%sediment%tau_mag(ew,ns)
             erosion%sediment%params(9) = 0.
             total = romberg_int(flow_law,erosion%sediment%za(ew,ns),0.d0,erosion%sediment%params)
             erosion%sediment%params(9) = -erosion%seds2(ew,ns)
             part = romberg_int(flow_law,erosion%sediment%za(ew,ns),-erosion%seds2(ew,ns),erosion%sediment%params)
             erosion%sediment%velx(ew,ns) = (total - part)/erosion%seds2(ew,ns)
          else
             erosion%sediment%velx(ew,ns) =  0.
          end if
       end do
    end do

    erosion%sediment%vely = sin(erosion%sediment%tau_dir)*erosion%sediment%velx
    erosion%sediment%velx = cos(erosion%sediment%tau_dir)*erosion%sediment%velx

  end subroutine calc_velo

end module erosion_sediment
