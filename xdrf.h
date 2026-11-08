/*_________________________________________________________________
 |
 | xdrf.h - Public C header for the xdrf library.
 |
 | Include this file in any C program that uses xdropen(), xdrclose(),
 | or xdr3dfcoord(). You must also include <rpc/rpc.h> and <rpc/xdr.h>
 | before this header so that the XDR type is defined.
 |
 | For standard XDR primitives (xdr_int, xdr_float, xdr_double, etc.)
 | use the system <rpc/xdr.h> functions directly.
 |
*/

#ifndef XDRF_H
#define XDRF_H

// On Linux, xdrstdio_create is declared in <rpc/xdr.h> via libntirpc.
// On macOS, the declaration is missing from the system headers, so we
// provide it here. The function itself exists in the system RPC library.
#if defined(__APPLE__) || defined(darwin)
#include <stdio.h>
extern void xdrstdio_create(XDR *xdrs, FILE *file, enum xdr_op op);
#endif


/*
 * xdropen - Open an XDR file for reading or writing.
 *
 * This replaces xdrstdio_create and must be used instead of it when
 * using xdr3dfcoord(), because xdropen tracks the file mode (read/write)
 * and the file descriptor internally.
 *
 * Parameters:
 *   xdrs     - Pointer to a caller-allocated XDR struct, or NULL.
 *              If NULL (used by the Fortran interface), the library
 *              allocates the XDR struct internally and frees it on close.
 *   filename - Path to the file to open.
 *   type     - "w" or "W" for write, "a" or "A" for append, anything
 *              else for read.
 *
 * Returns: A nonzero xdrid handle on success, 0 on failure.
 */
int xdropen(XDR *xdrs, const char *filename, const char *type);

/*
 * xdrclose - Close an XDR file opened with xdropen.
 *
 * Flushes XDR buffers, destroys the XDR stream, and closes the
 * underlying file descriptor. Do not call xdr_destroy separately.
 *
 * If the library allocated the XDR struct (xdropen called with
 * xdrs == NULL) it is freed here; otherwise the caller keeps ownership.
 *
 * Returns: 1 on success, 0 if xdrs is NULL, was not opened by xdropen,
 *          or the file hit an I/O error -- check this after writing,
 *          because a full disk often only shows up when the final buffer
 *          is flushed here. The file is closed in every case. Versions
 *          before 1.6 called exit(1) for a bad stream, and versions up
 *          to 1.6 ignored I/O errors here and reported success.
 */
int xdrclose(XDR *xdrs) ;

/*
 * xdr3dfcoord - Read or write compressed 3D coordinates.
 *
 * Compresses floating-point 3D coordinates for efficient storage.
 * Coordinates are converted to fixed-point integers by multiplying
 * by *precision and rounding. The compression exploits spatial
 * locality and small inter-atom differences (especially effective
 * for water molecules in MD simulations).
 *
 * Parameters:
 *   xdrs      - XDR stream opened with xdropen.
 *   fp        - Array of 3 * (*size) floats (x,y,z triples).
 *   size      - On write: number of coordinate triples.
 *               On read: the number of triples the frame is expected to
 *               contain. A mismatch with the file is an error and the
 *               call fails without touching fp. Set to 0 to accept
 *               whatever count the file specifies -- but see the
 *               warning below. On return it holds the actual count.
 *   precision - Multiplier for float-to-int conversion (e.g. 1000.0
 *               gives 3 decimal places of precision). On read it is
 *               set to the value stored in the file, except for frames
 *               of 9 or fewer atoms, which are stored uncompressed and
 *               carry no precision field.
 *
 * Returns: 1 on success, 0 on failure.
 *
 * On write, a frame of 10 or more atoms is checked in full before any of
 * it is written, and refused (with nothing written) if the precision is
 * not positive and finite, if any coordinate is NaN or infinite, if a
 * scaled coordinate or coordinate range would not fit in 31 bits, or if
 * a coordinate would read back as infinite (which only an absurdly small
 * precision, such as a subnormal one, can cause).
 *
 * WARNING: with *size == 0 the library writes as many triples as the
 * file asks for, and has no way to know how large fp is. Only use 0
 * when you can bound the atom count independently -- for an untrusted
 * or possibly corrupt file, get the count with xdr3dfcoord_peek_size()
 * and size fp from it, or pass the count you expect. The C++ wrapper's
 * read_3dfcoord() does the former for you.
 *
 * Malformed input is rejected rather than followed: the atom count,
 * precision, coordinate ranges, compression index, run lengths and
 * compressed block size found in the file are all validated before use.
 */
int xdr3dfcoord(XDR *xdrs, float *fp, int *size, float *precision) ;

/*
 * xdr3dfcoord_peek_size - Report the atom count of the next frame.
 *
 * Reads the count that starts the next xdr3dfcoord frame and restores the
 * stream position, so the caller can allocate 3 * (*size) floats before
 * calling xdr3dfcoord. Works at any file offset; rewinding by hand with
 * xdr_getpos/xdr_setpos does not, because those carry the position in an
 * unsigned int and wrap past 4 GiB.
 *
 * Parameters:
 *   xdrs - XDR stream opened for reading with xdropen.
 *   size - Receives the atom count as stored in the file (unvalidated;
 *          xdr3dfcoord itself rejects bad counts).
 *
 * Returns: 1 on success, 0 if xdrs is not a read stream from xdropen or
 *          there is no further frame (end of file).
 */
int xdr3dfcoord_peek_size(XDR *xdrs, int *size) ;

#endif /* XDRF_H */

