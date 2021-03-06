module glimmer_sparse_trilinos
    !*FD This module builds on the glimmer_sparse module to provide an easy
    !*FD interface to Trilinos.  
    
    use glimmer_sparse_type
    use glimmer_global, only: dp
    use glimmer_log

    implicit none

    type trilinos_solver_workspace
        !*FD This type contains any working memory needed for the trilinos solver.

        !TRILINOS status arrays
        real(kind=dp),dimension(20) :: control
        real(kind=dp),dimension(90) :: info

        !TRILINOS pointers
        integer :: numeric
        integer :: symbolic

        logical :: alloc
    end type trilinos_solver_workspace

    type trilinos_solver_options
        !*FD This type holds options that are passed to the trilinos solver, such
        !*FD as preconditioner type, error tolerances, etc.  At a minimum, it
        !*FD must define the tolerance and maxiters field, as these will be
        !*FD common to any iterative trilinos linear solver.  Other options
        !*FD can be defined as necessary.
        !*FD
        !*FD Design note: the options are seperated from the workspace because
        !*FD one set of options could apply to multiple matrices, and the
        !*FD lifecycles for each could be different (a workspace need only
        !*FD exist as long as the matrix does, the options could persist
        !*FD throughout the entire program)
        real(kind=dp) :: tolerance !*FD Error tolerance
        integer :: maxiters !*FD Max iterations before giving up
        logical :: use_iterative_refinement
    end type trilinos_solver_options

contains
    subroutine check_trilinos()
#ifndef TRILINOS
      call write_log('Trilinos functionality was called, but the code'// &
                     ' is not compiled with -DTRILINOS ',GM_FATAL);
#endif
    end subroutine

    subroutine trilinos_default_options(opt)
        !*FD Populates a trilinos_solver_options (defined above) with default
        !*FD options.  This is necessary because different solvers may define
        !*FD different options beyond the required fields defined above.
        !*FD Filling them in this function allows client code to pick "good"
        !*FD values in a generic way.
        type(trilinos_solver_options), intent(out) :: opt
        opt%tolerance  = 1e-5
        opt%maxiters = 2000
        opt%use_iterative_refinement = .true.
        call check_trilinos()
    end subroutine trilinos_default_options

    subroutine trilinos_allocate_workspace(matrix, options, workspace, max_nonzeros_arg)
        !*FD Allocate solver workspace.  This needs to be done once
        !*FD (when the maximum number of nonzero entries is first known)
        
        !*FD Note that the max_nonzeros argument must be optional, and if
        !*FD the current number of nonzeroes must be used.
        type(sparse_matrix_type) :: matrix
        type(trilinos_solver_options) :: options
        type(trilinos_solver_workspace) :: workspace
        integer, optional :: max_nonzeros_arg
    
        !*FD TRILINOS internally allocates all solver memory when we perform
        !*FD factorization.  Thus, the only thing we'll do here is to initialize
        !*FD the workspace
        workspace%alloc = .false.
    
        call check_trilinos()
    end subroutine trilinos_allocate_workspace

    subroutine trilinos_solver_preprocess(matrix, options, workspace)
        !*FD Performs any preprocessing needed to be performed on the trilinos
        !*FD matrix.  Workspace must have already been allocated. 
        !*FD This function should be safe to call more than once.
        !*FD 
        !*FD It is an error to call this function on a workspace without already
        !*FD allocated memory.
        !*FD
        !*FD In general trilinos_allocate_workspace should perform any actions
        !*FD that depend on the *size* of the trilinos matrix, and
        !*FD sprase_solver_preprocess should perform any actions that depend
        !*FD upon the *contents* of the trilinos matrix.
        type(sparse_matrix_type) :: matrix
        type(trilinos_solver_options) :: options
        type(trilinos_solver_workspace) :: workspace
        integer :: i, max
        call check_trilinos()

        !Check if we have previously allocated TRILINOS storage
        if (workspace%alloc) then
            call trilinos_destroy_workspace(matrix, options, workspace)
        end if

        matrix%row = matrix%row - 1
        matrix%col = matrix%col - 1
    end subroutine trilinos_solver_preprocess

    function trilinos_solve(matrix, rhs, solution, options, workspace,err,niters, verbose)
        !*FD Solves the trilinos linear system, and reports status information.
        !*FD This function returns an error code that should be zero if the
        !*FD call succeeded and nonzero if it failed.  No additional error codes
        !*FD are defined.  Although this function reports back the final error
        !*FD and the number of iterations needed to converge, these should *not*
        !*FD be relied upon as not every trilinos linear solver may report them.
        type(sparse_matrix_type), intent(inout) :: matrix 
        !*FD Sparse matrix to solve.  This is inout because the trilinos solver
        !*FD may have to do some re-arranging of the matrix.
        
        real(kind=dp), dimension(:), intent(in) :: rhs 
        !*FD Right hand side of the solution vector
        
        real(kind=dp), dimension(:), intent(inout) :: solution 
        !*FD Solution vector, containing an initial guess.

        type(trilinos_solver_options), intent(in) :: options
        !*FD Options such as convergence criteria
        
        type(trilinos_solver_workspace), intent(inout) :: workspace
        !*FD Internal solver workspace
        
        real(kind=dp), intent(out) :: err
        !*FD Final solution error
        
        integer, intent(out) :: niters
        !*FD Number of iterations required to reach the solution

        logical, optional, intent(in) :: verbose
        !*FD If present and true, this argument may cause diagnostic information
        !*FD to be printed by the solver (not every solver may implement this).
        
        integer :: trilinos_solve

        integer :: iunit !Unit number to print verbose output to (6=stdout, 0=no output)
        integer :: isym !Whether matrix is symmetric
        integer :: sys,i

        sys=0
        call solvetriadmatrixwithtrilinos (matrix%nonzeros, matrix%order, &
                    matrix%row, matrix%col, matrix%val, rhs, solution)
       
        call check_trilinos()
        trilinos_solve = 0; !workspace%info(1) 
    
        err = 0
        niters = 0
    end function trilinos_solve

    subroutine trilinos_solver_postprocess(matrix, options, workspace)
        type(sparse_matrix_type) :: matrix
        type(trilinos_solver_options) :: options
        type(trilinos_solver_workspace) :: workspace
        matrix%row = matrix%row + 1
        matrix%col = matrix%col + 1
    end subroutine

    subroutine trilinos_destroy_workspace(matrix, options, workspace)
        !*FD Deallocates all working memory for the trilinos linear solver.
        !*FD This need *not* be safe to call of an unallocated workspace
        !*FD No trilinos solver should call this automatically.
        type(sparse_matrix_type) :: matrix
        type(trilinos_solver_options) :: options
        type(trilinos_solver_workspace) :: workspace
        !Deallocate all of the working memory
        !Free the Umfpack symbolic analysis
        workspace%alloc = .false.
    end subroutine trilinos_destroy_workspace

    subroutine trilinos_interpret_error(error_code, error_string)
        !*FD takes an error code output from trilinos_solve and interprets it.
        !*FD error_string must be an optional argument.
        !*FD If it is not provided, the error is printed to standard out
        !*FD instead of being put in the string
        integer :: error_code
        character(*), optional, intent(out) :: error_string
        character(256) :: tmp_error_string
        
        select case (error_code)
            case (0)
                tmp_error_string="All went well"
            case (1)
                tmp_error_string="Matrix is singular (This is a warning, but we barf anyway if it happens)"
            case (-1)
                tmp_error_string="Out of memory"
            case (-3)
                tmp_error_string="Invalid Numeric object"
            case (-4)
                tmp_error_string="Invalid Symbolic object" 
            case (-5)
                tmp_error_string="Argument missing"
            case (-6)
                tmp_error_string="n (matrix order given) is nonpositive"
            case (-8)
                tmp_error_string="Invalid trilinos matrix format"
            case (-11)
                tmp_error_string="Different pattern"
            case(-13)
                tmp_error_string="Invalid system"
            case(-15)
                tmp_error_string="Invalid permutation"
            case(-911)
                tmp_error_string="Internal error, contact Trilinos developers"
            case(-17)
                tmp_error_string="File IO error"
            case default
                tmp_error_string="Unrecognized error code"
        end select


        if (present(error_string)) then
            error_string = tmp_error_string
        else
            write(*,*) tmp_error_string
        endif
    end subroutine trilinos_interpret_error

!! AGS: The following are dummy implementations of the
!! C++ Trilinos interface functions in the src/cpp
!! directory. These empty functions allow the main
!! code in glam_strs2.F90 to be fre of "#ifdef TRILINOS"
!! lines all over the place. 
#ifndef TRILINOS
    subroutine dopartition(i,j)  !Dummy implementation of cpp function
        integer :: i,j
        call check_trilinos()
    end subroutine dopartition

    subroutine getpartition(i,j)  !Dummy implementation of cpp function
        integer :: i
        integer, dimension(:) :: j
        call check_trilinos()
    end subroutine getpartition

    subroutine inittrilinos(i,j,k)  !Dummy implementation of cpp function
        integer :: i,j
        integer, dimension(:) :: k
        call check_trilinos()
    end subroutine inittrilinos

    subroutine solvewithtrilinos(x,y,z)  !Dummy implementation of cpp function
        real(kind=dp), dimension(:) :: x,y
        real(kind=dp) :: z
        call check_trilinos()
    end subroutine solvewithtrilinos

    subroutine matvecwithtrilinos(x,y)  !Dummy implementation of cpp function
        real(kind=dp), dimension(:) :: x,y
        call check_trilinos()
    end subroutine matvecwithtrilinos

    subroutine restoretrilinosmatrix(i)  !Dummy implementation of cpp function
        integer :: i
        call check_trilinos()
    end subroutine restoretrilinosmatrix

    subroutine savetrilinosmatrix(i)  !Dummy implementation of cpp function
        integer :: i
        call check_trilinos()
    end subroutine savetrilinosmatrix

    subroutine putintotrilinosmatrix(i,j,x)  !Dummy implementation of cpp function
        integer :: i,j
        real(kind=dp) :: x
        call check_trilinos()
    end subroutine putintotrilinosmatrix

    subroutine solvetriadmatrixwithtrilinos (i,j,k,l,x,y,z)  !Dummy implementation of cpp function
        integer :: i,j
        integer, dimension(:) :: k,l
        real(kind=dp), dimension(:) :: x,y,z
        call check_trilinos()
    end subroutine solvetriadmatrixwithtrilinos

#endif
end module glimmer_sparse_trilinos
