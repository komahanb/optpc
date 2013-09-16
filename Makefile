# Copyright (C) 2003, 2010 International Business Machines and others.
# All Rights Reserved.
# This file is distributed under the Eclipse Public License.

# $Id: Makefile.in 1875 2010-12-28 23:32:54Z andreasw $

##########################################################################
#    You can modify this example makefile to fit for your own program.   #
#    Usually, you only need to change the five CHANGEME entries below.   #
##########################################################################

# CHANGEME: This should be the name of your executable
EXE = MixedOUU

# CHANGEME: Here is the name of all object files corresponding to the source
#           code that you wrote in order to define the problem statement
OBJS =  problemPC.o BFGSroutines.o optimize.o CalcstuffBFGS.o

# CHANGEME: Additional libraries
ADDLIBS =

# CHANGEME: Additional flags for compilation (e.g., include flags)
ADDINCFLAGS = 

##########################################################################
#  Usually, you don't have to change anything below.  Note that if you   #
#  change certain compiler options, you might have to recompile Ipopt.   #
##########################################################################

# Fortran Compiler options
F77 = mpif77
F90 = mpif90

# Fotran Compiler options
FFLAGS = -O3 -r8 -openmp 

# additional Fortran Compiler options for linking
F77LINKFLAGS =  -Wl,--rpath -Wl,/home/komahan/Dropbox/Thesis/Program/Markus/Ipopt-3.10.0/lib


# Linker flags
LIBS = `PKG_CONFIG_PATH=/home/komahan/Dropbox/Thesis/Program/Markus/Ipopt-3.10.0/lib/pkgconfig:/home/komahan/Dropbox/Thesis/Program/Markus/Ipopt-3.10.0/share/pkgconfig: /usr/bin/pkg-config --libs ipopt` -lstdc++ -lm -L/usr/local/lib -lgsl -lgslcblas


all: $(EXE)

.SUFFIXES: .f90 .o .F

$(EXE): $(OBJS) Eulersolve.a pcestimate.a libmir.a tapenade.a
	$(F90) $(F77LINKFLAGS) $(FFLAGS) -o $@ $^ $(LIBS) -Wl,-rpath=/usr/local/lib

clean:
	rm -f $(EXE) $(OBJS) IPOPT.OUT *~

%.o : %.F
	$(F77) $(FFLAGS)  -c -o $@ $<

%.o : %.f90
	$(F90) $(FFLAGS)  -c -o $@ $<

