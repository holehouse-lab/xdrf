# This make file is part of the xdrf package.
#
# (C) 1995 Frans van Hoesel, hoesel@chem.rug.nl
# Define ARCH to be one the of architectures found in the conf directory.
# The names are the same as the ones used for compiling pvm, so you might
# want to use the value of PVM_ARCH.
# Auto-detect: macOS vs linux
UNAME_S := $(shell uname -s)
ifeq ($(UNAME_S),Darwin)
ARCH	= darwin
else
ARCH	= linux
# glibc 2.32 and later no longer ship the Sun RPC headers (rpc/rpc.h,
# rpc/xdr.h) or the xdr_* functions; libtirpc provides both. Use it when
# pkg-config can find it, and otherwise fall back to glibc's own RPC, which
# older systems such as Ubuntu 20.04 (glibc 2.31) still have.
TIRPC_CFLAGS := $(shell pkg-config --cflags libtirpc 2>/dev/null)
TIRPC_LIBS   := $(shell pkg-config --libs libtirpc 2>/dev/null)
endif

# Set FORTRAN compiler and flags for ARCH

# if intel compilers are available use gfortran and gcc
F77     = gfortran
CC      = gcc
CXX     = g++

#F77     = ifort

FFLAGS  = -O3 
CFLAGS 	= -O -D$(ARCH) $(TIRPC_CFLAGS)
CXXFLAGS = -O -std=c++17 -D$(ARCH) $(TIRPC_CFLAGS)

# Set C compiler and flags for ARCH
#CC      = icc



# Set HASRANLIB to t if your system needs ranlib
HASRANLIB = f	

# Set LIBS to libraries to link your c program with
# for SUN Solaris 2:
# LIBS = -lnsl
LIBS = $(TIRPC_LIBS)

SHELL	= /bin/sh


## RMCMD definition set ##

# set RM to rm -f if you want to remove the intermediate C source file
# generated for the FORTRAN interface library
#RMCMD 	= rm -f


# if we need to specify full paths we have to use different paths
# for linux or MacOS

# macOS
#RMCMD	= /usr/bin/true

# linux
#RMCMD	= /bin/true

# the definition below SHOULD work on both... hopefully!
RMCMD	= true

M4 	= m4

# Resolve the m4 config for ARCH. Two naming families live in conf/: the
# uppercase PVM_ARCH names (SUN4, RS6K, ALPHA, ...) and the lowercase short
# codes (sun, sgi, linux, darwin, ...). Two names collided between the two
# families case-insensitively -- SGI/sgi and CM5/cm5 -- which meant the
# repository could not be checked out correctly on macOS or Windows, where
# each pair is a single file. The uppercase duplicates were dropped (their
# contents were identical to the lowercase ones), so fall back to the
# lowercase spelling when an uppercase ARCH has no file of its own.
ARCH_LC := $(shell echo $(ARCH) | tr 'A-Z' 'a-z')
M4FILE	:= $(if $(wildcard conf/$(ARCH).m4),conf/$(ARCH).m4,conf/$(ARCH_LC).m4)

LFOBS 	= libxdrf.o 
LOBS	= xdr3dfcoord.o

default: libxdrf.a ctest ftest cxxtest

libxdrf.a:  $(LFOBS) ftocstr.o
	ar cr libxdrf.a $?
	case x$(HASRANLIB) in xt ) echo ranlib; ranlib libxdrf.a ;; esac

ctest:	ctest.c libxdrf.a xdrf.h
	$(CC) -o ctest $(CFLAGS) ctest.c libxdrf.a -lm $(LIBS)

ftest:	ftest.f libxdrf.a
	$(F77) -o ftest $(FFLAGS) ftest.f libxdrf.a $(LIBS)

cxxtest: cxxtest.cpp libxdrf.a xdrf.hpp xdrf.h
	$(CXX) -o cxxtest $(CXXFLAGS) cxxtest.cpp libxdrf.a -lm $(LIBS)

clean:
	rm -f $(LFOBS) $(LOBS) ftocstr.o libxdrf.a ftest ctest cxxtest
	rm -f libxdrf.c
	rm -f test.xdr test.out test_f.xdr test_f.out test_cpp.xdr test_cpp.out

tidy:
	rm -f $(LOBS) $(LFOBS)

ftocstr.o: ftocstr.c
	$(CC) $(CFLAGS) -c ftocstr.c

libxdrf.o:	libxdrf.m4 $(M4FILE) xdrf.h
	$(M4) $(M4FILE) libxdrf.m4 > libxdrf.c
	$(CC) $(CFLAGS) -c libxdrf.c
	$(RMCMD) libxdrf.c

conf/.m4:
	@echo "ERROR: you didn't set ARCH in the Makefile"
