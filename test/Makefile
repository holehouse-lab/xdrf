# Makefile for xdrf test suite.
# Run from the test/ directory, or from the parent with 'make -C test'.

PARENT   = ..
LIBXDRF  = $(PARENT)/libxdrf.a

# Inherit compiler settings from parent
CC       = gcc
CXX      = g++
F77      = gfortran

UNAME_S := $(shell uname -s)
ifeq ($(UNAME_S),Darwin)
ARCH     = darwin
else
ARCH     = linux
# libtirpc where glibc no longer ships the RPC headers; see ../Makefile.
TIRPC_CFLAGS := $(shell pkg-config --cflags libtirpc 2>/dev/null)
TIRPC_LIBS   := $(shell pkg-config --libs libtirpc 2>/dev/null)
endif

CFLAGS   = -O -D$(ARCH) -I$(PARENT) $(TIRPC_CFLAGS)
CXXFLAGS = -O -std=c++17 -D$(ARCH) -I$(PARENT) $(TIRPC_CFLAGS)
FFLAGS   = -O3
LIBS     = -lm $(TIRPC_LIBS)

TESTS    = test_xdrf test_fortran test_xdrf_cpp

.PHONY: all clean test

all: test

# Rebuild the library through the parent Makefile whenever one of its
# sources changes. With no prerequisites here, an existing libxdrf.a was
# always considered up to date, so the tests ran against a stale library.
LIBSRCS  = $(PARENT)/libxdrf.m4 $(PARENT)/ftocstr.c $(PARENT)/xdrf.h

$(LIBXDRF): $(LIBSRCS)
	$(MAKE) -C $(PARENT) libxdrf.a

test_xdrf: test_xdrf.c $(LIBXDRF) $(PARENT)/xdrf.h
	$(CC) -o $@ $(CFLAGS) $< $(LIBXDRF) $(LIBS)

test_fortran: test_fortran.f $(LIBXDRF)
	$(F77) -o $@ $(FFLAGS) $< $(LIBXDRF) $(LIBS)

test_xdrf_cpp: test_xdrf_cpp.cpp $(LIBXDRF) $(PARENT)/xdrf.h $(PARENT)/xdrf.hpp
	$(CXX) -o $@ $(CXXFLAGS) $< $(LIBXDRF) $(LIBS)

test: $(TESTS)
	@echo ""
	@echo "==============================="
	@echo "  Running C tests"
	@echo "==============================="
	./test_xdrf
	@echo ""
	@echo "==============================="
	@echo "  Running Fortran tests"
	@echo "==============================="
	./test_fortran
	@echo ""
	@echo "==============================="
	@echo "  Running C++ tests"
	@echo "==============================="
	./test_xdrf_cpp
	@echo ""
	@echo "==============================="
	@echo "  Cleaning up temp files"
	@echo "==============================="
	rm -f tmp_*.xdr
	@echo "All tests complete."

clean:
	rm -f $(TESTS) tmp_*.xdr
