! ism_advect.f90
! Magnus Hagdorn, March 2003
!
! for solving dx/dt=v(x,t)

module erosion_advect

  ! private data
  real, private, dimension(:,:), allocatable :: ux, uy
  integer, private :: numx,numy
  real, private :: x0, y0
  real, private :: deltax,deltay
  real, private :: deltax_r,deltay_r
  real, private :: eps
  
contains
  subroutine er_advect2d_init(x0d,y0d,numxd,numyd,deltaxd,deltayd)
    !initialise advection
    implicit none
    real, intent(in)    :: x0d,y0d         ! lower left corner of grid
    integer, intent(in) :: numxd,numyd     ! number of nodes
    real, intent(in)    :: deltaxd,deltayd ! node spacing

    x0 = x0d
    y0 = y0d
    numx = numxd
    numy = numyd
    deltax = deltaxd
    deltay = deltayd
    deltax_r = 1./deltaxd
    deltay_r = 1./deltayd
    allocate(ux(numx,numy))
    allocate(uy(numx,numy))
    eps = 0.00001*min(deltax,deltay)

  end subroutine er_advect2d_init

  subroutine er_advect2d(times, x0d, y0d, x, y)
    use rk4module
    implicit none
    real, intent(in), dimension(:) :: times   ! array of times at which position should be saved
    real, intent(in) :: x0d, y0d              ! initial conditions
    real, intent(out), dimension(:) :: x, y   ! x component of location

    ! local variables
    integer j
    real t1,t2
    real, dimension(2) :: xtemp
    integer :: nok, nbad

    t1 = 0.
    xtemp(1) = x0d
    xtemp(2) = y0d
    
    do j=1,size(times)
       t2 = times(j)
       call odeint(xtemp,t1,t2,eps,10.,0.,nok,nbad,interp_velos)
       x(j) = xtemp(1)
       y(j) = xtemp(2)
       
       t1 = times(j)
    end do

  end subroutine er_advect2d

  subroutine interp_velos(t, x, velo)
    implicit none
    real, intent(in) :: t
    real, intent(in), dimension(2) :: x
    real, intent(out), dimension(2) :: velo
    real :: p1, p2

    integer, dimension(4) :: i,j

    i(1) = 1+floor((x(1)-x0)*deltax_r)
    j(1) = 1+floor((x(2)-y0)*deltay_r)
    i(2) = i(1) + 1
    j(2) = j(1)
    i(3) = i(1) + 1
    j(3) = j(1) + 1
    i(4) = i(1)
    j(4) = j(1) + 1
    
    i = min(i,numx)
    i = max(i,1)
    j = min(j,numy)
    j = max(j,1)
    
    p1 = (x(1)-x0-(i(1)-1)*deltax)*deltax_r
    p2 = (x(2)-y0-(j(1)-1)*deltay)*deltay_r

    velo(1) = (1-p1)*(1-p2)*ux(i(1),j(1)) + p1*(1-p2)*ux(i(2),j(2)) &
         + p1*p2*ux(i(3),j(3)) + (1-p1)*p2*ux(i(4),j(4))

    velo(2) = (1-p1)*(1-p2)*uy(i(1),j(1)) + p1*(1-p2)*uy(i(2),j(2)) &
         + p1*p2*uy(i(3),j(3)) + (1-p1)*p2*uy(i(4),j(4))    
  end subroutine interp_velos
  
  subroutine set_velos(x,y)
    implicit none
    real, dimension(:,:) :: x,y
    ux = x
    uy = y
  end subroutine set_velos
end module erosion_advect
