! ism_advect.f90
! Magnus Hagdorn, March 2003
!
! for solving dx/dt=v(x,t)

module erosion_advect

  use glimmer_global, only : dp
  use glimmer_coordinates

  ! private data
  real(kind=dp), private, dimension(:,:), pointer :: ux, uy
  type(coordsystem_type), private :: coords
  real(kind=dp), private :: eps
  
contains
  subroutine er_advect2d_init(velo_coords)
    !initialise advection
    implicit none
    type(coordsystem_type) :: velo_coords ! coordinate system for velo grid
    
    call coordsystem_allocate(velo_coords, ux)
    call coordsystem_allocate(velo_coords, uy)

    coords = velo_coords

    eps = 0.00001*minval(velo_coords%delta%pt)

  end subroutine er_advect2d_init

  subroutine er_advect2d(times, x0d, y0d, x, y)
    use rk4module
    implicit none
    real(kind=dp), intent(in), dimension(:) :: times   ! array of times at which position should be saved
    real(kind=dp), intent(in) :: x0d, y0d              ! initial conditions
    real(kind=dp), intent(out), dimension(:) :: x, y   ! x component of location

    ! local variables
    integer j
    real(kind=dp) t1,t2
    real(kind=dp), dimension(2) :: xtemp
    integer :: nok, nbad

    t1 = 0.
    xtemp(1) = x0d
    xtemp(2) = y0d
    
    do j=1,size(times)
       t2 = times(j)
       call odeint(xtemp,t1,t2,eps,10.d0,0.d0,nok,nbad,interp_velos)
       x(j) = xtemp(1)
       y(j) = xtemp(2)
       
       t1 = times(j)
    end do

  end subroutine er_advect2d

  subroutine interp_velos(t, x, velo)
    use glimmer_interpolate2d
    implicit none
    real(kind=dp), intent(in) :: t
    real(kind=dp), intent(in), dimension(2) :: x
    real(kind=dp), intent(out), dimension(2) :: velo

    ! local vars
    type(coord_point) :: pnt
    type(coord_ipoint), dimension(4) :: nodes
    real(kind=dp), dimension(4) :: weights

    integer k
    
    pnt%pt(:) = x(:)
    call glimmer_bilinear(coords,pnt,nodes,weights)

    velo(:) = 0.d0
    do k=1,4
       velo(1) = velo(1) + weights(k)*ux(nodes(k)%pt(1),nodes(k)%pt(2))
       velo(2) = velo(2) + weights(k)*uy(nodes(k)%pt(1),nodes(k)%pt(2))
    end do
  end subroutine interp_velos
  
  subroutine set_velos(x,y,factor)
    implicit none
    real(kind=dp), dimension(:,:) :: x,y
    real(kind=dp), optional :: factor
    ! local variables
    real(kind=dp) :: f

    if (present(factor)) then
       f = factor
    else
       f = 1.
    end if

    ux = f*x
    uy = f*y
  end subroutine set_velos
end module erosion_advect
