!Debugging module: contains routines to write out data fields quickly
!that can be read into Matlab
module xls
contains
    subroutine write_xls(fname, data)
      use parallel
        character(len=*) :: fname
        double precision data(:,:)
!!$        integer :: i , j
!!$        open(11, file=fname)
!!$
!!$        do i = 1, size(data, 2)
!!$            write(11, *)(data(j,i),j=1,size(data,1))
!!$        end do
!!$
!!$        close(11)
        call distributed_print(fname,data)
    end subroutine

    subroutine write_xls_int(fname, data)
      use parallel
        character(len=*) :: fname
        integer data(:,:)
!!$        integer :: i , j
!!$        open(11, file=fname)
!!$
!!$        do i = 1, size(data, 2)
!!$            write(11, *)(data(j,i),j=1,size(data,1))
!!$        end do
!!$
!!$        close(11)
        call distributed_print(fname,data)
    end subroutine



    subroutine write_xls_3d(fname, data)
      use parallel
        character(len=*) :: fname
        double precision data(:,:,:)
!!$        integer :: i , j, k
!!$        open(11, file=fname)
!!$        do k = 1, size(data, 1)
!!$            do i = 1, size(data, 3)
!!$                write(11, *)(data(k,j,i),j=1,size(data,2))
!!$            end do
!!$        end do
!!$        close(11)
        call distributed_print(fname,data)
    end subroutine

    subroutine write_sparse_system(name, ia, ja, a,nelt)
      use parallel
        double precision, dimension(:) :: a
        integer, dimension(:) :: ia, ja
        integer :: nelt, i
        character(len=*) :: name

        call not_parallel(__FILE__,__LINE__)
        open(11, file=name)
        write(11,*)(ia(i),i=1,nelt)
        write(11,*)(ja(i),i=1,nelt)
        write(11,*)(a(i),i=1,nelt)
        close(11)
    end subroutine
end module xls
