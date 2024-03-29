      program problemKriging

      use dimpce
      
      implicit none
!
!     include the Ipopt return codes
!
      include 'IpReturnCodes.inc'
      include 'mpif.h'
!
!     Size of the problem (number of variables and equality constraints)
!
      integer     N,     M,     NELE_JAC,     NELE_HESS,      IDX_STY
      parameter  (N = 3, M = 3, NELE_JAC = 6, NELE_HESS = 5)
      parameter  (IDX_STY = 1 )
!
!     Space for multipliers and constraints
!
      double precision LAM(M)
      double precision G(M)
!
!     Vector of variables
!
      double precision X(N)
!
!     Vector of lower and upper bounds
!
      double precision X_L(N), X_U(N), Z_L(N), Z_U(N)
      double precision G_L(M), G_U(M)
!
!     Private data for evaluation routines
!     This could be used to pass double precision and integer arrays untouched
!     to the evaluation subroutines EVAL_*
!
      double precision DAT(2000)
      integer IDAT(1)
!
!     Place for storing the Ipopt Problem Handle
!
      integer*8 IPROBLEM
      integer*8 IPCREATE
!
      integer IERR
      integer IPSOLVE, IPADDSTROPTION
      integer IPADDNUMOPTION, IPADDINTOPTION
      integer IPOPENOUTPUTFILE
!
      double precision F,Fs,sigmax(N)
      integer i,kprob

      double precision  infbound
      parameter        (infbound = 1.d+20)
!
!     The following are the Fortran routines for computing the model
!     functions and their derivatives - their code can be found further
!     down in this file.
!
      external EV_F, EV_G, EV_GRAD_F, EV_JAC_G, EV_HESS, ITER_CB

      call MPI_START

      kprob=2
      sigmax(1)=0.05
      sigmax(2)=0.05
      sigmax(3)=0.05

      Fs=1.0

!
!     Set initial point and bounds:
!
      do i=1,N
          X(i) = 2.0
          X_L(i) = 0.0
          X_U(i) = infbound
      end do
    
!
!     Set bounds for the constraints
!
      do i=1,M
         G_L(i)=-infbound
         G_U(i)=0.d0
      end do

!
!     First create a handle for the Ipopt problem (and read the options
!     file)
!
      IPROBLEM = IPCREATE(N, X_L, X_U, M, G_L, G_U, NELE_JAC, NELE_HESS,IDX_STY, EV_F, EV_G, EV_GRAD_F, EV_JAC_G, EV_HESS)
      if (IPROBLEM.eq.0) then
         write(*,*) 'Error creating an Ipopt Problem handle.'
         call stop_all
      endif
!
!     Open an output file
!
!!$      IERR = IPOPENOUTPUTFILE(IPROBLEM, 'IPOPT.OUT', 5)
!!$      if (IERR.ne.0 ) then
!!$         write(*,*) 'Error opening the Ipopt output file.'
!!$         goto 9000
!!$      endif
!

!!
!!     Set a callback function to give you control once per iteration.
!!     You can use it if you want to generate some output, or to stop
!!     the optimization early.
!!
      call IPSETCALLBACK(IPROBLEM, ITER_CB)

!
!     Call optimization routine
!

      if (id_proc.eq.0) then
          IERR = IPADDINTOPTION(IPROBLEM, 'print_level', 0)
          if (IERR.ne.0 ) goto 9990
      else
         IERR = IPADDINTOPTION(IPROBLEM, 'print_level', 0)
         if (IERR.ne.0 ) goto 9990
      end if

      IDAT(1)=kprob
      DAT(1)=Fs
      do i=2,N+1
         DAT(i)=sigmax(i-1)
      end do

      IERR = IPSOLVE(IPROBLEM, X, G, F, LAM, Z_L, Z_U, IDAT, DAT)

!
!     Output:
!
      if (id_proc.eq.0) then

         if( IERR.eq.IP_SOLVE_SUCCEEDED .or. IERR.eq.5) then
            write(*,*)
            write(*,*) 'The solution was found.'
            write(*,*)
         else
            write(*,*)
            write(*,*) 'An error occoured.'
            write(*,*) 'The error code is ',IERR
            write(*,*)
         endif
         
         write(*,*) 'The final value of the objective function is ',F
         write(*,*)
         write(*,*) 'The optimal values of X are:'
         write(*,*)
         do i = 1, N
            write(*,*) 'X  (',i,') = ',X(i)
         enddo
         write(*,*)
         write(*,*) 'The multipliers for the equality constraints are:'
         write(*,*)
         do i = 1, M
            write(*,*) 'LAM(',i,') = ',LAM(i)
         enddo
         write(*,*)
         write(*,*) 'Weight and its variance:',DAT(N+2),DAT(N+3)
         
      end if
!
 9000 continue
!
!     Clean up
!
      call IPFREE(IPROBLEM)

      call stop_all
!
 9990 continue
      write(*,*) 'Error setting an option'
      goto 9000

    end program problemKriging
!
! =============================================================================
!
!                    Computation of objective function
!
! =============================================================================
!
      subroutine EV_F(N, X, NEW_X, F, IDAT, DAT, IERR)
      use dimpce
      
      implicit none
      integer N, NEW_X,I
      double precision F, X(N),sigmax(N),fmeantmp,fvartmp,fmeanprimetmp(n),fvarprimetmp(n)
      double precision DAT(*)
      integer IDAT(*),kprob,NMC
      integer IERR
      double precision fmin,fmax,gradmin(N-1),gradmax(N-1),gtol,low(N-1),up(N-1),Xsave(N)
      double precision  rho, L, sigmay, pi, p, E, Fs 

!      if (id_proc.eq.0) print *,'Calculate Objective',X

      NMC=100000

      Fs=DAT(1)
      kprob=IDAT(1)
      do i=1,N
         sigmax(i)=DAT(i+1)
         Xsave(i)=X(i)
      end do     

!!$      gtol=1e-4
!!$
!!$      low(1:N-1)=X(1:N-1)-sigmax(1:N-1)
!!$      up(1:N-1)=X(1:N-1)+sigmax(1:N-1)
!!$
!!$      call optimize(N-1,X,N,fmax,gradmax,low,up,gtol,.true.,.false.,1)


!---- MEAN and VARIANCE OF worst OBJECTIVE FUNCTION
      call  PCestimate(N,x,sigmax,fmeantmp,fvartmp,fmeanprimetmp,fvarprimetmp,8,0,3,0,0)
!      call Krigingestimate(1,X,N,sigmax,fmeantmp,fvartmp,fmeanprimetmp,fvarprimetmp,NMC,0)

!---- COMBINED OBJECTIVE FUNCTION
      F=fmeantmp+fvartmp
      
      DAT(N+2)=fmeantmp
      DAT(N+3)=fvartmp

!---- OBJECTIVE FUNCTION gradient and x value

      rho=0.2836
      sigmay=36260.0
      p=25000.0
      L=5.0
      E=30e6
      pi=4.0*atan(1.0)

      !---- GRADIENT OF worst OBJECTIVE FUNCTION
      DAT(N+3+1)= rho*L
      DAT(N+3+2)= rho*sqrt(L**2+X(3)**2)
      DAT(N+3+3)=fmeanprimetmp(3)+fvarprimetmp(3)

      do i=1,n
         DAT(2*N+3+i)=Xsave(i)
         X(i)=Xsave(i)
      end do

      IERR = 0
      return
      end

!
! =============================================================================
!
!                     Computation of constraints
!
! =============================================================================
!
      subroutine EV_G(N, X, NEW_X, M, G, IDAT, DAT, IERR)
      use dimpce
      
      implicit none
      integer N, NEW_X, M
      double precision G(M), X(N), sigmax(N), cmean(M), cstd(M), fmeantmp, fvartmp
      double precision DAT(*),fmeanprimetmp(n),fvarprimetmp(n),dc(M,N)
      integer IDAT(*),kprob,NMC
      integer IERR, i, j, cnt
      double precision fmin,fmax,gradmin(N-1),gradmax(N-1),gtol,low(N-1),up(N-1),Xsave(N)
      double precision  rho, L, sigmay, pi, p, E, Fs 

!      if (id_proc.eq.0) print *,'Calculate Constraints',X

      kprob=IDAT(1)
      do i=1,N
         sigmax(i)=DAT(i+1)
         Xsave(i)=X(i)
      end do

      NMC=100000

      dc(:,:)=0.0

      rho=0.2836
      sigmay=36260.0
      p=25000.0
      L=5.0
      E=30e6
      pi=4.0*atan(1.0)

      Fs=DAT(1)

      dc(1,2) = -p*Fs*sqrt(L**2+x(3)**2) / (x(2)**2*x(3)*sigmay) 
      dc(2,1) = -p*Fs*L / (x(1)**2*x(3)*sigmay)
      dc(3,1) = -8.0*p*Fs*L**3 / (pi*E*x(1)**3*x(3))

      do i=1,M

         !---- MEAN OF INEQUALITY CONSTRAINT i

!!$         gtol=1e-4
!!$         
!!$         low(1:N-1)=X(1:N-1)-sigmax(1:N-1)
!!$         up(1:N-1)=X(1:N-1)+sigmax(1:N-1) 
!!$      
!!$         call optimize(N-1,X,N,fmax,gradmax,low,up,gtol,.true.,.false.,i+1)

         call  PCestimate(N,x,sigmax,fmeantmp,fvartmp,fmeanprimetmp,fvarprimetmp,8,i,3,0,0)

    !     call Krigingestimate(1,X,N,sigmax,fmeantmp,fvartmp,fmeanprimetmp,fvarprimetmp,NMC,i)
     
         cmean(i)=fmeantmp
         cstd(i)=sqrt(fvartmp)
!               if (id_proc.eq.0) print*,fmeantmp,fvartmp,fmeanprimetmp,fvarprimetmp

         do j=n,N
            dc(i,j)=fmeanprimetmp(j)
            if (fvartmp.ne.0.0) then
               dc(i,j)=dc(i,j)+kprob*fvarprimetmp(j)/(2.0*sqrt(fvartmp))
 !              if (id_proc.eq.0) print*,dc(i,j)
            endif
         end do
!call stop_all
      end do

!---- COMBINED INEQUALITY CONSTRAINTS

      G(1:M)=cmean(1:M)+kprob*cstd(1:M)

!---- INEQUALITY CONSTRAINTS gradient

      do i=1,N
         DAT(3*N+3+i)=Xsave(i)
         X(i)=Xsave(i)
      end do

      cnt=0
      do i=1,M
         do j=1,N
            cnt=cnt+1
            DAT(4*N+3+cnt)=dc(i,j)
         end do
      end do


      IERR = 0
      return
      end

!
! =============================================================================
!
!                Computation of gradient of objective function
!
! =============================================================================
!
      subroutine EV_GRAD_F(N, X, NEW_X, GRAD, IDAT, DAT, IERR)
        use dimpce

        implicit none
        integer N, NEW_X,i
        double precision GRAD(N), X(N), sigmax(N), fmeantmp, fvartmp
        double precision DAT(*),fmeanprimetmp(n),fvarprimetmp(n)
        integer IDAT(*),kprob,NMC
        integer IERR
        double precision  rho, L, sigmay, pi, p, E, Fs 
        logical samex


        samex=.true.
        do i=1,N
           if (x(i).ne.DAT(2*N+3+i)) samex=.false. 
        end do

        if (samex) then

           !if (id_proc.eq.0) print *,'Samex in obj'

           !---- TOTAL GRADIENT OF OBJECTIVE FUNCTION
           do i=1,n
              GRAD(i)=DAT(N+3+i)
           end do

        else

           !if (id_proc.eq.0) print *,'Not Samex in obj'

           NMC=100000

           Fs=DAT(1)
           kprob=IDAT(1)
           do i=1,N
              sigmax(i)=DAT(i+1)
           end do

!!$      gtol=1e-4
!!$
!!$      low(1:N-1)=X(1:N-1)-sigmax(1:N-1)
!!$      up(1:N-1)=X(1:N-1)+sigmax(1:N-1)
!!$
!!$      call optimize(N-1,X,N,fmax,gradmax,low,up,gtol,.true.,.false.,1)


           !---- MEAN and VARIANCE OF worst OBJECTIVE FUNCTION

           call  PCestimate(N,x,sigmax,fmeantmp,fvartmp,fmeanprimetmp,fvarprimetmp,8,0,3,0,0)
           !         call Krigingestimate(1,X,N,sigmax,fmeantmp,fvartmp,fmeanprimetmp,fvarprimetmp,NMC,0)


           !---- OBJECTIVE FUNCTION gradient and x value

           rho=0.2836
           sigmay=36260.0
           p=25000.0
           L=5.0
           E=30e6
           pi=4.0*atan(1.0)

           !---- GRADIENT OF worst OBJECTIVE FUNCTION
           GRAD(1)= rho*L
           GRAD(2)= rho*sqrt(L**2+X(3)**2)
           GRAD(3)=fmeanprimetmp(3)+fvarprimetmp(3)


        end if

        !if (id_proc.eq.0) print *,'Obj Gradient',GRAD(1:3)

        IERR = 0
        return
      end subroutine EV_GRAD_F

      !
      ! =============================================================================
      !
      !                Computation of Jacobian of constraints
      !
      ! =============================================================================
      !
      subroutine EV_JAC_G(TASK, N, X, NEW_X, M, NZ, ACON, AVAR, JAC,IDAT, DAT, IERR)
        use dimpce

        implicit none
        integer TASK, N, NEW_X, M, NZ
        double precision X(N), JAC(NZ),dc(M,N), sigmax(N), fmeantmp, fvartmp
        integer ACON(NZ), AVAR(NZ), I, J, K, cnt, NMC
        double precision DAT(*),fmeanprimetmp(n),fvarprimetmp(n)
        double precision  rho, L, sigmay, pi, p, E, Fs
        integer IDAT(*)
        integer IERR, kprob
        logical samex

        if( TASK.eq.0 ) then 
           !
           !     structure of Jacobian:
           !
           ACON(1) = 1
           AVAR(1) = 2
           ACON(2) = 1
           AVAR(2) = 3
           ACON(3) = 2
           AVAR(3) = 1
           ACON(4) = 2
           AVAR(4) = 3
           ACON(5) = 3
           AVAR(5) = 1
           ACON(6) = 3
           AVAR(6) = 3

        else

           samex=.true.
           do i=1,N
              if (x(i).ne.DAT(3*N+3+i)) samex=.false. 
           end do

           if (samex) then

              !if (id_proc.eq.0) print *,'Samex in con'

              cnt=0
              do i=1,M
                 do j=1,N
                    cnt=cnt+1
                    dc(i,j)=DAT(4*N+3+cnt)
                 end do
              end do


           else

              !if (id_proc.eq.0) print *,'Not Samex in con'

              !---- TOTAL GRADIENT OF CONSTRAINTS 

              kprob=IDAT(1)
              do i=1,N
                 sigmax(i)=DAT(i+1)
              end do

              NMC=100000

              dc(:,:)=0.0

              rho=0.2836
              sigmay=36260.0
              p=25000.0
              L=5.0
              E=30e6
              pi=4.0*atan(1.0)

              Fs=DAT(1)

              dc(1,2) = -p*Fs*sqrt(L**2+x(3)**2) / (x(2)**2*x(3)*sigmay) 
              dc(2,1) = -p*Fs*L / (x(1)**2*x(3)*sigmay)
              dc(3,1) = -8.0*p*Fs*L**3 / (pi*E*x(1)**3*x(3))

              do i=1,M

                 !---- MEAN OF INEQUALITY CONSTRAINT i

!!$         gtol=1e-4
!!$         
!!$         low(1:N-1)=X(1:N-1)-sigmax(1:N-1)
!!$         up(1:N-1)=X(1:N-1)+sigmax(1:N-1) 
!!$      
!!$         call optimize(N-1,X,N,fmax,gradmax,low,up,gtol,.true.,.false.,i+1)

                 call  PCestimate(N,x,sigmax,fmeantmp,fvartmp,fmeanprimetmp,fvarprimetmp,8,i,3,0,0)

                 !               call Krigingestimate(1,X,N,sigmax,fmeantmp,fvartmp,fmeanprimetmp,fvarprimetmp,NMC,i)

                 do j=1,N
                    dc(i,j)=fmeanprimetmp(j)
                    if (fvartmp.ne.0.0) then
                       dc(i,j)=dc(i,j)+kprob*fvarprimetmp(j)/(2.0*sqrt(fvartmp))
                    endif
                 end do

              end do


           end if

           jac(1)=dc(1,2)
           jac(2)=dc(1,3)
           jac(3)=dc(2,1)
           jac(4)=dc(2,3)
           jac(5)=dc(3,1)
           jac(6)=dc(3,3)

           !if (id_proc.eq.0) print *,'Cons Gradients',jac(1:6)

        end if


        IERR = 0
        return
      end subroutine EV_JAC_G
      !
      ! =============================================================================
      !
      !                Computation of Hessian of Lagrangian
      !
      ! =============================================================================
      !
      subroutine EV_HESS(TASK, N, X, NEW_X, OBJFACT, M, LAM, NEW_LAM,NNZH, IRNH, ICNH, HESS, IDAT, DAT, IERR)
        implicit none
        integer TASK, N, NEW_X, M, NEW_LAM, NNZH, i, ir
        double precision X(N), OBJFACT, LAM(M), HESS(NNZH), sigmax(N)
        integer IRNH(NNZH), ICNH(NNZH)
        double precision DAT(*)
        integer IDAT(*), kprob
        integer IERR
        double precision  rho, L, sigmay, pi, p, E, Fs 

        rho=0.2836
        sigmay=36260.0
        p=25000.0
        L=5.0
        E=30e6
        pi=4.0*atan(1.0)

        Fs=DAT(1)

        kprob=IDAT(1)
        do i=1,N
           sigmax(i)=DAT(i+1)
        end do


        if( TASK.eq.0 ) then
           !
           !     structure of sparse Hessian (lower triangle):
           !
           IRNH(1) = 1
           ICNH(1) = 1
           IRNH(2) = 1
           ICNH(2) = 3
           IRNH(3) = 2
           ICNH(3) = 2
           IRNH(4) = 2
           ICNH(4) = 3
           IRNH(5) = 3
           ICNH(5) = 3

        else

           IERR = 1

        endif

        return
      end subroutine EV_HESS











      !
      ! =============================================================================
      !
      !                   Callback method called once per iteration
      !
      ! =============================================================================
      !
      subroutine ITER_CB(ALG_MODE, ITER_COUNT,OBJVAL, INF_PR, INF_DU,MU, DNORM, REGU_SIZE, ALPHA_DU, ALPHA_PR, LS_TRIAL, IDAT,DAT, ISTOP)
        use dimpce

        implicit none
        integer ALG_MODE, ITER_COUNT, LS_TRIAL
        double precision OBJVAL, INF_PR, INF_DU, MU, DNORM, REGU_SIZE
        double precision ALPHA_DU, ALPHA_PR
        double precision DAT(*)
        integer IDAT(*)
        integer ISTOP
        !
        !     You can put some output here
        !
        if (id_proc.eq.0) then

           if (ITER_COUNT .eq.0) then
              write(*,*) 
              write(*,*) 'iter    objective      ||grad||        inf_pr          inf_du         lg(mu)'
           end if

           write(*,'(i5,5e15.7)') ITER_COUNT,OBJVAL,DNORM,INF_PR,INF_DU,MU

        end if
        !
        !     And set ISTOP to 1 if you want Ipopt to stop now.  Below is just a
        !     simple example.
        !
        if (ITER_COUNT .gt. 1 .and. DNORM.le.1D-04) ISTOP = 1

        return
      end subroutine ITER_CB
