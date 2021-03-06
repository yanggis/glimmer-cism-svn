module plume_global

  implicit none

  public 

  !parameter used to declare double-precision reals
  integer,parameter::kdp = kind(1.0d0)
  integer,parameter::ksp = kind(1.0e0)

  ! set array sizes to maximum (data storage actually used set later)
  ! lamb = maximum number of vertical levels for ambient fluid t,s,rho 
  ! lice = maximum no of frazil size classes
  ! linf = maximum no of inflows
  ! ldr = maximum number of regions in which drag coefficient is varied
  ! lsm = maximum number of regions in which smoothing is varied
  integer,parameter :: lxin=1000,lyin=1000
  integer,parameter :: lamb=302, lice=10, linf=9,ldr=3,lsm=3,ldec=26

  !variables for cell dimensions
  real(kind=kdp) :: hx,hy



  real(kind=kdp),allocatable,dimension(:) :: dx,dxu,rdx,rdxu
  real(kind=kdp),allocatable,dimension(:) :: dy,dyv,rdy,rdyv

  ! variables for plume thickness(pdep), interface position(ipos), 
  ! ice shelf bottom depth(bpos) and position
  ! bpos and ipos are heights above a fictitious water level
  ! at depth gldep+wcdep 

  real(kind=kdp),allocatable,dimension(:,:) :: pdep,ipos,bpos

  !cell incices demarking status of cell

  !     jcs sea cell = 1, land cell = 0
  !     jcw wet = 1, dry = 0
  !      _fl      =>  newly-wet = 1
  !      _negdep  =>  negative depths = 1
  !      _fseed   =>  frazil seeded = 1

  integer,allocatable,dimension(:,:) :: jcs,jcw,jcd_u,jcd_v
  integer,allocatable,dimension(:,:) :: jcd_fl,jcd_negdep,jcd_fseed

  !ice-related variables
  real(kind=kdp),allocatable,dimension(:,:,:) :: c,ca 
  real(kind=kdp),allocatable,dimension(:,:) :: ctot,ctota,tf
  real(kind=kdp),pointer,dimension(:,:) :: bmelt
  real(kind=kdp),allocatable,dimension(:,:) :: btemp,bsalt,ctempd
  real(kind=kdp),allocatable,dimension(:,:) :: tint !ice shelf interior temperature

  !ice-related parameters
  real(kind=kdp) :: lat,c0,ci,nu0,pr,sc,fta,ftb,ftc,si,nus,kt,ks,tiuniform
  real(kind=kdp) :: ar,eps,nbar,r(lice),re(lice),thi(lice),vol(lice)
  real(kind=kdp) :: wi(lice),cmin(lice),cseed(lice),nuss(lice)

  !frazil interaction terms
  integer :: seedtype	
  real(kind=kdp),allocatable,dimension(:,:,:) :: fmelt,fppn,fnuc

  !inflow-related variables and initial thickness
  logical :: inflag(linf)
  integer :: infloa,infloe,knfloa,knfloe
  integer,allocatable,dimension(:,:) :: intrin !inflow tracers

  real(kind=kdp),dimension(:,:),allocatable :: saltinf,tempinf,depinf
  real(kind=kdp),dimension(:,:,:),allocatable :: intr,intra

  real(kind=kdp) :: meltinf,cinf(lice),cinftot,depinffix,depinit

  !array limits actually used
  integer :: m_grid,n_grid,namb,nice

  !array limits selected by external caller (ie Glimmer-CISM)
  integer :: domain_imin,domain_imax,domain_kmin,domain_kmax

  !TODO: what are these?
  integer :: ninfmin,ninfmax

  !option switches
  logical :: mixlayer,in_glimmer,restart,nonlin,horturb,entrain,basmelt,frazil
  logical :: rholinear,thermobar,intrace,vardrag,topedit,tangle,negfrz
  logical :: use_min_plume_thickness
  integer :: entype

  ! restart data filename
  character(len=256) :: restart_data_filename

  !general parameters
  real(kind=kdp) :: pi,dcr,g,dt,gdt,fdt,small,edepth,mdepth,fdepth,septol
  real(kind=kdp) :: ah,kh,dzincr,temptop,tempbot,saltbot,salttop
  real(kind=kdp) :: tgrad,sgrad,wcdep,gldep,ifdep,rho0,rhoi
  real(kind=kdp) :: plume_min_thickness
  real(kind=kdp) :: cdb,cdbvar,ef,cl
  real(kind=kdp) :: phi ! latitude
  real(kind=kdp) :: radian,f	

  real(kind=kdp) :: dt1,dt2,dtswtim ! first timestep size, second timestep size, time at which to switch to second stepsize	

  !scalar fields
  real(kind=kdp),allocatable,dimension(:,:) :: rhop,temp,tempa,tins
  real(kind=kdp),allocatable,dimension(:,:) :: salt,salta,rhoamb
  real(kind=kdp),allocatable,dimension(:,:) :: entr,atemp,asalt,drag,thk_def
  real(kind=kdp) :: samb(lamb),tamb(lamb),rhovf(lamb)
  real(kind=kdp) :: frzcut(lice)

  logical :: drflag(ldr)

  !topography parameters
  character(len=6) :: context
  logical :: smflag(lsm)
  integer :: bathtype,kcorn,rad,bsmoothit,smoothit(lsm)
  real(kind=kdp) :: cweight,nweight
  real(kind=kdp) :: channel_amplitude,cross_slope_wavenumber,along_slope_deepening_exp
  real(kind=kdp) :: random_amplitude

  !eddy viscosities
  real(kind=kdp),allocatable,dimension(:) :: ahdx,ahdxu,ahdy,ahdyv

  ! transports (depth integrated velocities)
  real(kind=kdp),allocatable,dimension(:,:) :: u,v
  ! arrays holding a copy of the transports from the previous timestep 
  real(kind=kdp),allocatable,dimension(:,:) :: ua,va
  ! average velocities
  real(kind=kdp),allocatable,dimension(:,:) :: su,sv

  ! velocities at base of Ekman layer (for turning-angle calculation)
  real(kind=kdp),allocatable,dimension(:,:) :: u0,v0,u0a,v0a
  ! turning angle 
  real(kind=kdp),allocatable,dimension(:,:) :: tang

  integer,private :: count,count_rate,count_max
  real(kind=ksp),private :: sys_tim_a,sys_tim_b
  real(kind=kdp),private :: systim

contains

  subroutine allocate_arrays()

    integer :: m,n
    m  = m_grid
    n = n_grid

    allocate (dx (m), dxu(m), rdx (m), rdxu (m))
    allocate (dy (n), dyv (n),rdy (n), rdyv (n))
    allocate (pdep(m,n),ipos(m,n),bpos(m,n))
    allocate (jcs(m,n),jcw(m,n),jcd_u(m,n),jcd_v(m,n),jcd_fl(m,n))
    allocate (jcd_negdep(m,n),jcd_fseed(m,n))
    allocate (c(m,n,lice),ca(m,n,lice),ctot(m,n),ctota(m,n))
    allocate (tf(m,n))
    allocate (bmelt(m,n))
    allocate (btemp(m,n),bsalt(m,n),ctempd(m,n))

    allocate (fmelt(m,n,lice),fppn(m,n,lice),fnuc(m,n,lice))
    allocate (saltinf(m,n),tempinf(m,n),depinf(m,n),intr(m,n,linf))
    allocate (intra(m,n,linf),intrin(m,n))

    allocate (rhop(m,n),temp(m,n),tempa(m,n),tins(m,n))
    allocate (salt(m,n),salta(m,n),rhoamb(m,n))
    allocate (entr(m,n),thk_def(m,n))
    allocate (atemp(m,n),asalt(m,n))
    allocate (drag(m,n))

    allocate (ahdx(m),ahdxu(m),ahdy(n),ahdyv(n))

    allocate (u(m,n),ua(m,n),v(m,n),va(m,n))
    allocate (su(m,n),sv(m,n))
    allocate (u0(m,n),v0(m,n),u0a(m,n),v0a(m,n))
    allocate (tang(m,n))

    allocate (tint(m,n))

  end subroutine allocate_arrays

  subroutine deallocate_arrays()

    deallocate(dx,dxu,rdx,rdxu,dy,dyv,rdy,rdyv)
    deallocate(intrin)
    deallocate(pdep,ipos,bpos)
    deallocate(jcs,jcw,jcd_u,jcd_v,jcd_fl,jcd_negdep,jcd_fseed)
    deallocate(c,ca,ctot,ctota,tf,btemp,bsalt,ctempd)
    deallocate(bmelt)
    deallocate(fmelt,fppn,fnuc)
    deallocate(saltinf,tempinf,depinf,intr,intra)
    deallocate(ahdx,ahdxu,ahdy,ahdyv)
    deallocate(rhop,temp,tempa,tins,salt,salta,rhoamb,entr,atemp,asalt,drag,thk_def)
    deallocate(u,ua,v,va,su,sv,u0,v0,u0a,v0a,tang)
    deallocate(tint)

  end subroutine deallocate_arrays

  subroutine reset_elapsed_sys_time()

    systim = 0.d0
    call system_clock(count,count_rate,count_max)
    sys_tim_a = real(count) / count_rate

  end subroutine reset_elapsed_sys_time

  integer function get_elapsed_sys_time()

    call system_clock(count,count_rate,count_max)
    sys_tim_b = real(count) / count_rate
    systim = systim + (sys_tim_b-sys_tim_a)
    sys_tim_a = sys_tim_b

    get_elapsed_sys_time = systim

  end function get_elapsed_sys_time

end module plume_global

