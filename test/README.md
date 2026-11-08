# xdrf test suite

Unit tests for the xdrf library covering the C, C++ and Fortran APIs.

## Building and running

From the `test/` directory:

    make test

Or from the project root:

    make -C test

This will build the library (if needed), compile all three test programs, run them, and clean up temporary files.

Each program writes its scratch files as `tmp_*.xdr` in the working directory. The C and C++ programs remove theirs as they go; the Fortran program leaves its `tmp_ftest_*.xdr` files behind, and `make test` sweeps up those and any left by a failing run.

## Test programs

### `test_xdrf.c` — C API tests

39 tests covering:

- **Open/Close**: write mode, read mode, nonexistent file handling
- **Primitive round-trips**: int, float, double, short, char, string, bool, mixed types
- **xdr3dfcoord**: small arrays, boundary cases (9/10 atoms), 100 and 1000 atoms, precision levels, negative/large/identical/scattered coordinates, water-like repeating patterns
- **Advanced**: append mode, multiple open files, reopen, setpos/getpos, multi-frame trajectories, metadata interleaved with coordinates, compression ratio verification
- **Robustness**: mixing caller-owned and library-owned `XDR` structs in either close order; rejection of a `size` that disagrees with the file; rejection of corrupt frames (out-of-range compression index, inverted or 2<sup>32</sup>-wide coordinate range, oversized or too-short compressed block, negative atom count, zero precision, truncated header), checked against an unpatched frame that reads back; the `"W"` and `"A"` modes; NULL and foreign streams; refusal, with nothing written, of NaN, infinite and out-of-range coordinates, of a precision that is not positive and finite, and of one so small that coordinates would read back as infinite; round-trips at precisions of 10<sup>5</sup> and 10<sup>6</sup>, including the large-range encoding; `xdr3dfcoord_peek_size`; `xdrclose` reporting a write that failed at the final flush; and a golden-bytes test that pins the exact output of `xdr3dfcoord`

The golden-bytes test compares FNV-1a hashes of frames written from deterministic data against values produced by gcc builds of 1.5 and 1.6, including two cases in the large-range encoding (an axis spanning more than 2<sup>24</sup> scaled units). If it fails, the on-disk bytes have changed: that is a format compatibility question, not a test to update casually.

Two tests run a child process under a file-size limit (`RLIMIT_FSIZE`) to simulate a full disk.

### `test_xdrf_cpp.cpp` — C++ API tests

30 tests covering:

- **Construction / RAII**: open and close via scope, explicit close, nonexistent file, move construction and assignment, operations on a closed file
- **Primitive round-trips**: int, float, double, short, char, bool, string, mixed types
- **xdr3dfcoord**: `std::vector` and raw-pointer overloads, 100 and 1000 atoms, precision levels, rejection of a coordinate count that is not a multiple of 3
- **Advanced**: multi-frame trajectories, setpos/getpos, append mode, compression ratio verification
- **Robustness**: `read_3dfcoord()` at end of file throws without moving the stream, `write_string` rejects embedded NULs, the `"W"` mode, `close()` throwing on a write that failed at the final flush, `write_*`/`read_*` throwing on a file opened the other way, `read_3dfcoord()` throwing `std::runtime_error` for a corrupt atom count

### `test_fortran.f` — Fortran API tests

22 tests covering:

- Primitive round-trips (int, float, double, short, char, bool, mixed, string via `xdrfstring` and `xdrfwrapstring`, opaque, long and unsigned long)
- xdr3dfcoord at various sizes (small, compressed, 100 atoms)
- Multi-frame trajectories, negative coordinates
- setpos/getpos, vector float, vector long, empty vector, file reopen
- An `xdrid` from a failed open or a closed file gives `ret = 0`, including for an empty `xdrfvector`
- `xdrfwrapstring` refuses a string too long for the variable it is read into

The robustness tests in `test_xdrf.c` call `xdrfclose_` directly, to close a library-owned handle by its id. The trailing underscore matches `conf/linux.m4` and `conf/darwin.m4`, the two configurations this suite builds for.

## Requirements

- `gcc`, `g++` (C++17) and `gfortran`
- On Linux with glibc 2.32 or later, libtirpc and `pkg-config` (see the main README's Requirements)
- The parent directory must contain the xdrf source (`libxdrf.m4`, `ftocstr.c`, etc.)
- macOS and Linux are auto-detected; no manual configuration needed

## Cleanup

Temporary `.xdr` files are removed automatically after a test run. To remove compiled binaries:

    make clean
