  subroutine CalcstuffBFGS(X,ndvart,fobj,dfdD,fct)
    implicit none

    integer  :: ndvart,fct 
    double precision :: X(ndvart),fobj,dfdD(ndvart),x3
    double precision ::  rho, L, sigmay, pi, p, E, Fs  
    
    rho=0.2836
    sigmay=36260.0
    p=25000.0
    L=5.0
    E=30e6
    pi=4.0*atan(1.0)
    
    Fs=1.0

    if (fct.eq.1) then

       fobj = rho*x(1)*L+rho*x(2)*sqrt(L**2+x(3)**2)
       
       dfdD(1) = rho*L
       dfdD(2) = rho*sqrt(L**2+x(3)**2)

    else if (fct.eq.2) then

       fobj = p*Fs*sqrt(L**2+x(3)**2) / (x(2)*x(3)*sigmay) - 1.0

       dfdD(1) =0.0
       dfdD(2) =-p*Fs*sqrt(L**2+x(3)**2) / (x(2)**2*x(3)*sigmay)

    else if (fct.eq.3) then

       fobj = p*Fs*L / (x(1)*x(3)*sigmay) - 1.0

       dfdD(1) = -p*Fs*L / (x(1)**2*x(3)*sigmay)
       dfdD(2) = 0.0

    else if (fct.eq.4) then
       
       fobj  = 4.0*p*Fs*L**3 / (x(1)**2*x(3)*E*pi) - 1.0

       dfdD(1) = -8.0*p*Fs*L**3 / (pi*E*x(1)**3*x(3))
       dfdD(2) = 0.0

    end if
    





  end subroutine CalcstuffBFGS
