module mod_geom
  use mod_za,only : zaiost,zaiopf,zaiord,zaiocl,idm,jdm
  use mod_gribio, only: rdgrib
  use mod_flags
  private
  implicit none
  public hycom_na_mercator, hycom_global_tripolar,hycom_na, &
       mrf_gaussian,rd_hycom_grid_params,mask_mrf &
       ,horiz_intp,horiz_intp_,global_extend !!$$ ,extend_fld
  !
  real,parameter:: radian=57.2957795
  interface hycom_na_mercator
     module procedure hycom_na_mercator_calc
     module procedure hycom_na_mercator_read
  end interface
  interface hycom_global_tripolar
     module procedure hycom_global_tripolar_read
  end interface
  interface hycom_na
     module procedure hycom_na_read
     module procedure hycom_na_calc
  end interface
  interface mask_mrf
     module procedure mask_mrf_1
     module procedure mask_mrf_2
  end interface
  interface horiz_intp
     module procedure horiz_intp_
     module procedure horiz_intp_msk
     module procedure horiz_intp_init
  end interface
  interface global_extend
     module procedure global_extend_latlon_1d
     module procedure global_extend_field_2d
     module procedure global_extend_field_3d
     module procedure global_extend_mask
  end interface
contains
  !
  !========================================================================
  !
  subroutine hycom_na_mercator_calc(gridsz,pntlat,reflon,exhycom,eyhycom,dbgn)
    real,parameter:: e10=1.5707963268 
    real, intent(in) :: gridsz,pntlat,reflon
    integer, intent(in) :: dbgn
    real, dimension(:),intent(out) :: exhycom
    real, dimension(:),intent(out) :: eyhycom
    integer nxhycom,nyhycom,i
    real, dimension(:), allocatable ::  xhycom,yhycom
    !  
    nxhycom=size(exhycom)-1
    nyhycom=size(eyhycom)-1
    allocate(xhycom(nxhycom),yhycom(nyhycom))
    !
    !   calculate latitudes and longitudes of HYCOM mercator grid.
    !
    yhycom=(/((2.*atan(exp(gridsz*(i-pntlat)/radian))-e10)*radian,i=1,nyhycom)/)
    xhycom=(/(mod(gridsz*(i-1)+reflon+180.,360.)-180.,i=1,nxhycom)/)
    !
    !   Calculate grid edges ( coordinates are supposed to increase )
    ! 
    exhycom(1:nxhycom)=(xhycom(1:nxhycom)-0.5*gridsz)/radian
    exhycom(nxhycom+1)=(xhycom(nxhycom)+0.5*gridsz)/radian
    !
    eyhycom(1)=(yhycom(1)-0.5*(yhycom(2)-yhycom(1)))/radian
    eyhycom(2:nyhycom)=(/(0.5*(yhycom(i-1)+yhycom(i))/radian,i=2,nyhycom)/)
    eyhycom(nyhycom+1)=(yhycom(nyhycom)+0.5*(yhycom(nyhycom)-yhycom(nyhycom-1)))/radian
    !
    if (dbgn>=2) then
       write (*,'("yhycom ==========")')
       write (*,'(8F10.4)') (yhycom(i),i=1,nyhycom)
       write (*,'("xhycom ==========")')
       write (*,'(1X,I5,F10.4)') (i,xhycom(i),i=1,nxhycom)
       write (*,'("eyhycom ==========")')
       write (*,'(1X,I5,2F10.4)') (i,eyhycom(i),eyhycom(i)*radian,i=1,nyhycom+1)
       write (*,'("exhycom ==========")')
       write (*,'(1X,I5,2F10.4)') (i,exhycom(i),exhycom(i)*radian,i=1,nxhycom+1)
    endif
  end subroutine hycom_na_mercator_calc
  !
  !========================================================================
  !
  subroutine hycom_na_mercator_read(exhycom,eyhycom,dbgn)
    integer, intent(in) :: dbgn
    real, dimension(:),intent(out) :: exhycom
    real, dimension(:),intent(out) :: eyhycom
    integer nxhycom,nyhycom,i
    real, dimension(:,:), allocatable ::  plon,plat
    integer, dimension(:,:), allocatable ::  ip
    real hmina,hmaxa,gridsz
    !  
    nxhycom=size(exhycom)-1
    nyhycom=size(eyhycom)-1
    allocate(ip(nxhycom,nyhycom),plon(nxhycom,nyhycom),plat(nxhycom,nyhycom))
    !
    !   read latitudes and longitudes of HYCOM mercator grid.
    !
    ip=0.
!!!    call zaiost 
    call zaiopf('regional.grid.a','old', 9)
    call zaiord(plon, ip,.false., hmina,hmaxa, 9)
    write(*,*) 'reading latitudes max min=',hmina,hmaxa
    call zaiord(plat, ip,.false., hmina,hmaxa, 9)
    write(*,*) 'reading longitudes max min=',hmina,hmaxa
    call zaiocl(9)
    ! why? Carlos
    plon(:,:)=plon(:,:)-360.
    !
    !   Calculate grid edges ( coordinates are supposed to increase )
    ! 
    gridsz=abs(plat(1,1)-plat(1,2))
    exhycom(1:nxhycom)=(plon(1:nxhycom,1)-0.5*gridsz)/radian
    exhycom(nxhycom+1)=(plon(nxhycom,1)+0.5*gridsz)/radian
    !
    eyhycom(1)=(plat(1,1)-0.5*(plat(1,2)-plat(1,1)))/radian
    eyhycom(2:nyhycom)=(/(0.5*(plat(1,i-1)+plat(1,i))/radian,i=2,nyhycom)/)
    eyhycom(nyhycom+1)=(plat(1,nyhycom)+0.5*(plat(1,nyhycom)-plat(1,nyhycom-1)))/radian
    !
    if (dbgn>=2) then
       write (*,*)'gridsz=',gridsz
       write (*,'("plat ==========")')
       write (*,'(8F10.4)') (plat(1,i),i=1,nyhycom)
       write (*,'("plon ==========")')
       write (*,'(1X,I5,F10.4)') (i,plon(i,1),i=1,nxhycom)
       write (*,'("eyhycom ==========")')
       write (*,'(1X,I5,2F10.4)') (i,eyhycom(i),eyhycom(i)*radian,i=1,nyhycom+1)
       write (*,'("exhycom ==========")')
       write (*,'(1X,I5,2F10.4)') (i,exhycom(i),exhycom(i)*radian,i=1,nxhycom+1)
    endif
  end subroutine hycom_na_mercator_read
  !
  !========================================================================
  !
  subroutine hycom_global_tripolar_read(anhycom,qxhycom,qyhycom,dbgn)
    integer, intent(in) :: dbgn
    real, dimension(:,:),intent(out)  :: qxhycom
    real, dimension(:,:),intent(out)  :: qyhycom
    real, dimension(:,:),intent(out)  :: anhycom
    ! integer, dimension(:,:),intent(inout)  :: imsk
    integer :: nxhycom,nyhycom,i,j
    real, dimension(:,:), allocatable ::  plon,plat
    real, dimension(:,:), allocatable ::  qlon,qlat
    real, dimension(:,:), allocatable ::  tmp
    integer, dimension(:,:), allocatable ::  ip1
    real hmina,hmaxa
    !  
    nxhycom=size(qxhycom,dim=1)-1
    nyhycom=size(qxhycom,dim=2)-1
    print *,'hycom_global_tripolar: nxhycom,nyhycom=',nxhycom,nyhycom !dbgzp
    allocate(ip1(nxhycom,nyhycom),plon(nxhycom,nyhycom),plat(nxhycom,nyhycom))
    allocate(tmp(nxhycom,nyhycom),qlon(nxhycom,nyhycom),qlat(nxhycom,nyhycom))
    plon=0.0 !dbgz
    plat=0.0 !dbgz
    qlon=0.0 !dbgz
    qlat=0.0 !dbgz
    print *,'size(ip1)=',size(ip1,dim=1), size(ip1,dim=2)!dbgzp
    print *,'size(plon)=',size(plon,dim=1),size(plon,dim=2) !dbgzp
    print *,'size(plat)=',size(plat,dim=1),size(plat,dim=2) !dbgzp
    print *,'size(qlon)=',size(qlon,dim=1),size(qlon,dim=2) !dbgzp
    print *,'size(qlat)=',size(qlat,dim=1), size(qlat,dim=2)!dbgzp
    print *,'size(anhycom)=',size(anhycom,dim=1), size(anhycom,dim=2)!dbgzp
    !
    !   read latitudes and longitudes of HYCOM mercator grid.
    !
    ip1=0.
!!!    call zaiost 
    call zaiopf('regional.grid.a','old', 9)
     call zaiord(plon, ip1,.false., hmina,hmaxa, 9)
     write(*,*) 'reading p-longitudes max min=',hmina,hmaxa!dbgzp
     print *,'first:  min(plon), max(plon)=',minval(plon), maxval(plon)
     call zaiord(plat, ip1,.false., hmina,hmaxa, 9)
     write(*,*) 'reading p-latitudes max min=',hmina,hmaxa!dbgzp
     print *,'first:  min(plat), max(plat)=',minval(plat), maxval(plat)
     call zaiord(qlon, ip1,.false., hmina,hmaxa, 9)
     write(*,*) 'reading q-longitudes max min=',hmina,hmaxa!dbgzp
     call zaiord(qlat, ip1,.false., hmina,hmaxa, 9)
     write(*,*) 'reading q-latitudes max min=',hmina,hmaxa!dbgzp
     ! skip records until  angle is read
     do i=1,5
       call zaiord(tmp, ip1,.false., hmina,hmaxa, 9)
    enddo
    write(*,*) 'reading angles max min=',hmina,hmaxa
    print *,'min(anhycom), max(anhycom)=',minval(tmp), maxval(tmp)!dbgz
    write(*,*) 'reading angle between x-axis and East max min=',hmina,hmaxa
    call zaiocl(9)
    !
    ! set ang to radians
    anhycom(:,:)= tmp(:,:)*acos(-1.0)/180.0
    print *,'before: min(plon), max(plon)=',minval(plon), maxval(plon)
    print *,'before: min(plat), max(plat)=',minval(plat), maxval(plat)
    print *,'before: min(qlon), max(qlon)=',minval(qlon), maxval(qlon)
    print *,'before: min(qlat), max(qlat)=',minval(qlat), maxval(qlat)
    ! range of longitude in the range of [-180,180]
    plon=plon-360.
    qlon=qlon-360.
    where(plon<-180.0)plon=360.0+plon
    where(qlon<-180.0)qlon=360.0+qlon
    print *,'after:  min(plon), max(plon)=',minval(plon), maxval(plon)
    print *,'after:  min(plat), max(plat)=',minval(plat), maxval(plat)
    print *,'after:  min(qlon), max(qlon)=',minval(qlon), maxval(qlon)
    print *,'after:  min(qlat), max(qlat)=',minval(qlat), maxval(qlat)
    !
    !   Calculate grid edges 
    ! 
    qyhycom(1:nxhycom,1:nyhycom)=qlat/radian
    qyhycom(nxhycom+1,2:nyhycom+1)=plat(nxhycom,1:nyhycom)/radian
    qyhycom(2:nxhycom+1,nyhycom+1)=plat(1:nxhycom,nyhycom)/radian
    !   corners
    !   not really needed
    qyhycom(1,nyhycom+1)=plat(1,nyhycom)/radian
    qyhycom(nxhycom+1,1)=plat(nxhycom,1)/radian

    qxhycom(1:nxhycom,1:nyhycom)=qlon/radian
    qxhycom(nxhycom+1,2:nyhycom+1)=plon(nxhycom,1:nyhycom)/radian
    qxhycom(2:nxhycom+1,nyhycom+1)=plon(1:nxhycom,nyhycom)/radian
    !   corners
    !   not really needed
    qxhycom(1,nyhycom+1)=plon(1,nyhycom)/radian
    qxhycom(nxhycom+1,1)=plon(nxhycom,1)/radian
    !
    print *,'min(qxhycom), max(qxhycom) [in degrees] =',minval(qxhycom)*radian, maxval(qxhycom)*radian
    print *,'min(qyhycom), max(qyhycom) [in degrees] =',minval(qyhycom)*radian, maxval(qyhycom)*radian
    if (dbgn>=2) then
       write (*,'("plat ==========")')
       write (*,'(8F10.4)') (plat(1,i),i=1,nyhycom)
       write (*,'("plon ==========")')
       write (*,'(1X,I5,F10.4)') (i,plon(i,1),i=1,nxhycom)
       write (*,'("qyhycom ==========")')
       write (*,'(1X,I5,2F10.4)') (i,qyhycom(1,i),qyhycom(1,i)*radian,i=1,nyhycom+1,10)
       write (*,'("qxhycom ==========")')
       write (*,'(1X,I5,2F10.4)') (i,qxhycom(i,1),qxhycom(i,1)*radian,i=1,nxhycom+1,10)
    endif
    deallocate(ip1,plon,plat,qlon,qlat)
    !
  end subroutine hycom_global_tripolar_read
  !
  !========================================================================
  !
  subroutine hycom_na_calc(gridsz,pntlat,reflon,exhycom,eyhycom,dbgn)
    real,parameter:: e10=1.5707963268 
    real, intent(in) :: gridsz,pntlat,reflon
    integer, intent(in) :: dbgn
    real, dimension(:),intent(out) :: exhycom
    real, dimension(:),intent(out) :: eyhycom
    integer nxhycom,nyhycom,i
    real, dimension(:), allocatable ::  xhycom,yhycom
    !  
    nxhycom=size(exhycom)-1
    nyhycom=size(eyhycom)-1
    allocate(xhycom(nxhycom),yhycom(nyhycom))
    !
    !   calculate latitudes and longitudes of HYCOM  grid.
    !
    yhycom=(/((2.*atan(exp(gridsz*(i-pntlat)/radian))-e10)*radian,i=1,nyhycom)/)
    xhycom=(/(mod(gridsz*(i-1)+reflon+180.,360.)-180.,i=1,nxhycom)/)
    !
    !   Calculate grid edges ( coordinates are supposed to increase )
    ! 
    exhycom(1:nxhycom)=(xhycom(1:nxhycom)-0.5*gridsz)/radian
    exhycom(nxhycom+1)=(xhycom(nxhycom)+0.5*gridsz)/radian
    !
    eyhycom(1)=(yhycom(1)-0.5*(yhycom(2)-yhycom(1)))/radian
    eyhycom(2:nyhycom)=(/(0.5*(yhycom(i-1)+yhycom(i))/radian,i=2,nyhycom)/)
    eyhycom(nyhycom+1)=(yhycom(nyhycom)+0.5*(yhycom(nyhycom)-yhycom(nyhycom-1)))/radian
    !
    if (dbgn>=2) then
       write (*,'("yhycom ==========")')
       write (*,'(8F10.4)') (yhycom(i),i=1,nyhycom)
       write (*,'("xhycom ==========")')
       write (*,'(1X,I5,F10.4)') (i,xhycom(i),i=1,nxhycom)
       write (*,'("eyhycom ==========")')
       write (*,'(1X,I5,2F10.4)') (i,eyhycom(i),eyhycom(i)*radian,i=1,nyhycom+1)
       write (*,'("exhycom ==========")')
       write (*,'(1X,I5,2F10.4)') (i,exhycom(i),exhycom(i)*radian,i=1,nxhycom+1)
    endif
  end subroutine hycom_na_calc
  !
  !========================================================================
  !
  subroutine hycom_na_read(anhycom,qxhycom,qyhycom,dbgn)
    integer, intent(in) :: dbgn
    real, dimension(:,:)  :: qxhycom
    real, dimension(:,:)  :: qyhycom
    real, dimension(:,:)  :: anhycom
    integer nxhycom,nyhycom,i,j
    real, dimension(:,:), allocatable ::  plon,plat
    real, dimension(:,:), allocatable ::  qlon,qlat
    integer, dimension(:,:), allocatable ::  ip
    real hmina,hmaxa,gridsz
    real fac
    !  
    nxhycom=size(qxhycom,dim=1)-1
    nyhycom=size(qxhycom,dim=2)-1
    write(*,*)' hycom_na_read: grid size = ',nxhycom,nyhycom
    allocate(ip(nxhycom,nyhycom),plon(nxhycom,nyhycom),plat(nxhycom,nyhycom))
    allocate(                    qlon(nxhycom,nyhycom),qlat(nxhycom,nyhycom))
    !
    !   read latitudes and longitudes of HYCOM
    !
    ip=0.
!!!   call zaiost 
    call zaiopf('regional.grid.a','old', 9)
    call zaiord(plon, ip,.false., hmina,hmaxa, 9)
    write(*,*) 'reading longitudes max min=',hmina,hmaxa
    call zaiord(plat, ip,.false., hmina,hmaxa, 9)
    write(*,*) 'reading latitudes max min=',hmina,hmaxa
    call zaiord(qlon, ip,.false., hmina,hmaxa, 9)
    write(*,*) 'reading q-longitudes max min=',hmina,hmaxa
    call zaiord(qlat, ip,.false., hmina,hmaxa, 9)
    write(*,*) 'reading q-latitudes max min=',hmina,hmaxa
    ! skip records until  angle is read
    do i=1,5
       call zaiord(anhycom, ip,.false., hmina,hmaxa, 9)
    enddo
    write(*,*) 'reading angle between x-axis and East max min=',hmina,hmaxa
    call zaiocl(9)

    ! range of longitude in the range of [-180,180]
    ! and set ang to radians
    fac=acos(-1.0)/180.0
    do j=1,nyhycom
       do i=1,nxhycom
          if( plon(i,j) > 180.0 ) plon(i,j)=plon(i,j)-360
          if( qlon(i,j) > 180.0 ) qlon(i,j)=qlon(i,j)-360
          anhycom(i,j)=anhycom(i,j)*fac
       enddo
    enddo
    !
    !   Calculate grid edges 
    ! 
    qyhycom(1:nxhycom,1:nyhycom)=qlat/radian
    qyhycom(nxhycom+1,2:nyhycom+1)=plat(nxhycom,1:nyhycom)/radian
    qyhycom(2:nxhycom+1,nyhycom+1)=plat(1:nxhycom,nyhycom)/radian
    !   corners
    !   not really needed
    qyhycom(1,nyhycom+1)=plat(1,nyhycom)/radian
    qyhycom(nxhycom+1,1)=plat(nxhycom,1)/radian
    !
    qxhycom(1:nxhycom,1:nyhycom)=qlon/radian
    qxhycom(nxhycom+1,2:nyhycom+1)=plon(nxhycom,1:nyhycom)/radian
    qxhycom(2:nxhycom+1,nyhycom+1)=plon(1:nxhycom,nyhycom)/radian
    !   corners
    !   not really needed
    qxhycom(1,nyhycom+1)=plon(1,nyhycom)/radian
    qxhycom(nxhycom+1,1)=plon(nxhycom,1)/radian
    !
    if (dbgn>=2) then
       write (*,'("plat ==========")')
       write (*,'(8F10.4)') (plat(1,i),i=1,nyhycom)
       write (*,'("plon ==========")')
       write (*,'(1X,I5,F10.4)') (i,plon(i,1),i=1,nxhycom)
       write (*,'("qyhycom ==========")')
       write (*,'(1X,I5,2F10.4)') (i,qyhycom(1,i),qyhycom(1,i)*radian,i=1,nyhycom+1,10)
       write (*,'("qxhycom ==========")')
       write (*,'(1X,I5,2F10.4)') (i,qxhycom(i,1),qxhycom(i,1)*radian,i=1,nxhycom+1,10)
    endif
  end subroutine hycom_na_read
  !
  !========================================================================
  !
  subroutine mrf_gaussian(exmrf,eymrf,edges,dbgn)
    real,parameter:: acon=180./3.14159265
    integer, intent(in) :: dbgn,edges
    real, dimension(:),intent(out) :: exmrf
    real, dimension(:),intent(out) :: eymrf
    real, dimension(:), allocatable :: xmrf,ymrf,cosc,gwt,sinc,colat,wos2
    integer :: nxmrf,nymrf,nxmrf2,nymrf2,i,nx,ny
    real :: dxmrf
    !
    nxmrf=size(exmrf)
    nymrf=size(eymrf)
    if(edges.eq.1) then
       nxmrf=nxmrf-1
       nymrf=nymrf-1
    endif
    !
    nxmrf2=nxmrf/2 ; nymrf2=nymrf/2 ; dxmrf=360./nxmrf
    !
    !   calculate latitudes and longitudes of MRF gaussian grid.
    !
    allocate (xmrf(nxmrf),ymrf(nymrf) &
         &    ,cosc(1:nymrf),gwt(1:nymrf),sinc(1:nymrf),colat(1:nymrf),wos2(1:nymrf))
    call lggaus(nymrf,cosc,gwt,sinc,colat,wos2)
    ymrf=(/(sign(1,nymrf2-i)*acos(sinc(i))*acon,i=1,nymrf)/)
    xmrf=(/((i-1.)*dxmrf,i=1,nxmrf)/)
    !
    !   Calculate MRF grid points used in interpolation
    !   edges=1 at edges; otherwise at center
    !
    !   step 1. reset origin to nxmrf2
    exmrf(1:nxmrf2)=(xmrf(nxmrf2+1:nxmrf)-360.0)/radian
    exmrf(nxmrf2+1:nxmrf)=xmrf(1:nxmrf2)/radian
    !   step 2  edges
    if(edges.eq.1) then
       exmrf(1:nxmrf)=exmrf(1:nxmrf)-0.5*dxmrf/radian
       exmrf(nxmrf+1)=exmrf(nxmrf)+dxmrf/radian
       !
       eymrf(1)=(ymrf(1)-0.5*(ymrf(2)-ymrf(1)))/radian
       eymrf(2:nymrf)=0.5*(ymrf(1:nymrf-1)+ymrf(2:nymrf))/radian
       eymrf(nymrf+1)=(ymrf(nymrf)+0.5*(ymrf(nymrf)-ymrf(nymrf-1)))/radian
    else
       eymrf=ymrf/radian
    endif
    !
    if (dbgn>=2) then
       ny=nymrf
       nx=nxmrf
       if(edges.eq.1) then
          ny=ny+1
          nx=nx+1
       endif
       write (*,'("ymrf ==========")')
       write (*,'(1X,I5,F10.4)') (i,ymrf(nymrf+1-i),i=1,nymrf)
       write (*,'("xmrf ==========")')
       write (*,'(1X,I5,F10.4)') (i,xmrf(i),i=1,nxmrf)
       write (*,'("eymrf ==========")')
       write (*,'(1X,I5,2F10.4)') (i,eymrf(i),eymrf(i)*radian,i=1,ny)
       write (*,'("exmrf ==========")')
       write (*,'(1X,I5,2F10.4)') (i,exmrf(i),exmrf(i)*radian,i=1,nx)
    end if
    !
  end subroutine mrf_gaussian
  !
  !========================================================================
  !
  subroutine lggaus( nlat, cosc, gwt, sinc, colat, wos2 )
    !   ********** warning *************
    !   this routine may not converge using 32-bit arithmetic
    !
    !   routines from amy solomon, 28 jan 1991.
    !
    !    lggaus finds the gaussian latitudes by finding the roots of the
    !    ordinary legendre polynomial of degree nlat using newton's
    !    iteration method.
    !
    !    on entry:
    !       nlat - the number of latitudes (degree of the polynomial)
    !  
    !    on exit: for each gaussian latitude
    !       cosc   - cos(colatitude) or sin(latitude)
    !       gwt    - the gaussian weights
    !       sinc   - sin(colatitude) or cos(latitude)
    !       colat  - the colatitudes in radians
    !       wos2   - gaussian weight over sin**2(colatitude)
    !    also
    !       xlim   -convergence criterion for iteration of cos latitude
    !
    !
    !-----------------------------------------------------------------------
    !
    real:: cosc(nlat),gwt(nlat),sinc(nlat),colat(nlat),wos2(nlat) & 
         &   ,fi,fi1,a,b,c,d,g,gm,gp,gt,delta
    !irivin: to speed up things
    real, parameter :: pi = 3.141592653589793,xlim  = 1.0e-5
    !real, parameter :: pi = 3.141592653589793,xlim  = 1.0e-7
    integer :: nlat,nzero,nother,i,j
    !
    !      -the number of zeros between pole and equator
    nzero = nlat/2
    nother= nlat-nzero+1
    !
    !      -set first guess for cos(colat)      
    do i=1,nzero
       cosc(i) = sin( (i-0.5)*pi/nlat + pi*0.5 )
    enddo
    !
    !      -constants for determining the derivative of the polynomial
    fi  = nlat
    fi1 = fi+1.0
    a   = fi*fi1 / sqrt(4.0*fi1*fi1-1.0)
    b   = fi1*fi / sqrt(4.0*fi*fi-1.0)
    !
    !    -loop over latitudes, iterating the search for each root
    do i=1,nzero
       j=0
       !
       !         -determine the value of the ordinary legendre polynomial for
       !         -the current guess root
30     call lgord( g, cosc(i), nlat )
       !
       !         -determine the derivative of the polynomial at this point
       call lgord( gm, cosc(i), nlat-1 )
       call lgord( gp, cosc(i), nlat+1 )
       gt = (cosc(i)*cosc(i)-1.0) / (a*gp-b*gm)
       !
       !         -update the estimate of the root
       delta   = g*gt
       cosc(i) = cosc(i) - delta
       !
       !         -if convergence criterion has not been met, keep trying
       j = j+1
       if( abs(delta).gt.xlim ) go to 30
       !     print*,' lat no.',i,j,' iterations'
       !
       !         -determine the gaussian weights
       c      = 2.0 *( 1.0-cosc(i)*cosc(i) )
       call lgord( d, cosc(i), nlat-1 )
       d      = d*d*fi*fi
       gwt(i) = c *( fi-0.5 ) / d
    enddo
    !
    !      -determine the colatitudes and sin(colat) and weights over sin**2
    colat(1:nzero)= acos(cosc(1:nzero))
    sinc(1:nzero) = sin(colat(1:nzero))
    wos2(1:nzero) = gwt(1:nzero) /( sinc(1:nzero)*sinc(1:nzero) )
    !
    !      -if nlat is odd, set values at the equator
    if( mod(nlat,2) .ne. 0 ) then
       i       = nzero+1
       cosc(i) = 0.0
       c       = 2.0
       call lgord( d, cosc(i), nlat-1 )
       d       = d*d*fi*fi
       gwt(i)  = c *( fi-0.5 ) / d
       colat(i)= pi*0.5
       sinc(i) = 1.0
       wos2(i) = gwt(i)
    end if
    !
    !      -determine the southern hemisphere values by symmetry
    do i=nlat-nzero+1,nlat
       cosc(i) =-cosc(nlat+1-i)
       gwt(i)  = gwt(nlat+1-i)
       colat(i)= pi-colat(nlat+1-i)
       sinc(i) = sinc(nlat+1-i)
       wos2(i) = wos2(nlat+1-i)
    end do
    return
  end subroutine lggaus
  !
  !========================================================================
  !
  subroutine lgord( f, cosc, n )
    ! 
    !    lgord calculates the value of an ordinary legendre polynomial at a
    !    latitude.
    !
    !    on entry:
    !       cosc - cos(colatitude)
    !       n      - the degree of the polynomial
    !
    !    on exit:
    !       f      - the value of the legendre polynomial of degree n at
    !                latitude asin(cosc)
    !
    !------------------------------------------------------------------------
    real :: f,cosc,colat,c1,fn,ang,s1,c4,a,b,fk
    integer :: n,k
    !  
    !      -determine the colatitude
    colat = acos(cosc)
    !
    c1 = sqrt(2.0)
    do k=1,n
       c1 = c1 * sqrt( 1.0 - 1.0/(4*k*k) )
    end do
    !
    fn = n
    ang= fn * colat
    s1 = 0.0
    c4 = 1.0
    a  =-1.0
    b  = 0.0
    do k=0,n,2
       if (k.eq.n) c4 = 0.5 * c4
       s1 = s1 + c4 * cos(ang)
       a  = a + 2.0
       b  = b + 1.0
       fk = k
       ang= colat * (fn-fk-2.0)
       c4 = ( a * (fn-b+1.0) / ( b * (fn+fn-a) ) ) * c4
    end do
    f = s1 * c1
    !
    return
  end subroutine lgord
  !
  !========================================================================
  !
  subroutine ismus(mskout)
    real, dimension(:,:) :: mskout
    integer :: i,j,m,n,k,num,mm,nn,iu=18
    real :: a,b
    character*30 as,bs,cs
    logical ex
    n=size(mskout,2)
    m=size(mskout,1)
    write(as,*)m
    write(bs,*)n
    cs='ismus_msk'//trim(adjustl(as))//'x'//trim(adjustl(bs))//'.dat'
    inquire(file=trim(cs),exist=ex)
    if(.not.ex) then
       print *,'ismus: warning: mask for the ismus correction is not found' &
            &          ,'(looked for the file '//trim(cs)//')'

       stop
    endif
    print *,'ismus: mask for the ismus correction is '//cs
    open(iu,file=trim(cs),form="formatted")
    read(iu,*)a,b
    num=int(a)
    if (num>=0) then
       read(iu,*)a,b
       mm=int(a)
       nn=int(b)
       if(mm.ne.m .or. nn.ne.n) then
          print *,' ismus: Error in ismus'
          print *,'ismus: m,n,mm,nn =',m,n,mm,nn
          stop
       endif
       do k=1,num
          read(iu,*)a,b
          i=int(a)
          j=int(b)
          if(i.lt.1.or.i.gt.m.or.j.lt.1.or.j.gt.n) then
             print *,'ismus:  Error in ismus '
             print *,'ismus: i,j,k=',i,j,k
             stop
          endif
          mskout(i,j)=0.  ! MRF convention: 1-land, 0-ocean
          print *,'ismus:  MRF mask is corrected for i,j=',i,j
       enddo
    else
       print *,' ismus: Error in ismus'
       stop
    endif
    close(iu)
  end subroutine ismus
  !
  !========================================================================
  !
  subroutine mask_mrf_1(lu,name,kpds,mskfrac,nextrap_max,msk &
,imsk_hycom,msk_tmp,nextrap,mapflg,exhycom2d,eyhycom2d,global)
    !
    !   Establish MRF mask (land=0,sea=1)
    !
    ! INPUT:
    ! lu          is init number for atmospheric GRIB file with land/sea mask
    ! name        is name of the atmospheric GRIB file with land/sea mask
    ! mskfrac     is a number which ....
    ! nextrap_max is maximum namber of inerations in mask extrapolation procedure
    ! kpds        are pds(5,6,7) numbers for LAND in atmospheric GRIB file.
    ! imsk_hycom  is land/sea mask on HYCOM grid
    ! mapflag     is the flag defining the HYCOM grid type.
    ! exhycom2d
    ! eyhycom2d
    ! global      (optional)
    !
    ! OUTPUT:
    ! msk
    ! msk_tmp
    ! nextrap is an actual number of iteration used in mask extrapolation procedure.
    !
    character*(*), intent(in) :: name
    integer, intent(in) :: lu,nextrap_max
    real, intent(in) :: mskfrac
    integer, dimension(:,:), intent(in) :: imsk_hycom
    integer, dimension(:), intent(in)  :: kpds
    real, dimension(:,:), intent(out) :: msk,msk_tmp
    real, dimension(size(msk,1),size(msk,2)) :: flx
    real, dimension(size(imsk_hycom,1),size(imsk_hycom,2)) :: msk_out
    real, dimension(:,:) :: exhycom2d,eyhycom2d
    integer, intent (out) :: nextrap
    integer, intent (in) :: mapflg
    logical, optional, intent (in) :: global
    integer :: i,j,n,nxmrf,nymrf,nxhycom,nyhycom,nxmrf2,nymrf2
    character*30 as,bs,cs
    logical ::   ex,glo=.false.
    integer :: idum
    !
    if (present(global)) glo=global
    nxmrf=size(msk,1)
    nymrf=size(msk,2)
    nxhycom=size(imsk_hycom,1)
    nyhycom=size(imsk_hycom,2)
    write(*,*)size(exhycom2d,dim=1),size(exhycom2d,dim=2),' exhycom2d size'
    write(*,*)size(eyhycom2d,dim=1),size(eyhycom2d,dim=2),' eyhycom2d size'
    nxmrf2=nxmrf/2 ; nymrf2=nymrf/2 
    call rdgrib(lu,trim(name),flx,kpds(:),.true.)  ! LAND
    ! dbgz IMPORTANT !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    ! flx=1 ! all is sea
    !
    !   Fix ithsmus problem.
    !
    ! ilya; ismus correction is ready for this grid only
    if (mapflg==mapflg_ort)  call ismus(flx)
    !
    !   Shift mask following shift of longitude grid
    !
    msk_tmp(1:nxmrf2      ,:)=flx(nxmrf2+1:nxmrf,:)
    msk_tmp(nxmrf2+1:nxmrf,:)=flx(1:nxmrf2      ,:)
    msk=abs(1.-msk_tmp(:,:))                          ! land =0 ; sea =1
    if (glo) then
       call global_extend(msk)
       call global_extend(msk_tmp)
    endif
    !
    !   If required, determine number of iterations needed to extrapolate field in MRF 
    !   grid to cover ocean region 
    !
    msk_tmp=msk 
    iterx: do n=1,nextrap_max
       call extend_fld(msk_tmp,flx(:,:),msk_tmp,flx(:,:))
       call horiz_intp(exhycom2d,eyhycom2d,msk_tmp,msk_out,idum)
       loopj: do j=1,nyhycom
          loopi: do i=1,nxhycom
             if(imsk_hycom(i,j)==1 .and. msk_out(i,j)<mskfrac) then
                write(*,*)'iterations on land/sea mask: i,j,msk_out,imsk_hycom' &
                     ,j,msk_out(i,j),imsk_hycom(i,j)
                exit loopj 
             end if
          end do loopi
       end do loopj
       if (j>nyhycom .and.  i>nxhycom) exit iterx
    end do iterx
    nextrap=n+1
    write(*,*)'+++++ # of interations for land/sea mask extrapolation is nextrap=',nextrap
  end subroutine mask_mrf_1
  !
  !========================================================================
  !
  subroutine mask_mrf_2(nextrap,mskin,flxin,mskout,flxout)
    !
    !       Extrapolate field in MRF grid to cover all ocean in HYCOM grid
    !
    integer, intent(in) :: nextrap
    real, dimension(:,:), intent(in) :: mskin,flxin
    real, dimension(:,:), intent(out) :: flxout,mskout
    integer :: n
    mskout=mskin
    flxout=flxin
    do n=1,nextrap
       call extend_fld(mskout,flxout,mskout,flxout)
    end do
  end subroutine mask_mrf_2
  !
  !========================================================================
  !
  subroutine rd_hycom_grid_params(idm,jdm,mapflg,ex)
    !
    !   read HYCOM grid parameters 
    !
    integer, intent(out) :: idm,jdm,mapflg
    logical, intent(out)  :: ex
    character*80 :: cline
    idm=-1 ; jdm=-1; mapflg=-1
    inquire(file='regional.grid.a',exist=ex)
    if(.not.ex) return
    inquire(file='regional.grid.b',exist=ex)
    if(.not.ex) return
    open(8, file='regional.grid.b',status='old' ,action='read')
    read(8,'(a)') cline ; read (cline,*) idm
    read(8,'(a)') cline ; read (cline,*) jdm
    read(8,'(a)') cline ; read (cline,*) mapflg
    if (mapflg /= mapflg_mer .and. mapflg /= mapflg_ort .and.  mapflg /= mapflg_tripol ) then 
       print *, 'ERROR: Wrong map flag in regional.grid.b, mapflg=',mapflg
       stop
    endif
    print *,'HYCOM GRID parameters from regional.grid.b: mapflg,idm,jdm=', mapflg,idm,jdm
    close(8)    
  end subroutine rd_hycom_grid_params
  !
  !========================================================================
  !
  subroutine extend_fld(msk_in,fld_in,msk_out,fld_out)
    !
    ! Extrapolate field fld_in under the mask msk_in.
    ! The zero order extrapolated field fld_out, is valid for the extended mask 
    ! msk_out.
    !
    ! Convention: invalid field value if mask has value 0, otherwise is valid.
    !
    ! msk_in     input real mxn array mask
    ! fld_in     input real mxn array    field
    ! msk_out    output real mxn array extended mask
    ! fld_out    output real mxn array    extended field
    !
    real, dimension(:,:), intent(in) ::  msk_in
    real, dimension(:,:), intent(out) :: msk_out
    real, dimension(:,:), intent(in)    ::  fld_in
    real, dimension(:,:), intent(out)    :: fld_out
    integer :: i,j,i1,j1,m,n,imsk_in(size(msk_in,1),size(msk_in,2))
    real :: val, count, corner

    m=size(msk_in,1)
    n=size(msk_in,2)
    corner=1.0/sqrt(2.0)
    !
    ! -- copy field and mask
    !
    fld_out=fld_in
    msk_out=msk_in
    imsk_in=int(msk_in)
    !
    ! -- update under the msk_in using values of fld_in at eight
    ! -- neighbor points if they are valid.
    ! -- if the update is possible, set msk_out to valid and fld_out
    ! -- to the average of the valid fld_in values.
    !
    do j=1,n
       do i=1,m
          if( imsk_in(i,j).eq.0 ) then
             val=0.0
             count=0.0
             if(i.gt.1 ) then
                i1=i-1
                j1=j
                if ( imsk_in(i1,j1).eq.1) then
                   val=val+fld_in(i1,j1)
                   count=count+1.0
                endif
             endif
             !
             if(i.lt.m ) then
                i1=i+1
                j1=j
                if ( imsk_in(i1,j1).eq.1) then
                   val=val+fld_in(i1,j1)
                   count=count+1.0
                endif
             endif
             if(j.gt.1 ) then
                i1=i
                j1=j-1
                if ( imsk_in(i1,j1).eq.1) then
                   val=val+fld_in(i1,j1)
                   count=count+1.0
                endif
             endif
             !
             if(j.lt.n ) then
                i1=i
                j1=j+1
                if ( imsk_in(i1,j1).eq.1) then
                   val=val+fld_in(i1,j1)
                   count=count+1.0
                endif
             endif
             !
             if(i.gt.1.and.j.lt.n ) then
                i1=i-1
                j1=j+1
                if ( imsk_in(i1,j1).eq.1) then
                   val=val+fld_in(i1,j1)*corner
                   count=count+corner
                endif
             endif
             !
             if(i.lt.m.and.j.gt.1 ) then
                i1=i+1
                j1=j-1
                if ( imsk_in(i1,j1).eq.1) then
                   val=val+fld_in(i1,j1)*corner
                   count=count+corner
                endif
             endif
             if(j.gt.1.and.i.gt.1 ) then
                i1=i-1
                j1=j-1
                if ( imsk_in(i1,j1).eq.1) then
                   val=val+fld_in(i1,j1)*corner
                   count=count+corner
                endif
             endif
             !
             if(j.lt.n.and.i.lt.m ) then
                i1=i+1
                j1=j+1
                if ( imsk_in(i1,j1).eq.1) then
                   val=val+fld_in(i1,j1)*corner
                   count=count+corner
                endif
             endif
             if(count.gt.0.0) then
                fld_out(i,j)=val/count
                msk_out(i,j)=1.
             endif
          endif
       enddo
    enddo

    return
  end subroutine extend_fld
  !
  !========================================================================
  !
  subroutine horiz_intp_init(exmrf,eymrf,qx,qy,ex,ey,iu,global)
    implicit none
    real, dimension(:,:),intent(in) ::  qx,qy
    real, dimension(:),intent(in) ::  exmrf,eymrf
    real, dimension(:,:),intent(out) :: ex,ey
    integer, intent(in):: iu
    logical, optional, intent(in) :: global
    integer :: i,j,idm,jdm
    integer :: id,jd,ip,jp,ic,ipmax,jpmax,ipmin,jpmin
    real :: x,y
    logical :: glo=.false.
    !
    if (present(global)) glo=global
    id=size(exmrf)
    jd=size(eymrf)
    idm=size(qx,dim=1)
    jdm=size(qx,dim=2)
    !
    ! --- check that ocean grid is properly covered by mrf grid
    !
    ic=0
    if( MinVal(exmrf) > MinVal(qx) ) then
       ic = ic + 1
       write(iu,*)'min of exmrf ', MinVal(exmrf),' >  min of lon target grid ',MinVal(qx)
    endif
    if( MinVal(eymrf)  > MinVal(qy) ) then
       ic = ic + 1
       write(iu,*)'min of eymrf ', MinVal(eymrf),' >  min of lat target grid ',MinVal(qy)
    endif
    if( MaxVal(exmrf) < MaxVal(qx) ) then
       ic = ic + 1
       write(iu,*)'max of exmrf ', MaxVal(exmrf),' <  max of lon target grid ',MaxVal(qx)
    endif
    if( MaxVal(eymrf) < MaxVal(qy) ) then
       ic = ic + 1
       write(iu,*)'max of eymrf ', MaxVal(eymrf),' >  max of lat target grid ',MaxVal(qy)
    endif
    if(ic > 0) then
       write(iu,*)' emrf grid does not contain target grid.'
       call flush(iu)
       stop
    endif
    !
    if (glo) then
       ipmin=1
       jpmin=1
       ipmax=id+1
       jpmax=jd+1
    else
       ipmin=1
       jpmin=1
       ipmax=id
       jpmax=jd
    endif
    do j=1,jdm
       do i=1,idm
          ! exmrf is in  increasing order
          x=qx(i,j)
          ip=ipmin
          do while(x > exmrf(ip) .and. ip < ipmax )
             ip=ip+1
          enddo
          ex(i,j)=ip-1.0+(x-exmrf(ip-1))/(exmrf(ip)-exmrf(ip-1))
          ! eymrf is in decreasing order
          y=qy(i,j)
          ip=jpmin
          do while(y < eymrf(ip) .and. ip < jpmax)
             ip=ip+1
          enddo
          ey(i,j)=ip-1.0+(y-eymrf(ip-1))/(eymrf(ip)-eymrf(ip-1))
       enddo
    enddo
    return
  end subroutine horiz_intp_init
  !
  !========================================================================
  !
  subroutine horiz_intp_old(win,wout,xout,yout)
    implicit none
    real, dimension(:,:),intent(in) ::  win, xout,yout
    real, dimension(:,:),intent(out) :: wout
    integer i,j,idmp1,jdmp1,k
    integer ii,jj
    real x,y,z1,z2,z3,z4
    !
    idmp1=size(wout,dim=1)
    jdmp1=size(wout,dim=2)

    do j=1,jdmp1-1
       do i=1,idmp1-1
          x=xout(i,j)
          y=yout(i,j)
          ii=int(x)
          x=x-ii
          jj=int(y)
          y=y-jj
          z1=(win(ii,jj)*(1.0-x)+win(ii+1,jj)*x)*(1.-y)     &
               + (win(ii,jj+1)*(1.0-x)+win(ii+1,jj+1)*x)*y
          !
          x=xout(i+1,j)
          y=yout(i+1,j)
          ii=int(x)
          x=x-ii
          jj=int(y)
          y=y-jj
          z2=(win(ii,jj)*(1.0-x)+win(ii+1,jj)*x)*(1.-y)     &
               +(win(ii,jj+1)*(1.0-x)+win(ii+1,jj+1)*x)*y
          !
          x=xout(i+1,j+1)
          y=yout(i+1,j+1)
          ii=int(x)
          x=x-ii
          jj=int(y)
          y=y-jj
          z3=(win(ii,jj)*(1.0-x)+win(ii+1,jj)*x)*(1.-y)     &
               +(win(ii,jj+1)*(1.0-x)+win(ii+1,jj+1)*x)*y
          !
          x=xout(i,j+1)
          y=yout(i,j+1)
          ii=int(x)
          x=x-ii
          jj=int(y)
          y=y-jj
          z4=(win(ii,jj)*(1.0-x)+win(ii+1,jj)*x)*(1.-y)     &
               +(win(ii,jj+1)*(1.0-x)+win(ii+1,jj+1)*x)*y
          !
          wout(i,j)=0.25*(z1+z2+z3+z4)
       enddo
    enddo
    return
  end subroutine  horiz_intp_old
  !
  !========================================================================
  !
  subroutine horiz_intp_(win,wout,xout,yout)
    implicit none
    real, dimension(:,:),intent(in) ::  win, xout,yout
    real, dimension(:,:),intent(out) :: wout
    integer :: i,j,idmp1,jdmp1,minus
    real,dimension(4) :: z
    !
    idmp1=size(wout,dim=1)
    jdmp1=size(wout,dim=2)
    do j=1,jdmp1-1
       do i=1,idmp1-1
          call edge_interp( win ,xout(i,j)     ,yout(i,j)      ,z(1) )
          call edge_interp( win ,xout(i+1,j)   ,yout(i+1,j)    ,z(2) )
          call edge_interp( win ,xout(i+1,j+1) ,yout(i+1,j+1)  ,z(3) )
          call edge_interp( win ,xout(i,j+1)   ,yout(i,j+1)    ,z(4) )
          wout(i,j)=0.25*sum(z)
       enddo
    enddo
    return
  end subroutine  horiz_intp_
  !
  !========================================================================
  !
  subroutine  edge_interp(win,xin,yin,z)
    real, dimension(:,:),intent(in) ::  win
    real, intent(in):: xin,yin
    real, intent(out):: z
    real :: x,y
    integer :: ii,jj
    !
    ii=int(xin)
    x=xin-ii
    jj=int(yin)
    y=yin-jj
    z=(win(ii,jj)*(1.0-x)+win(ii+1,jj)*x)*(1.-y)     &
         +(win(ii,jj+1)*(1.0-x)+win(ii+1,jj+1)*x)*y
  end subroutine  edge_interp
  !
  !========================================================================
  !
  subroutine  horiz_intp_msk(xout,yout,mskin,mskout,iu)
    implicit none
    real, dimension(:,:),intent(in) ::  xout,yout,mskin
    real, dimension(:,:),intent(out) :: mskout
    integer, intent(in) :: iu
    integer i,j,idmp1,jdmp1
    integer ii,jj
    real x,y
    !
    idmp1=size(xout,dim=1)
    jdmp1=size(xout,dim=2)
    do j=1,jdmp1-1
       do i=1,idmp1-1
          mskout(i,j)=0.0
          x=xout(i,j)
          y=yout(i,j)
          ii=int(x)
          jj=int(y)
          if(mskin(ii,jj).eq.1.0) then
             mskout(i,j)=mskout(i,j)+0.25
          endif
          x=xout(i+1,j)
          y=yout(i+1,j)
          ii=int(x)
          jj=int(y)
          !
          if(mskin(ii,jj).eq.1.0) then
             mskout(i,j)=mskout(i,j)+0.25
          endif
          !
          x=xout(i+1,j+1)
          y=yout(i+1,j+1)
          ii=int(x)
          jj=int(y)
          if(mskin(ii,jj).eq.1.0) then
             mskout(i,j)=mskout(i,j)+0.25
          endif
          !
          x=xout(i,j+1)
          y=yout(i,j+1)
          ii=int(x)
          jj=int(y)
          if(mskin(ii,jj).eq.1.0) then
             mskout(i,j)=mskout(i,j)+0.25
          endif
          !
       enddo
    enddo
    return
  end subroutine  horiz_intp_msk
  !
  !========================================================================
  !
  subroutine global_extend_latlon_1d(x,y)
    real, dimension(:), intent(inout):: x,y
    integer :: nx,ny
    real :: dx
    ! integer :: i ! dbgzp
    nx=size(x)
    ny=size(y)
    dx=x(3)-x(2)
    x(1)=x(2)-dx
    x(nx)=x(nx-1)+dx
    y(1)=90.0/radian
    y(ny)=-90.0/radian
    ! print *, 'global_extend: ny=',ny !dbgzp
    ! print *, 'global_extend: x: min,max=',minval(x)*radian,maxval(x)*radian !dbgzp
    ! print *, 'global_extend: y: min,max=',minval(y)*radian,maxval(y)*radian !dbgzp
    ! write(*,'(a,i5,f13.4)') ('global_extend: y: ',i,y(i)*radian,i=1,ny) ! dbgzp
  end subroutine global_extend_latlon_1d
  !
  !========================================================================
  !
  subroutine global_extend_mask(msk)
    integer, dimension(:,:), intent(inout):: msk
    integer :: nx,ny
    nx=size(msk,dim=1)
    ny=size(msk,dim=2)
    msk(1,:)=msk(nx-1,:)
    msk(nx,:)=msk(2,:)
    msk(:,1)=0 ! Ocean at Nothern Pole
    msk(:,ny)=1 ! Land at Southern Pole 
  end subroutine global_extend_mask
  !
  !========================================================================
  !
  subroutine global_extend_field_2d(fld)
    real, dimension(:,:), intent(inout):: fld
    integer :: nx,ny
    nx=size(fld,dim=1)
    ny=size(fld,dim=2)
    fld(1,:)=fld(nx-1,:)
    fld(nx,:)=fld(2,:)
    fld(:,1)=sum(fld(2:nx-1,2))/nx
    fld(:,ny)=sum(fld(2:nx-1,ny-1))/nx
  end subroutine global_extend_field_2d
  !
  !========================================================================
  !
  subroutine global_extend_field_3d(fld)
    real, dimension(:,:,:), intent(inout):: fld
    integer :: nx,ny,nk,i
    nx=size(fld,dim=1)
    ny=size(fld,dim=2)
    nk=size(fld,dim=3)
    do i=1,nk
      call global_extend_field_2d(fld(:,:,nk))
    enddo
  end subroutine global_extend_field_3d
  !
  !========================================================================
  !
end module mod_geom





