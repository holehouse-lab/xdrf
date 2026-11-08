/*____________________________________________________________________________
 |
 | libxdrf - portable fortran interface to xdr. some xdr routines
 |	     are C routines for compressed coordinates
 |
 | version 1.7
 |
 | This collection of routines is intended to write and read
 | data in a portable way to a file, so data written on one type
 | of machine can be read back on a different type.
 |
 | all fortran routines use an integer 'xdrid', which is an id to the
 | current xdr file, and is set by xdrfopen.
 | most routines have in integer 'ret' which is the return value.
 | The value of 'ret' is zero on failure, and most of the time one
 | on succes. An xdrid that does not name an open file (for example
 | the 0 left behind by a failed xdrfopen) gives ret = 0.
 |
 | There are four routines useful for C users:
 |  xdropen(), xdrclose(), xdr3dfcoord(), xdr3dfcoord_peek_size().
 | The first two replace xdrstdio_create and xdr_destroy, and *must* be
 | used when you plan to use xdr3dfcoord(). (they are also a bit
 | easier to interface). For writing data other than compressed coordinates
 | you should use the standard C xdr routines (see xdr man page)
 |
 | xdrfopen(xdrid, filename, mode, ret)
 |	character *(*) filename
 |	character *(*) mode
 |
 |	this will open the file with the given filename (string)
 |	and the given mode, it returns an id in xdrid, which is
 |	to be used in all other calls to xdrf routines.
 |	mode is 'w' (or 'W') to create or truncate a file for writing,
 |	'a' (or 'A') to append to it, and any other value opens the file
 |	for reading. The mode may be at most 2 characters and the filename
 |	at most 511 (trailing blanks aside); longer ones give ret = 0.
 |
 |	you need to call xdrfclose to flush the output and close
 |	the file.
 |	Note that you should not use xdrstdio_create, which comes with the
 |	standard xdr library
 |
 | xdrfclose(xdrid, ret)
 |	flush the data to the file, and closes the file;
 |	You should not use xdr_destroy (which comes standard with
 |	the xdr libraries.
 |	ret is 1 on success and 0 if xdrid does not name an open file
 |	or if the final flush to disk failed.
 |
 | xdrfbool(xdrid, bp, ret)
 |	integer pb
 |
 | 	This filter produces values of either 1 or 0	
 |
 | xdrfchar(xdrid, cp, ret)
 |	character cp
 |
 |	filter that translate between characters and their xdr representation
 |	Note that the characters in not compressed and occupies 4 bytes.
 |
 | xdrfdouble(xdrid, dp, ret)
 |	double dp
 |
 |	read/write a double.
 |
 | xdrffloat(xdrid, fp, ret)
 |	float fp
 |
 |	read/write a float.
 |
 | xdrfint(xdrid, ip, ret)
 |	integer ip
 |
 |	read/write integer.
 |
 | xdrflong(xdrid, lp, ret)
 |	integer lp
 |
 |	read/write a default (4 byte) integer as an xdr long, which is
 |	32 bits on the wire.
 |
 | xdrfshort(xdrid, sp, ret)
 |	integer *2 sp
 |
 | xdrfstring(xdrid, sp, maxsize, ret)
 |	character *(*)
 |	integer maxsize
 |
 |	read/write a string, with maximum length given by maxsize
 |
 | xdrfwrapstring(xdris, sp, ret)
 |	character *(*)
 |
 |	read/write a string (it is the same as xdrfstring accept that it finds
 |	the stringlength itself.
 |
 | xdrfvector(xdrid, cp, size, xdrfproc, ret)
 |	character *(*)
 |	integer size
 |	external xdrfproc
 |
 |	read/write an array pointed to by cp, with number of elements
 |	defined by 'size'. the routine 'xdrfproc' is the name
 |	of one of the above routines to read/write data (like xdrfdouble)
 |	In contrast with the c-version you don't need to specify the
 |	byte size of an element.
 |	xdrfstring is not allowed here (it is in the c version)
 |	
 | xdrf3dfcoord(xdrid, fp, size, precision, ret)
 |	real (*) fp
 |	real precision
 |	integer size
 |
 |	this is *NOT* a standard xdr routine. I named it this way, because
 |	it invites people to use the other xdr routines.
 | 	It is introduced to store specifically 3d coordinates of molecules
 |	(as found in molecular dynamics) and it writes it in a compressed way.
 |	It starts by multiplying all numbers by precision and
 |	rounding the result to integer. effectively converting
 |	all floating point numbers to fixed point.
 |	it uses an algorithm for compression that is optimized for
 |	molecular data, but could be used for other 3d coordinates
 |	as well. There is subtantial overhead involved, so call this
 |	routine only if you have a large number of coordinates to read/write
 |
 |	On read, size is the number of triplets the frame is expected to
 |	hold; a disagreement with the file is an error and ret comes back
 |	0. Passing 0 accepts whatever count the file specifies, which is
 |	only safe when fp is known to be large enough for it.
 |
 | ________________________________________________________________________
 |
 | Below are the routines to be used by C programmers. Use the 'normal'
 | xdr routines to write integers, floats, etc (see man xdr)	
 |
 | int xdropen(XDR *xdrs, const char *filename, const char *type)
 |	This will open the file with the given filename and the 
 |	given mode. You should pass it an allocated XDR struct
 |	in xdrs, to be used in all other calls to xdr routines.
 |	Mode is "w" (or "W") to create or truncate a file for writing,
 |	"a" (or "A") to append to it, and any other value opens the
 |	file for reading.
 |	You need to call xdrclose to flush the output and close
 |	the file.
 |
 |	Note that you should not use xdrstdio_create, which
 |	comes with the standard xdr library.
 |
 | int xdrclose(XDR *xdrs)
 |	Flush the data to the file, and close the file;
 |	You should not use xdr_destroy (which comes standard
 |	with the xdr libraries).
 |	Returns 1 on success, 0 if xdrs is NULL, was not opened
 |	by xdropen(), or the file hit an I/O error (check this after
 |	writing: a full disk often first shows up in the final flush).
 |
 | int xdr3dfcoord(XDR *xdrs, float *fp, int *size, float *precision)
 |	This is \fInot\fR a standard xdr routine. I named it this
 |	way, because it invites people to use the other xdr
 |	routines.
 |	See xdrf.h for the full description of *size and *precision,
 |	including the caveat about passing *size == 0 on read.
 |
 | int xdr3dfcoord_peek_size(XDR *xdrs, int *size)
 |	Report the atom count of the next frame without consuming it,
 |	so a reader can size its buffer before calling xdr3dfcoord().
 |
 |	(c) 1995 Frans van Hoesel, hoesel@chem.rug.nl
*/



/* 64-bit file offsets for ftello()/fseeko() in xdr3dfcoord_peek_size(), so
 * that it works past 2 GiB on 32-bit systems too. _LARGEFILE_SOURCE makes
 * glibc declare ftello() and fseeko() in strict ISO modes (-std=c99, -std=c11)
 * as well; without it they are implicitly declared there, ftello() comes back
 * truncated to an int, and frames past 4 GiB are read from the wrong place.
 * Both must precede every include.
 */
#define _FILE_OFFSET_BITS 64
#define _LARGEFILE_SOURCE 1

#include <limits.h>
#include <math.h>
#include <stdint.h>
#include <string.h>
#include <sys/types.h>
#include <rpc/rpc.h>
#include <rpc/xdr.h>
#include <stdio.h>
#include <stdlib.h>
#include "xdrf.h"

/* Forward declarations for Fortran-to-C string conversion helpers
 * (implemented in ftocstr.c). These convert between Fortran's
 * fixed-length space-padded strings and C's null-terminated strings.
 */
int ftocstr(char *, int, char *, int);
int ctofstr(char *, int, char *);

/* Maximum number of simultaneously open XDR files */
#define MAXID 20

/* Global state for managing open XDR file handles.
 *
 * xdrfiles[]  - FILE pointers for each open XDR file (indexed by xdrid).
 * xdridptr[]  - XDR stream pointers. Slots 1..MAXID-1 hold active streams;
 *               slot 0 is unused so that a valid xdrid is always nonzero.
 * xdrowned[]  - Per-slot ownership flag: 1 if the library allocated the XDR
 *               struct itself (the Fortran path, where xdropen() is called
 *               with xdrs == NULL) and so must free it on close; 0 if the
 *               caller owns the struct and is responsible for its memory.
 * cnt         - Running byte counter used by the Fortran wrapper functions
 *               to track offsets within xdrfvector() iterations.
 *
 * Whether a stream reads or writes is taken from its own x_op field. A
 * separate copy of the mode character used to be kept here, and it held
 * whatever the caller passed: 'W' and 'A' opened a write stream that
 * xdr3dfcoord() then treated as a read stream.
 *
 * Ownership used to be recorded in a single extra slot at xdridptr[MAXID]
 * that every xdropen() call overwrote, so the flag only ever described the
 * most recently opened file. Closing a C-opened file while a Fortran-opened
 * one was also open therefore called free() on memory the library did not
 * own (an abort, or worse if the struct was on the stack), and closing them
 * in the other order leaked. Tracking ownership per slot fixes both.
 *
 * ~alex [alex.holehouse@wustl.edu]
 */
static FILE *xdrfiles[MAXID];
static XDR *xdridptr[MAXID];
static char xdrowned[MAXID];
static unsigned int cnt;

/* Function pointer type for the Fortran element-processing callback
 * used by xdrfvector. The callback signature is:
 *   void func(int *xdrid, void *data, int *ret)
 */
typedef void (* FUNCTION(xdrfproc)) (int *, void *, int *);

/* slot_of_stream - find the table slot that holds an open stream.
 *
 * Parameters:
 *   xdrs - a stream pointer, possibly NULL.
 *
 * Returns the xdrid (1..MAXID-1) under which xdropen() registered xdrs,
 * or 0 if xdrs is NULL or was not opened by xdropen(). Slot 0 is never
 * used and is always NULL, so searching from 0 (as xdr3dfcoord once did)
 * matched a NULL stream and then dereferenced it.
 */
static int slot_of_stream(XDR *xdrs) {
    int xdrid;

    if (xdrs == NULL)
	return 0;
    for (xdrid = 1; xdrid < MAXID; xdrid++) {
	if (xdridptr[xdrid] == xdrs)
	    return xdrid;
    }
    return 0;
}

/* stream_of_id - look up the stream for a Fortran xdrid.
 *
 * Parameters:
 *   xdrid - pointer to the id that xdrfopen() handed out.
 *
 * Returns the stream, or NULL (after printing why) if the id does not name
 * an open file. Every Fortran wrapper goes through this so that the id
 * from a failed xdrfopen (0), a closed file, or an uninitialised variable
 * gives ret = 0 instead of a NULL dereference or a read off the table.
 */
static XDR *stream_of_id(const int *xdrid) {
    if (*xdrid < 1 || *xdrid >= MAXID || xdridptr[*xdrid] == NULL) {
	fprintf(stderr, "xdrf: %d is not the id of an open xdr file\n", *xdrid);
	return NULL;
    }
    return xdridptr[*xdrid];
}

/*___________________________________________________________________________
 |
 | Fortran wrapper functions
 |
 | These functions provide the Fortran-callable interface to XDR routines.
 | Each takes an xdrid (file handle index), the data to read/write, and
 | a ret pointer that receives 1 on success or 0 on failure. The xdrid
 | is checked first (see stream_of_id), so a bad one also gives ret = 0.
 |
 | The FUNCTION() and ARGS() macros are expanded by m4 using the
 | architecture-specific config files in the conf directory to handle Fortran name
 | mangling (e.g. appending underscores) and string passing conventions.
 |
*/

/* xdrfbool - Read/write a boolean value.
 * The boolean is stored as a 4-byte XDR integer (0 or 1).
 */
void
FUNCTION(xdrfbool) ARGS(`int *xdrid, int *pb, int *ret')
{
	XDR *xdrs = stream_of_id(xdrid);
	*ret = (xdrs != NULL) && xdr_bool(xdrs, (bool_t *) pb);
	cnt += sizeof(int);
}

/* xdrfchar - Read/write a single character.
 * Note: XDR stores characters in 4 bytes (not compressed).
 */
void
FUNCTION(xdrfchar) ARGS(`int *xdrid, char *cp, int *ret')
{
	XDR *xdrs = stream_of_id(xdrid);
	*ret = (xdrs != NULL) && xdr_char(xdrs, cp);
	cnt += sizeof(char);
}

/* xdrfdouble - Read/write a double-precision floating point value. */
void
FUNCTION(xdrfdouble) ARGS(`int *xdrid, double *dp, int *ret')
{
	XDR *xdrs = stream_of_id(xdrid);
	*ret = (xdrs != NULL) && xdr_double(xdrs, dp);
	cnt += sizeof(double);
}

/* xdrffloat - Read/write a single-precision floating point value. */
void
FUNCTION(xdrffloat) ARGS(`int *xdrid, float *fp, int *ret')
{
	XDR *xdrs = stream_of_id(xdrid);
	*ret = (xdrs != NULL) && xdr_float(xdrs, fp);
	cnt += sizeof(float);
}

/* xdrfint - Read/write a 32-bit integer. */
void
FUNCTION(xdrfint) ARGS(`int *xdrid, int *ip, int *ret')
{
	XDR *xdrs = stream_of_id(xdrid);
	*ret = (xdrs != NULL) && xdr_int(xdrs, ip);
	cnt += sizeof(int);
}

/* xdrflong - Read/write a Fortran default INTEGER as an XDR long.
 *
 * An XDR long is a 4-byte signed integer on the wire -- the same encoding
 * as an XDR int -- and the documented Fortran argument is a default
 * (4-byte) INTEGER, so this is xdr_int() on an int. It used to take a C
 * long: on every 64-bit platform that read 8 bytes from the caller's
 * 4-byte integer and, on decode, wrote 8 bytes back, overwriting the
 * neighbouring variable. Inside xdrfvector the 8-byte stride also skipped
 * every other element and wrote past the end of the array.
 */
void
FUNCTION(xdrflong) ARGS(`int *xdrid, int *lp, int *ret')
{
	XDR *xdrs = stream_of_id(xdrid);
	*ret = (xdrs != NULL) && xdr_int(xdrs, lp);
	cnt += sizeof(int);
}

/* xdrfshort - Read/write a 16-bit short integer. */
void
FUNCTION(xdrfshort) ARGS(`int *xdrid, short *sp, int *ret')
{
	XDR *xdrs = stream_of_id(xdrid);
	*ret = (xdrs != NULL) && xdr_short(xdrs, sp);
	cnt += sizeof(*sp);  /* stride in the caller's buffer, not the pointer size */
}

/* xdrfuchar - Read/write an unsigned character. */
void
FUNCTION(xdrfuchar) ARGS(`int *xdrid, unsigned char *ucp, int *ret')
{
	XDR *xdrs = stream_of_id(xdrid);
	*ret = (xdrs != NULL) && xdr_u_char(xdrs, ucp);
	cnt += sizeof(char);
}

/* xdrfulong - Read/write a Fortran default INTEGER as an XDR unsigned long.
 * Same reasoning as xdrflong: 4 bytes on the wire, 4 bytes in the caller.
 */
void
FUNCTION(xdrfulong) ARGS(`int *xdrid, unsigned int *ulp, int *ret')
{
	XDR *xdrs = stream_of_id(xdrid);
	*ret = (xdrs != NULL) && xdr_u_int(xdrs, ulp);
	cnt += sizeof(unsigned int);
}

/* xdrfushort - Read/write an unsigned 16-bit short integer. */
void
FUNCTION(xdrfushort) ARGS(`int *xdrid, unsigned short *usp, int *ret')
{
	XDR *xdrs = stream_of_id(xdrid);
	*ret = (xdrs != NULL) && xdr_u_short(xdrs, usp);
	cnt += sizeof(unsigned short);
}

/* xdrf3dfcoord - Read/write compressed 3D coordinates (Fortran interface).
 * Delegates to the C xdr3dfcoord() function. See that function's
 * documentation for details on the compression algorithm.
 */
void
FUNCTION(xdrf3dfcoord) ARGS(`int *xdrid, float *fp, int *size, float *precision, int *ret')
{
	XDR *xdrs = stream_of_id(xdrid);
	*ret = (xdrs != NULL) && xdr3dfcoord(xdrs, fp, size, precision);
}

/* xdrfstring - Read/write a string with a specified maximum length.
 * Converts from Fortran string format (fixed-length, space-padded)
 * to C string format (null-terminated) before passing to xdr_string,
 * then converts the result back to Fortran format.
 *
 * The scratch buffer must hold *maxsize characters plus a terminator,
 * because on decode xdr_string writes up to *maxsize bytes into it and
 * then null-terminates. Sizing the buffer from the Fortran string length
 * alone overflowed the heap whenever maxsize exceeded that length.
 *
 * Failures set ret to 0 like every other wrapper. They used to set -1,
 * which a caller testing ret against 0 (as the documentation says to)
 * took for success.
 */
void
FUNCTION(xdrfstring) ARGS(`int *xdrid, STRING_ARG(sp), int *maxsize, int *ret')
{
	XDR *xdrs = stream_of_id(xdrid);
	char *tsp;
	int bufsize;

	if (xdrs == NULL || *maxsize < 0) {
	    *ret = 0;
	    return;
	}
	bufsize = (STRING_LEN(sp) > *maxsize ? STRING_LEN(sp) : *maxsize) + 1;
	tsp = (char*) malloc(bufsize * sizeof(char));
	if (tsp == NULL) {
	    *ret = 0;
	    return;
	}
	if (ftocstr(tsp, bufsize, STRING_PTR(sp), STRING_LEN(sp))) {
	    *ret = 0;
	    free(tsp);
	    return;
	}
	*ret = xdr_string(xdrs, (char **) &tsp, (u_int) *maxsize);
	ctofstr( STRING_PTR(sp), STRING_LEN(sp), tsp);
	cnt += *maxsize;
	free(tsp);
}

/* xdrfwrapstring - Read/write a string, automatically determining its length.
 * Like xdrfstring but infers the max size from the Fortran string length
 * rather than requiring an explicit maxsize parameter.
 *
 * As above, the buffer needs maxsize + 1 bytes so that xdr_string can
 * null-terminate a maximum-length string on decode, and failures give 0.
 *
 * maxsize is the Fortran string's own length. It used to be one more, so
 * reading a string one character too long for the variable succeeded and
 * silently dropped its last character; now that read fails with ret = 0.
 */
void
FUNCTION(xdrfwrapstring) ARGS(`int *xdrid, STRING_ARG(sp), int *ret')
{
	XDR *xdrs = stream_of_id(xdrid);
	char *tsp;
	int maxsize;

	if (xdrs == NULL) {
	    *ret = 0;
	    return;
	}
	maxsize = STRING_LEN(sp);
	tsp = (char*) malloc((maxsize + 1) * sizeof(char));
	if (tsp == NULL) {
	    *ret = 0;
	    return;
	}
	if (ftocstr(tsp, maxsize + 1, STRING_PTR(sp), STRING_LEN(sp))) {
	    *ret = 0;
	    free(tsp);
	    return;
	}
	*ret = xdr_string(xdrs, (char **) &tsp, (u_int)maxsize);
	ctofstr( STRING_PTR(sp), STRING_LEN(sp), tsp);
	cnt += maxsize;
	free(tsp);
}

/* xdrfopaque - Read/write opaque (untyped) data of a fixed byte count.
 * The data is written as-is without any type conversion.
 *
 * cp is the address of the caller's data, as Fortran passes it. It used
 * to be declared as a pointer to a pointer and dereferenced, which took
 * the first bytes of the caller's data as an address -- so any ordinary
 * call crashed or read and wrote through a garbage pointer.
 */
void
FUNCTION(xdrfopaque) ARGS(`int *xdrid, char *cp, int *ccnt, int *ret')
{
	XDR *xdrs = stream_of_id(xdrid);
	*ret = (xdrs != NULL) && *ccnt >= 0
	       && xdr_opaque(xdrs, (caddr_t)cp, (u_int)*ccnt);
	cnt += *ccnt;
}

/* xdrfsetpos - Set the current position in the XDR stream.
 * Allows seeking to a specific byte offset for random access. Positions
 * are default INTEGERs, so this only reaches the first 2 GiB of a file.
 */
void
FUNCTION(xdrfsetpos) ARGS(`int *xdrid, int *pos, int *ret')
{
	XDR *xdrs = stream_of_id(xdrid);
	*ret = (xdrs != NULL) && *pos >= 0 && xdr_setpos(xdrs, (u_int) *pos);
}

/* xdrf - Get the current position in the XDR stream.
 * Returns the current byte offset in *pos, or -1 if xdrid does not name
 * an open file (this routine has no ret argument to report that in).
 */
void
FUNCTION(xdrf) ARGS(`int *xdrid, int *pos')
{
	XDR *xdrs = stream_of_id(xdrid);
	*pos = (xdrs != NULL) ? (int) xdr_getpos(xdrs) : -1;
}

/* xdrfvector - Read/write an array of elements using a callback.
 * Iterates over *size elements, calling elproc for each one.
 * The element-processing function (e.g. xdrffloat, xdrfdouble)
 * is passed as a function pointer. The global 'cnt' variable
 * tracks the byte offset so each element is read from the
 * correct position in the buffer.
 * Note: xdrfstring cannot be used as the element procedure.
 *
 * ret is 1 if every element succeeded. The loop stops at the first
 * failure, so ret cannot be reset to 1 by later elements, and an empty
 * vector reports success; previously ret was never set when size was 0.
 * The xdrid is checked here as well, so that an empty vector on a bad id
 * gives ret = 0 like every other routine rather than a silent success.
 */
void
FUNCTION(xdrfvector) ARGS(`int *xdrid, char *cp, int *size, FUNCTION(xdrfproc) elproc, int *ret')
{
	int lcnt;
	cnt = 0;
	if (stream_of_id(xdrid) == NULL) {
		*ret = 0;
		return;
	}
	*ret = 1;
	for (lcnt = 0; lcnt < *size && *ret != 0; lcnt++) {
		elproc(xdrid, (cp+cnt) , ret);
	}
}


/* xdrfclose - Close an XDR file (Fortran interface).
 * Delegates to xdrclose() and resets the byte counter.
 */
void
FUNCTION(xdrfclose) ARGS(`int *xdrid, int *ret')
{
	XDR *xdrs = stream_of_id(xdrid);
	*ret = (xdrs != NULL) && xdrclose(xdrs);
	cnt = 0;
}

/* xdrfopen - Open an XDR file (Fortran interface).
 * Converts Fortran strings (filename and mode) to C strings,
 * then calls xdropen() with xdrs=NULL so the library allocates
 * the XDR struct. Returns the xdrid handle and sets ret to 1
 * on success, 0 on failure.
 */
void
FUNCTION(xdrfopen) ARGS(`int *xdrid, STRING_ARG(fp), STRING_ARG(mode), int *ret')
{
	char fname[512];
	char fmode[3];

	/* Bail out if either string does not fit: previously the failure was
	 * recorded in *ret but then overwritten by the result of xdropen(),
	 * so a truncated filename was silently opened (or silently failed).
	 */
	*xdrid = 0;
	if (ftocstr(fname, sizeof(fname), STRING_PTR(fp), STRING_LEN(fp))) {
		fprintf(stderr, "xdrfopen: file name is longer than %d "
			"characters\n", (int) sizeof(fname) - 1);
		*ret = 0;
		return;
	}
	if (ftocstr(fmode, sizeof(fmode), STRING_PTR(mode),
			STRING_LEN(mode))) {
		fprintf(stderr, "xdrfopen: mode must be at most %d characters, "
			"e.g. 'r', 'w' or 'a'\n", (int) sizeof(fmode) - 1);
		*ret = 0;
		return;
	}

	*xdrid = xdropen(NULL, fname, fmode);
	if (*xdrid == 0)
		*ret = 0;
	else 
		*ret = 1;	
}

/*___________________________________________________________________________
 |
 | what follows are the C routines for opening, closing xdr streams
 | and the routine to read/write compressed coordinates together
 | with some routines to assist in this task (those are marked
 | static and cannot be called from user programs)
*/
/* Maximum absolute value for coordinate compression. Coordinates
 * scaled beyond this range will cause an overflow error. Cast to
 * double to avoid implicit int-to-float conversion warnings.
 */
#define MAXABS ((double)(INT_MAX-2))

#ifndef MIN
#define MIN(x,y) ((x) < (y) ? (x):(y))
#endif
#ifndef MAX
#define MAX(x,y) ((x) > (y) ? (x):(y))
#endif
/* Lookup table of "magic" integers used for adaptive compression.
 * These values define the range of the small-integer encoding at
 * each compression level. The compressor dynamically selects a
 * level (index into this table) based on the differences between
 * successive coordinates. Larger indices allow larger differences
 * but use more bits.
 */
static int magicints[] = {
    0, 0, 0, 0, 0, 0, 0, 0, 0,
    8, 10, 12, 16, 20, 25, 32, 40, 50, 64,
    80, 101, 128, 161, 203, 256, 322, 406, 512, 645,
    812, 1024, 1290, 1625, 2048, 2580, 3250, 4096, 5060, 6501,
    8192, 10321, 13003, 16384, 20642, 26007, 32768, 41285, 52015, 65536,
    82570, 104031, 131072, 165140, 208063, 262144, 330280, 416127, 524287, 660561,
    832255, 1048576, 1321122, 1664510, 2097152, 2642245, 3329021, 4194304, 5284491, 6658042,
    8388607, 10568983, 13316085, 16777216 };

/* FIRSTIDX: index of the first usable entry in magicints
 * (entries before this are zero and cannot be used for encoding).
 * LASTIDX: one past the last valid index in magicints, i.e. the number
 *          of entries. The largest index that may be dereferenced is
 *          therefore LASTIDX - 1; several places used to clamp to
 *          LASTIDX itself and read one element past the end of the table.
 *
 * LASTIDX is cast to int so that it does not silently promote the
 * surrounding signed comparisons (MIN/MAX below) to unsigned.
 */
#define FIRSTIDX 9
/* note that magicints[FIRSTIDX-1] == 0 */
#define LASTIDX ((int)(sizeof(magicints) / sizeof(*magicints)))


/*__________________________________________________________________________
 |
 | xdropen - open xdr file
 |
 | This versions differs from xdrstdio_create, because I need to know
 | the state of the file (read or write) so I can use xdr3dfcoord
 | in eigther read or write mode, and the file descriptor
 | so I can close the file (something xdr_destroy doesn't do).
 |
*/

int xdropen(XDR *xdrs, const char *filename, const char *type) {
    static int init_done = 0;
    enum xdr_op lmode;
    int xdrid;
    char newtype[5];
    
    /* One-time initialization: clear all XDR stream pointers */
    if (init_done == 0) {
	for (xdrid = 1; xdrid < MAXID; xdrid++) {
	    xdridptr[xdrid] = NULL;
	}
	init_done = 1;
    }
    /* Find the first unused slot in the xdridptr table */
    xdrid = 1;
    while (xdrid < MAXID && xdridptr[xdrid] != NULL) {
	xdrid++;
    }
    if (xdrid == MAXID) {
	return 0;
    }
    /* Map the mode character to fopen flags and XDR direction */
    if (*type == 'w' || *type == 'W') {
            strcpy(newtype,"wb+");
	    lmode = XDR_ENCODE;
    } else if (*type == 'a' || *type == 'A') {
            strcpy(newtype,"ab+");
            lmode = XDR_ENCODE;
    } else {
            strcpy(newtype,"rb");
	    lmode = XDR_DECODE;
    }
    xdrfiles[xdrid] = fopen(filename, newtype);
    if (xdrfiles[xdrid] == NULL) {
	return 0;
    }
    /* Determine whether this is a Fortran or C call.
     * Fortran calls pass xdrs == NULL, so the library allocates the XDR
     * struct itself and records that it must free it again on close.
     * C calls pass a pre-allocated XDR struct that the caller owns.
     */
    if (xdrs == NULL) {
	xdridptr[xdrid] = (XDR *) malloc(sizeof(XDR));
	if (xdridptr[xdrid] == NULL) {
	    fclose(xdrfiles[xdrid]);
	    xdrfiles[xdrid] = NULL;
	    return 0;
	}
	xdrowned[xdrid] = 1;
    } else {
	xdridptr[xdrid] = xdrs;
	xdrowned[xdrid] = 0;
    }

    /* Initialize the XDR stream on the opened file */
    xdrstdio_create(xdridptr[xdrid], xdrfiles[xdrid], lmode);
    return xdrid;
}

/*_________________________________________________________________________
 |
 | xdrclose - close a xdr file
 |
 | This will flush the xdr buffers, and destroy the xdr stream.
 | It also closes the associated file descriptor (this is *not*
 | done by xdr_destroy).
 |
 | Returns 1 on success and 0 if xdrs is NULL, does not refer to a
 | stream opened by xdropen(), or the file reported an I/O error. Earlier
 | versions called exit(1) in the first two cases, which tore down the
 | whole calling program over a recoverable error; the Fortran wrapper
 | already reports the result through 'ret'.
 |
 | The I/O check matters for writers: the xdr routines only fill the stdio
 | buffer, so a full disk or a file size limit often first shows up when
 | that buffer is flushed here. Ignoring it, as earlier versions did,
 | reported success for a file that was silently truncated. The stream is
 | closed and its slot released whatever the outcome.
 |
*/

int xdrclose(XDR *xdrs) {
    int xdrid;
    int io_ok;
    FILE *file;

    if (xdrs == NULL) {
	fprintf(stderr, "xdrclose: passed a NULL pointer\n");
	return 0;
    }
    xdrid = slot_of_stream(xdrs);
    if (xdrid == 0) {
	fprintf(stderr, "xdrclose: no such open xdr file\n");
	return 0;
    }

    file = xdrfiles[xdrid];
    xdr_destroy(xdrs);              /* Flushes the stdio buffer */
    io_ok = (ferror(file) == 0);    /* Any earlier read/write error, or the flush */
    if (fclose(file) != 0)          /* Close the underlying file */
	io_ok = 0;
    if (!io_ok)
	fprintf(stderr, "xdrclose: I/O error on xdr file; "
		"data read or written may be incomplete\n");
    xdrfiles[xdrid] = NULL;

    /* Only free the XDR struct if this library allocated it
     * (the Fortran path); otherwise the caller owns the memory.
     */
    if (xdrowned[xdrid]) {
	free(xdridptr[xdrid]);
    }
    xdrowned[xdrid] = 0;
    xdridptr[xdrid] = NULL;
    return io_ok;
}

/*_________________________________________________________________________
 |
 | xdr3dfcoord_peek_size - report the atom count of the next frame
 |
 | Reads the count that starts the next xdr3dfcoord frame and puts the
 | stream back where it was, so a reader can size its buffer first.
 |
 | Parameters:
 |   xdrs - a stream opened for reading with xdropen().
 |   size - receives the atom count as stored in the file. It is not
 |          validated here; xdr3dfcoord() rejects bad counts.
 |
 | Returns 1 on success, 0 if xdrs is not a read stream from xdropen(),
 | there is no further frame, or the position cannot be restored.
 |
 | The rewind uses ftello()/fseeko() on the underlying file rather than
 | xdr_getpos()/xdr_setpos(). The xdr position calls carry the offset in
 | an unsigned int, so past 4 GiB they returned the offset modulo 2^32 and
 | rewound to the wrong place -- a routine size for a trajectory.
 |
*/

int xdr3dfcoord_peek_size(XDR *xdrs, int *size) {
    int xdrid = slot_of_stream(xdrs);
    FILE *file;
    off_t start;
    int read_ok;

    if (xdrid == 0) {
	fprintf(stderr, "xdr3dfcoord_peek_size: no such open xdr file\n");
	return 0;
    }
    if (xdrs->x_op != XDR_DECODE) {
	fprintf(stderr, "xdr3dfcoord_peek_size: stream is not open for reading\n");
	return 0;
    }
    file = xdrfiles[xdrid];
    start = ftello(file);
    if (start < 0)
	return 0;
    read_ok = xdr_int(xdrs, size);
    /* Rewind even after a failed read: hitting the end of the file must
     * not leave the stream in a different place, or flagged as at EOF. */
    if (fseeko(file, start, SEEK_SET) != 0)
	return 0;
    return read_ok;
}

/*____________________________________________________________________________
 |
 | sendbits - encode num into buf using the specified number of bits
 |
 | This routines appends the value of num to the bits already present in
 | the array buf. You need to give it the number of bits to use and you
 | better make sure that this number of bits is enough to hold the value
 | Also num must be positive.
 |
 | num_of_bits may exceed 32: sendints() pads with sendbits(buf, n, 0) for
 | up to 64 bits. Shifting an int by 32 or more is undefined behaviour, so
 | those high chunks are taken as 0 explicitly -- which is what the shift
 | of a value below 2^32 means, and what the hardware happened to produce.
 |
*/

static void sendbits(int buf[], int num_of_bits, int num) {

    unsigned int cnt, lastbyte;
    int lastbits, shift;
    unsigned char * cbuf;

    cbuf = ((unsigned char *)buf) + 3 * sizeof(*buf);
    cnt = (unsigned int) buf[0];
    lastbits = buf[1];
    lastbyte =(unsigned int) buf[2];
    while (num_of_bits >= 8) {
	shift = num_of_bits - 8;
	lastbyte = (lastbyte << 8) | (shift >= 32 ? 0 : (num >> shift));
	cbuf[cnt++] = lastbyte >> lastbits;
	num_of_bits -= 8;
    }
    if (num_of_bits > 0) {
	lastbyte = (lastbyte << num_of_bits) | num;
	lastbits += num_of_bits;
	if (lastbits >= 8) {
	    lastbits -= 8;
	    cbuf[cnt++] = lastbyte >> lastbits;
	}
    }
    buf[0] = cnt;
    buf[1] = lastbits;
    buf[2] = lastbyte;
    if (lastbits>0) {
	cbuf[cnt] = lastbyte << (8 - lastbits);
    }
}

/*_________________________________________________________________________
 |
 | sizeofint - calculate bitsize of an integer
 |
 | return the number of bits needed to store an integer with given max size
 |
*/

static int sizeofint(const int size) {
    unsigned int num = 1;
    int num_of_bits = 0;
    
    while (size >= num && num_of_bits < 32) {
	num_of_bits++;
	num <<= 1;
    }
    return num_of_bits;
}

/*___________________________________________________________________________
 |
 | sizeofints - calculate 'bitsize' of compressed ints
 |
 | given the number of small unsigned integers and the maximum value
 | return the number of bits needed to read or write them with the
 | routines receiveints and sendints. You need this parameter when
 | calling these routines. Note that for many calls I can use
 | the variable 'smallidx' which is exactly the number of bits, and
 | So I don't need to call 'sizeofints for those calls.
*/

static int sizeofints( const int num_of_ints, unsigned int sizes[]) {
    int i, num;
    unsigned int num_of_bytes, num_of_bits, bytes[32], bytecnt, tmp;
    num_of_bytes = 1;
    bytes[0] = 1;
    num_of_bits = 0;
    for (i=0; i < num_of_ints; i++) {	
	tmp = 0;
	for (bytecnt = 0; bytecnt < num_of_bytes; bytecnt++) {
	    tmp = bytes[bytecnt] * sizes[i] + tmp;
	    bytes[bytecnt] = tmp & 0xff;
	    tmp >>= 8;
	}
	while (tmp != 0) {
	    bytes[bytecnt++] = tmp & 0xff;
	    tmp >>= 8;
	}
	num_of_bytes = bytecnt;
    }
    num = 1;
    num_of_bytes--;
    while (bytes[num_of_bytes] >= num) {
	num_of_bits++;
	num *= 2;
    }
    return num_of_bits + num_of_bytes * 8;

}
    
/*____________________________________________________________________________
 |
 | sendints - send a small set of small integers in compressed format
 |
 | this routine is used internally by xdr3dfcoord, to send a set of
 | small integers to the buffer. 
 | Multiplication with fixed (specified maximum ) sizes is used to get
 | to one big, multibyte integer. Allthough the routine could be
 | modified to handle sizes bigger than 16777216, or more than just
 | a few integers, this is not done, because the gain in compression
 | isn't worth the effort. Note that overflowing the multiplication
 | or the byte buffer (32 bytes) is unchecked and causes bad results.
 |
 */
 
static void sendints(int buf[], const int num_of_ints, const int num_of_bits,
	unsigned int sizes[], unsigned int nums[]) {

    int i;
    unsigned int bytes[32], num_of_bytes, bytecnt, tmp;

    tmp = nums[0];
    num_of_bytes = 0;
    do {
	bytes[num_of_bytes++] = tmp & 0xff;
	tmp >>= 8;
    } while (tmp != 0);

    for (i = 1; i < num_of_ints; i++) {
	if (nums[i] >= sizes[i]) {
	    fprintf(stderr,"major breakdown in sendints num %d doesn't "
		    "match size %d\n", nums[i], sizes[i]);
	    exit(1);
	}
	/* use one step multiply */    
	tmp = nums[i];
	for (bytecnt = 0; bytecnt < num_of_bytes; bytecnt++) {
	    tmp = bytes[bytecnt] * sizes[i] + tmp;
	    bytes[bytecnt] = tmp & 0xff;
	    tmp >>= 8;
	}
	while (tmp != 0) {
	    bytes[bytecnt++] = tmp & 0xff;
	    tmp >>= 8;
	}
	num_of_bytes = bytecnt;
    }
    if (num_of_bits >= num_of_bytes * 8) {
	for (i = 0; i < num_of_bytes; i++) {
	    sendbits(buf, 8, bytes[i]);
	}
	sendbits(buf, num_of_bits - num_of_bytes * 8, 0);
    } else {
	for (i = 0; i < num_of_bytes-1; i++) {
	    sendbits(buf, 8, bytes[i]);
	}
	sendbits(buf, num_of_bits- (num_of_bytes -1) * 8, bytes[i]);
    }
}


/*___________________________________________________________________________
 |
 | receivebits - decode number from buf using specified number of bits
 | 
 | extract the number of bits from the array buf and construct an integer
 | from it. Return that value.
 |
*/

static int receivebits(int buf[], int num_of_bits) {

    int cnt, num;
    unsigned int lastbits, lastbyte;
    unsigned char * cbuf;
    /* 1 << 32 is undefined behaviour, and num_of_bits can legitimately
     * reach 32 via sizeofint(), so build the mask without shifting off
     * the end of the type.
     */
    unsigned int mask = (num_of_bits >= 32) ? 0xffffffffu
					    : ((1u << num_of_bits) - 1);

    cbuf = ((unsigned char *)buf) + 3 * sizeof(*buf);
    cnt = buf[0];
    lastbits = (unsigned int) buf[1];
    lastbyte = (unsigned int) buf[2];
    
    num = 0;
    while (num_of_bits >= 8) {
	lastbyte = ( lastbyte << 8 ) | cbuf[cnt++];
	num |=  (lastbyte >> lastbits) << (num_of_bits - 8);
	num_of_bits -=8;
    }
    if (num_of_bits > 0) {
	if (lastbits < num_of_bits) {
	    lastbits += 8;
	    lastbyte = (lastbyte << 8) | cbuf[cnt++];
	}
	lastbits -= num_of_bits;
	num |= (lastbyte >> lastbits) & ((1 << num_of_bits) -1);
    }
    num &= mask;
    buf[0] = cnt;
    buf[1] = lastbits;
    buf[2] = lastbyte;
    return num; 
}

/*____________________________________________________________________________
 |
 | receiveints - decode 'small' integers from the buf array
 |
 | this routine is the inverse from sendints() and decodes the small integers
 | written to buf by calculating the remainder and doing divisions with
 | the given sizes[]. You need to specify the total number of bits to be
 | used from buf in num_of_bits.
 |
 | The arithmetic is unsigned. With signed ints, (num << 8) overflowed
 | once a remainder reached 2^23 -- any axis range above about 8.4e6
 | scaled units, e.g. 8.4 nm at a precision of 1e6 -- as did
 | (bytes[3] << 24); both are undefined behaviour. Every value fits in
 | 32 bits unsigned, so the results are unchanged.
 |
*/

static void receiveints(int buf[], const int num_of_ints, int num_of_bits,
	unsigned int sizes[], int nums[]) {
    unsigned int bytes[32];
    unsigned int p, num;
    int i, j, num_of_bytes;

    bytes[1] = bytes[2] = bytes[3] = 0;
    num_of_bytes = 0;
    while (num_of_bits > 8) {
	bytes[num_of_bytes++] = receivebits(buf, 8);
	num_of_bits -= 8;
    }
    if (num_of_bits > 0) {
	bytes[num_of_bytes++] = receivebits(buf, num_of_bits);
    }
    for (i = num_of_ints-1; i > 0; i--) {
	num = 0;
	for (j = num_of_bytes-1; j >=0; j--) {
	    num = (num << 8) | bytes[j];
	    p = num / sizes[i];
	    bytes[j] = p;
	    num = num - p * sizes[i];
	}
	nums[i] = (int)num;
    }
    nums[0] = (int)(bytes[0] | (bytes[1] << 8) | (bytes[2] << 16) | (bytes[3] << 24));
}
    
/* Scratch buffers shared by all xdr3dfcoord() calls.
 *
 * ip      - the fixed-point integer form of the coordinates, 3 ints per atom.
 * buf     - the bit-packed representation, with three ints of bookkeeping
 *           at the front (see the comment in xdr3dfcoord).
 * bufints - the capacity of buf, in ints.
 * oldsize - the number of atoms the buffers were last sized for.
 *
 * They are static so that consecutive frames of the same size reuse a
 * single allocation, which is the common case for a trajectory.
 */
static int *coord_ip = NULL;
static int *coord_buf = NULL;
static int coord_bufints = 0;
static int coord_oldsize = 0;

/*____________________________________________________________________________
 |
 | ensure_buffers - grow the xdr3dfcoord scratch buffers to hold 'size' atoms
 |
 | Returns 1 on success and 0 if an allocation fails. The previous code
 | duplicated this block in the read and write paths, called exit(1) on
 | failure, and assigned realloc()'s result straight over the old pointer
 | (leaking it when realloc returned NULL).
 |
*/

static int ensure_buffers(int size) {
    int size3, newbufints;
    int *newip, *newbuf;

    if (coord_ip != NULL && size <= coord_oldsize)
	return 1;

    size3 = size * 3;
    /* Allow ~20% headroom for data that does not compress well, and check
     * the headroom itself fits in an int before converting back.
     */
    if ((double)size3 * 1.2 + 3.0 > (double)INT_MAX) {
	fprintf(stderr, "xdr3dfcoord: %d atoms is too many\n", size);
	return 0;
    }
    newbufints = (int)(size3 * 1.2) + 3;
    /* On a 32-bit system the byte counts below can exceed SIZE_MAX, and
     * realloc() would then be handed a wrapped, much smaller size.
     * newbufints is the larger of the two element counts, so checking it
     * covers both allocations.
     */
    if ((size_t) newbufints > SIZE_MAX / sizeof(*coord_buf)) {
	fprintf(stderr, "xdr3dfcoord: %d atoms is too many\n", size);
	return 0;
    }

    newip = (int *) realloc(coord_ip, size3 * sizeof(*coord_ip));
    if (newip == NULL) {
	fprintf(stderr, "xdr3dfcoord: out of memory for %d atoms\n", size);
	return 0;
    }
    coord_ip = newip;

    newbuf = (int *) realloc(coord_buf, newbufints * sizeof(*coord_buf));
    if (newbuf == NULL) {
	fprintf(stderr, "xdr3dfcoord: out of memory for %d atoms\n", size);
	return 0;
    }
    coord_buf = newbuf;
    coord_bufints = newbufints;
    coord_oldsize = size;
    return 1;
}

/*____________________________________________________________________________
 |
 | xdr_float_array - read or write n consecutive floats
 |
 | Used for the short-frame path, where compression is not worth the
 | overhead. This used to call xdr_vector() with xdr_float cast to
 | xdrproc_t, which invokes a two-argument function through a
 | three-argument pointer type. That is undefined behaviour and traps
 | under UBSan and CFI, even though it happens to work on the common
 | ABIs. xdr_vector() is defined as precisely this loop, so the on-disk
 | format is unchanged.
 |
*/

static int xdr_float_array(XDR *xdrs, float *fp, unsigned int n) {
    unsigned int i;

    for (i = 0; i < n; i++) {
	if (xdr_float(xdrs, fp + i) == 0)
	    return 0;
    }
    return 1;
}

/*____________________________________________________________________________
 |
 | scale_coordinate - convert one coordinate to the fixed-point integer form
 |
 | Parameters:
 |   value     - the coordinate, in whatever units the caller uses.
 |   precision - the fixed-point multiplier (e.g. 1000 for 3 decimals).
 |   scaled    - receives value * precision rounded half away from zero.
 |
 | Returns 1 on success and 0 if the scaled value is NaN, infinite, or
 | larger in magnitude than MAXABS. The range has to be checked before the
 | conversion to int: converting an out-of-range float is undefined
 | behaviour, and in practice NaN came out as 0 on arm64, so a NaN
 | coordinate was silently written as zero and the call reported success.
 | The arithmetic is exactly that of earlier versions, so in-range values
 | scale to the same integers bit for bit.
 |
*/

static int scale_coordinate(float value, float precision, int *scaled) {
    float lf;

    if (value >= 0.0)
	lf = value * precision + 0.5;
    else
	lf = value * precision - 0.5;
    /* Written as !(x <= max) so that NaN, which fails every comparison,
     * is rejected along with the values that are merely too large. */
    if (!(fabs(lf) <= MAXABS))
	return 0;
    *scaled = (int) lf;
    return 1;
}

/*____________________________________________________________________________
 |
 | wrapped_int - reinterpret a 32-bit unsigned value as a two's-complement int
 |
 | Converting an unsigned value above INT_MAX straight to int is
 | implementation-defined, so the negative range is rebuilt explicitly.
 |
*/

static int wrapped_int(unsigned int value) {
    if (value <= (unsigned int) INT_MAX)
	return (int) value;
    return -(int)(UINT_MAX - value) - 1;
}

/*____________________________________________________________________________
 |
 | wrapped_sqr_distance - squared distance between two scaled coordinates,
 |                        with 32-bit wraparound
 |
 | Parameters:
 |   a, b - two coordinate triples in scaled (fixed-point) units.
 |
 | Returns (a-b).(a-b) reduced modulo 2^32 and read as a signed int.
 |
 | The writer uses this distance only to decide whether a run of small
 | differences lets it step down to a finer compression level, and the
 | decision itself is written into the stream, so any answer yields a valid
 | frame that every reader decodes the same way. Earlier versions (and
 | other XTC writers built from this code) computed it in plain int, which
 | overflows for precisions around 1e5 and above. That was undefined
 | behaviour, and what it produced depended on the compiler: GNU gcc at
 | any optimisation level, and clang without optimisation, wrapped and
 | compared the results as signed ints; optimised clang assumed no
 | overflow and compared the same bits as unsigned. Doing the arithmetic
 | in unsigned, where wrapping is defined, and comparing as signed
 | reproduces the gcc result exactly. Frames are therefore byte-identical
 | to gcc builds of earlier versions -- the usual way they were built on
 | Linux -- and no longer depend on the compiler.
 |
*/

static int wrapped_sqr_distance(const int a[3], const int b[3]) {
    unsigned int dx = (unsigned int) a[0] - (unsigned int) b[0];
    unsigned int dy = (unsigned int) a[1] - (unsigned int) b[1];
    unsigned int dz = (unsigned int) a[2] - (unsigned int) b[2];

    return wrapped_int(dx * dx + dy * dy + dz * dz);
}

/*____________________________________________________________________________
 |
 | wrapped_manhattan_distance - |a-b| summed over the three axes, with 32-bit
 |                              wraparound
 |
 | Parameters:
 |   a, b - two coordinate triples in scaled (fixed-point) units.
 |
 | Returns the sum reduced modulo 2^32 and read as a signed int.
 |
 | The writer takes the smallest of these distances between consecutive
 | atoms to pick the initial compression index, which it writes into the
 | frame. Earlier versions summed the three per-axis distances in int.
 | Above INT_MAX that overflowed -- undefined behaviour, which every gcc
 | build tested (gcc 7 and 9 at -O0 to -O3) wrapped to a negative number.
 | That negative number then won the minimum and pinned the index at
 | FIRSTIDX. It takes only one pair of consecutive atoms more than 2^31
 | scaled units apart (about 2.1 um at a precision of 1e6). Reproducing
 | the wrap in unsigned arithmetic keeps those frames byte-identical to
 | gcc builds of earlier versions, as wrapped_sqr_distance() does for the
 | step-down heuristic. Summing exactly instead changed the bytes of such
 | frames (though not what they decode to).
 |
 | Each per-axis distance is below 2^31 in any frame that passes the range
 | check; frames where it is not are refused before anything is written,
 | so what this returns for them does not matter.
 |
*/

static int wrapped_manhattan_distance(const int a[3], const int b[3]) {
    unsigned int sum = 0;
    int k;

    for (k = 0; k < 3; k++)
	sum += (unsigned int) llabs((long long) a[k] - b[k]);
    return wrapped_int(sum);
}

/*____________________________________________________________________________
 |
 | xdr3dfcoord - read or write compressed 3d coordinates to xdr file.
 |
 | this routine reads or writes (depending on how you opened the file with
 | xdropen() ) a large number of 3d coordinates (stored in *fp).
 | The number of coordinates triplets to write is given by *size. On
 | read this number may be zero, in which case it reads as many as were written
 | or it may specify the number if triplets to read (which should match the
 | number written).
 | Compression is achieved by first converting all floating numbers to integer
 | using multiplication by *precision and rounding to the nearest integer.
 | Then the minimum and maximum value are calculated to determine the range.
 | The limited range of integers so found, is used to compress the coordinates.
 | In addition the differences between succesive coordinates is calculated.
 | If the difference happens to be 'small' then only the difference is saved,
 | compressing the data even more. The notion of 'small' is changed dynamically
 | and is enlarged or reduced whenever needed or possible.
 | Extra compression is achieved in the case of GROMOS and coordinates of
 | water molecules. GROMOS first writes out the Oxygen position, followed by
 | the two hydrogens. In order to make the differences smaller (and thereby
 | compression the data better) the order is changed into first one hydrogen
 | then the oxygen, followed by the other hydrogen. This is rather special, but
 | it shouldn't harm in the general case.
 |
 */
 
int xdr3dfcoord(XDR *xdrs, float *fp, int *size, float *precision) {
    
    /* Scratch buffers for the integer coordinates and the bit-packed
     * data. Allocated by ensure_buffers() and shared across calls.
     */
    int *ip, *buf;

    /* minint/maxint: per-axis min/max of integer coordinates (for range encoding).
     * mindiff: minimum Manhattan distance between successive coordinate triples
     *          (used to choose initial compression level), with the 32-bit
     *          wraparound of earlier versions; see wrapped_manhattan_distance().
     */
    int minint[3], maxint[3], *lip;
    int mindiff, diff;
    int smallidx;
    int minidx, maxidx;
    /* sizeint: per-axis range (max - min + 1) for absolute coordinate encoding.
     * sizesmall: per-axis range for difference encoding (set to magicints[smallidx]).
     * bitsizeint: per-axis bit widths when ranges are too large for combined encoding.
     */
    unsigned sizeint[3], sizesmall[3], bitsizeint[3], size3, *luip;
    int flag, k;
    /* small/smaller/larger: half the magicints values at the current, previous,
     * and next compression levels. Used to test whether coordinate differences
     * fit within the current encoding window.
     */
    int small, smaller, larger, i, is_small, is_smaller, run, prevrun;
    float *lfp;
    int tmp, *thiscoord,  prevcoord[3];
    unsigned int tmpcoord[30];  /* Temp buffer for up to 10 coordinate triples in a run */

    int lsize;
    unsigned int bitsize;
    float inv_precision;
    size_t buf_capacity_bytes, bytes_declared;

    /* xdr3dfcoord only works on streams from xdropen(). An unknown or NULL
     * stream is a caller error, but reporting it through the documented 0
     * return is friendlier than exiting (or crashing) the whole program.
     */
    if (slot_of_stream(xdrs) == 0) {
	fprintf(stderr, "xdr error. no open xdr stream\n");
	return 0;
    }
    /* Everything downstream works in units of 3 ints per atom, so reject
     * counts whose triple would not fit in an int before computing it.
     */
    if (*size < 0 || *size > INT_MAX / 3) {
	fprintf(stderr, "xdr3dfcoord: bad size %d\n", *size);
	return 0;
    }
    if (xdrs->x_op == XDR_ENCODE) {

	/* xdrs is open for writing */

	size3 = *size * 3;
	/* when the number of coordinates is small, don't try to compress; just
	 * write them as floats
	 */
	if (*size <= 9 ) {
	    if (xdr_int(xdrs, size) == 0)
		return 0;
	    return xdr_float_array(xdrs, fp, size3);
	}

	/* Every check on the input happens before the first byte of the
	 * frame is written, so a frame that cannot be stored fails without
	 * touching the stream. Earlier versions wrote the header, noted the
	 * problem, and went on to encode and write the whole (garbage) frame
	 * before returning 0.
	 *
	 * A zero or non-finite precision maps every coordinate to the same
	 * integer (or to nothing), and the reader then divides by it; the
	 * call used to succeed and the data came back as NaN.
	 */
	/* A negative precision is refused too: the rounding below assumes a
	 * positive one, and with a negative precision coordinates came back
	 * with up to three times the error that 0.5/precision promises.
	 */
	if (!(*precision > 0.0f) || !isfinite(*precision)) {
	    fprintf(stderr, "xdr3dfcoord: precision %g cannot store "
		    "coordinates\n", (double) *precision);
	    return 0;
	}
	if (ensure_buffers(*size) == 0)
	    return 0;
	ip = coord_ip;
	buf = coord_buf;
	/* buf[0-2] are reserved metadata for the bit-packing routines:
	 *   buf[0] = byte count written so far
	 *   buf[1] = number of leftover bits in the current byte
	 *   buf[2] = value of the current partial byte
	 * Actual compressed data starts at buf[3].
	 */
	buf[0] = buf[1] = buf[2] = 0;
	minint[0] = minint[1] = minint[2] = INT_MAX;
	maxint[0] = maxint[1] = maxint[2] = INT_MIN;
	prevrun = -1;
	lip = ip;
	mindiff = INT_MAX;
	/* PASS 1: Convert all float coordinates to fixed-point integers
	 * by multiplying by precision and rounding. Track per-axis
	 * min/max and the minimum inter-coordinate Manhattan distance
	 * (between consecutive atoms, so starting from the second one).
	 */
	for (i = 0; i < *size; i++) {
	    for (k = 0; k < 3; k++) {
		if (scale_coordinate(fp[3 * i + k], *precision, &lip[k]) == 0) {
		    fprintf(stderr, "xdr3dfcoord: coordinate %d of atom %d (%g) "
			    "is not finite or too large for precision %g\n",
			    k, i, (double) fp[3 * i + k], (double) *precision);
		    return 0;
		}
		if (lip[k] < minint[k]) minint[k] = lip[k];
		if (lip[k] > maxint[k]) maxint[k] = lip[k];
	    }
	    if (i > 0) {
		diff = wrapped_manhattan_distance(lip, lip - 3);
		if (diff < mindiff)
		    mindiff = diff;
	    }
	    lip += 3;
	}
	/* Offsets from minint are encoded as unsigned values below
	 * 2^31, so each axis range must stay under MAXABS. The check is done
	 * in double, which is exact here. It used to subtract in float, which
	 * rounded spans within about 60 scaled units of 2^31 up to 2^31 and so
	 * refused a few frames that can in fact be stored; it never let an
	 * oversized one through.
	 */
	for (k = 0; k < 3; k++) {
	    if ((double) maxint[k] - (double) minint[k] >= MAXABS) {
		fprintf(stderr, "xdr3dfcoord: coordinates span too large a "
			"range for precision %g\n", (double) *precision);
		return 0;
	    }
	}
	/* The reader turns each integer back into a float as
	 * integer * (1 / precision), in float. For a tiny precision that
	 * overflows -- a subnormal precision, or one near FLT_MIN with
	 * coordinates near FLT_MAX -- and the frame was written successfully
	 * only to read back as inf or NaN. The extremes are at minint and
	 * maxint, so computing those two exactly as the reader does is enough.
	 */
	inv_precision = 1.0 / *precision;
	for (k = 0; k < 3; k++) {
	    float lowest = minint[k] * inv_precision;
	    float highest = maxint[k] * inv_precision;
	    if (!isfinite(lowest) || !isfinite(highest)) {
		fprintf(stderr, "xdr3dfcoord: coordinates would not read back "
			"as finite numbers at precision %g\n", (double) *precision);
		return 0;
	    }
	}

	/* The frame is valid: from here on it is written out. */
	if (xdr_int(xdrs, size) == 0 || xdr_float(xdrs, precision) == 0)
	    return 0;
	/* Write the per-axis min and max values to the stream.
	 * These are needed by the reader to reconstruct absolute
	 * coordinates from the compressed (offset-from-minimum) form.
	 */
	for (k = 0; k < 3; k++) {
	    if (xdr_int(xdrs, &(minint[k])) == 0)
		return 0;
	}
	for (k = 0; k < 3; k++) {
	    if (xdr_int(xdrs, &(maxint[k])) == 0)
		return 0;
	}
	/* Unsigned: the span can exceed INT_MAX, and on read min/max come
	 * straight from the file.
	 */
	sizeint[0] = (unsigned int)maxint[0] - (unsigned int)minint[0] + 1;
	sizeint[1] = (unsigned int)maxint[1] - (unsigned int)minint[1] + 1;
	sizeint[2] = (unsigned int)maxint[2] - (unsigned int)minint[2] + 1;
	
	/* check if one of the sizes is to big to be multiplied */
	if ((sizeint[0] | sizeint[1] | sizeint[2] ) > 0xffffff) {
	    bitsizeint[0] = sizeofint(sizeint[0]);
	    bitsizeint[1] = sizeofint(sizeint[1]);
	    bitsizeint[2] = sizeofint(sizeint[2]);
	    bitsize = 0; /* flag the use of large sizes */
	} else {
	    bitsize = sizeofints(3, sizeint);
	}
	lip = ip;
	luip = (unsigned int *) ip;
	/* Choose the initial compression level (smallidx) based on the
	 * minimum difference between successive coordinates. This picks
	 * the smallest magicints entry that can represent the typical
	 * inter-coordinate difference, giving the best initial compression.
	 */
	smallidx = FIRSTIDX;
	while (smallidx < LASTIDX - 1 && magicints[smallidx] < mindiff) {
	    smallidx++;
	}
	if (xdr_int(xdrs, &smallidx) == 0)
	    return 0;
	/* Clamp to the last valid entry: LASTIDX is the table's element
	 * count, so magicints[LASTIDX] is one past the end.
	 */
	maxidx = MIN(LASTIDX - 1, smallidx + 8) ;
	minidx = maxidx - 8; /* often this equal smallidx */
	smaller = magicints[MAX(FIRSTIDX, smallidx-1)] / 2;
	small = magicints[smallidx] / 2;
	sizesmall[0] = sizesmall[1] = sizesmall[2] = magicints[smallidx];
	larger = magicints[maxidx] / 2;
	/* PASS 2: Encode integer coordinates into the bit-packing buffer.
	 * For each coordinate triple:
	 *   1. Write the absolute position (offset from minint) using
	 *      either per-axis bits or combined multi-int encoding.
	 *   2. Check if the next coordinate is "small" (close to this one).
	 *      If so, start a run of difference-encoded coordinates.
	 *   3. For water molecules, swap atom order (H-O-H instead of
	 *      O-H-H) to reduce differences and improve compression.
	 *   4. Adaptively adjust the compression level (smallidx) up
	 *      or down based on whether differences fit the current window.
	 */
	i = 0;
	while (i < *size) {
	    is_small = 0;
	    thiscoord = (int *)(luip) + i * 3;
	    if (smallidx < maxidx && i >= 1 &&
		    abs(thiscoord[0] - prevcoord[0]) < larger &&
		    abs(thiscoord[1] - prevcoord[1]) < larger &&
		    abs(thiscoord[2] - prevcoord[2]) < larger) {
		is_smaller = 1;
	    } else if (smallidx > minidx) {
		is_smaller = -1;
	    } else {
		is_smaller = 0;
	    }
	    if (i + 1 < *size) {
		if (abs(thiscoord[0] - thiscoord[3]) < small &&
			abs(thiscoord[1] - thiscoord[4]) < small &&
			abs(thiscoord[2] - thiscoord[5]) < small) {
		    /* interchange first with second atom for better
		     * compression of water molecules
		     */
		    tmp = thiscoord[0]; thiscoord[0] = thiscoord[3];
			thiscoord[3] = tmp;
		    tmp = thiscoord[1]; thiscoord[1] = thiscoord[4];
			thiscoord[4] = tmp;
		    tmp = thiscoord[2]; thiscoord[2] = thiscoord[5];
			thiscoord[5] = tmp;
		    is_small = 1;
		}
    
	    }
	    /* Offset from the per-axis minimum, in unsigned arithmetic. The
	     * range check above guarantees it is below 2^31.
	     */
	    tmpcoord[0] = (unsigned int)thiscoord[0] - (unsigned int)minint[0];
	    tmpcoord[1] = (unsigned int)thiscoord[1] - (unsigned int)minint[1];
	    tmpcoord[2] = (unsigned int)thiscoord[2] - (unsigned int)minint[2];
	    if (bitsize == 0) {
		sendbits(buf, bitsizeint[0], tmpcoord[0]);
		sendbits(buf, bitsizeint[1], tmpcoord[1]);
		sendbits(buf, bitsizeint[2], tmpcoord[2]);
	    } else {
		sendints(buf, 3, bitsize, sizeint, tmpcoord);
	    }
	    prevcoord[0] = thiscoord[0];
	    prevcoord[1] = thiscoord[1];
	    prevcoord[2] = thiscoord[2];
	    thiscoord = thiscoord + 3;
	    i++;
	    
	    run = 0;
	    if (is_small == 0 && is_smaller == -1)
		is_smaller = 0;
	    while (is_small && run < 8*3) {
		/* Only step down a level if this difference also fits the
		 * finer one. Both sides wrap as the original int arithmetic
		 * did; see wrapped_sqr_distance() for why that is kept. */
		if (is_smaller == -1 &&
			wrapped_sqr_distance(thiscoord, prevcoord) >=
			wrapped_int((unsigned int) smaller * (unsigned int) smaller)) {
		    is_smaller = 0;
		}

		tmpcoord[run++] = thiscoord[0] - prevcoord[0] + small;
		tmpcoord[run++] = thiscoord[1] - prevcoord[1] + small;
		tmpcoord[run++] = thiscoord[2] - prevcoord[2] + small;
		
		prevcoord[0] = thiscoord[0];
		prevcoord[1] = thiscoord[1];
		prevcoord[2] = thiscoord[2];

		i++;
		thiscoord = thiscoord + 3;
		is_small = 0;
		if (i < *size &&
			abs(thiscoord[0] - prevcoord[0]) < small &&
			abs(thiscoord[1] - prevcoord[1]) < small &&
			abs(thiscoord[2] - prevcoord[2]) < small) {
		    is_small = 1;
		}
	    }
	    if (run != prevrun || is_smaller != 0) {
		prevrun = run;
		sendbits(buf, 1, 1); /* flag the change in run-length */
		sendbits(buf, 5, run+is_smaller+1);
	    } else {
		sendbits(buf, 1, 0); /* flag the fact that runlength did not change */
	    }
	    for (k=0; k < run; k+=3) {
		sendints(buf, 3, smallidx, sizesmall, &tmpcoord[k]);	
	    }
	    if (is_smaller != 0) {
		smallidx += is_smaller;
		if (is_smaller < 0) {
		    small = smaller;
		    smaller = magicints[smallidx-1] / 2;
		} else {
		    smaller = small;
		    small = magicints[smallidx] / 2;
		}
		sizesmall[0] = sizesmall[1] = sizesmall[2] = magicints[smallidx];
	    }
	}
	if (buf[1] != 0) buf[0]++; /* Account for any remaining partial byte */
	/* Write the compressed data: first the byte count, then the raw bytes */
	if (xdr_int(xdrs, &(buf[0])) == 0) /* buf[0] holds the length in bytes */
	    return 0;
	return xdr_opaque(xdrs, (caddr_t)&(buf[3]), (u_int)buf[0]);
    } else {
	
	/* ================================================================
	 * READ PATH: Decode compressed coordinates back to floats.
	 * The format mirrors the write path:
	 *   1. Read size and precision.
	 *   2. Read min/max ranges and reconstruct encoding parameters.
	 *   3. Read the compressed bit buffer.
	 *   4. Decode each coordinate triple, handling both absolute
	 *      and difference-encoded (run) coordinates.
	 *   5. Convert fixed-point integers back to floats.
	 * ================================================================
	 */
	
	if (xdr_int(xdrs, &lsize) == 0)
	    return 0;
	/* A mismatch is fatal, not advisory: fp is only guaranteed to hold
	 * the number of triples the caller asked for, so decoding lsize of
	 * them would run off the end of the caller's array.
	 */
	if (*size != 0 && lsize != *size) {
	    fprintf(stderr, "wrong number of coordinates in xdr3dfcoord; "
		    "%d arg vs %d in file\n", *size, lsize);
	    return 0;
	}
	if (lsize < 0 || lsize > INT_MAX / 3) {
	    fprintf(stderr, "xdr3dfcoord: bad size %d in file\n", lsize);
	    return 0;
	}
	*size = lsize;
	size3 = *size * 3;
	if (*size <= 9) {
	    return xdr_float_array(xdrs, fp, size3);
	}
	/* Every header field is checked as it is read: on a truncated file a
	 * failed read leaves its variable uninitialised, and those values
	 * used to be used regardless. A zero or non-finite precision cannot
	 * come from a valid writer and would turn every coordinate into
	 * inf or NaN below.
	 */
	if (xdr_float(xdrs, precision) == 0)
	    return 0;
	if (*precision == 0.0f || !isfinite(*precision)) {
	    fprintf(stderr, "xdr3dfcoord: invalid precision %g in file\n",
		    (double) *precision);
	    return 0;
	}
	if (ensure_buffers(*size) == 0)
	    return 0;
	ip = coord_ip;
	buf = coord_buf;
	buf[0] = buf[1] = buf[2] = 0;

	/* Read per-axis min/max used to reconstruct absolute coordinates */
	for (k = 0; k < 3; k++) {
	    if (xdr_int(xdrs, &(minint[k])) == 0)
		return 0;
	}
	for (k = 0; k < 3; k++) {
	    if (xdr_int(xdrs, &(maxint[k])) == 0)
		return 0;
	}

	/* A maximum below the minimum is impossible in a frame this library
	 * wrote. Left unchecked it yields sizeint[] == 0, and receiveints()
	 * divides by sizeint[] -- so a corrupt file would crash on SIGFPE.
	 */
	if (maxint[0] < minint[0] || maxint[1] < minint[1] ||
		maxint[2] < minint[2]) {
	    fprintf(stderr, "xdr3dfcoord: inverted coordinate range in file\n");
	    return 0;
	}

	/* Unsigned: the span can exceed INT_MAX, and on read min/max come
	 * straight from the file.
	 */
	sizeint[0] = (unsigned int)maxint[0] - (unsigned int)minint[0] + 1;
	sizeint[1] = (unsigned int)maxint[1] - (unsigned int)minint[1] + 1;
	sizeint[2] = (unsigned int)maxint[2] - (unsigned int)minint[2] + 1;

	/* The other way to get a zero divisor: min = INT_MIN and max =
	 * INT_MAX on one axis is a range of 2^32 values, which wraps sizeint
	 * to 0. No writer can produce it (it rejects ranges of MAXABS and
	 * up), so it can only be corruption.
	 */
	if (sizeint[0] == 0 || sizeint[1] == 0 || sizeint[2] == 0) {
	    fprintf(stderr, "xdr3dfcoord: coordinate range in file is too "
		    "large\n");
	    return 0;
	}

	/* check if one of the sizes is to big to be multiplied */
	if ((sizeint[0] | sizeint[1] | sizeint[2] ) > 0xffffff) {
	    bitsizeint[0] = sizeofint(sizeint[0]);
	    bitsizeint[1] = sizeofint(sizeint[1]);
	    bitsizeint[2] = sizeofint(sizeint[2]);
	    bitsize = 0; /* flag the use of large sizes */
	} else {
	    bitsize = sizeofints(3, sizeint);
	}
	
	/* smallidx indexes magicints[], so it has to be validated before use:
	 * it comes straight out of the file and a corrupt or hostile value
	 * otherwise reads (and then indexes with) memory past the table.
	 */
	if (xdr_int(xdrs, &smallidx) == 0)
	    return 0;
	if (smallidx < FIRSTIDX || smallidx >= LASTIDX) {
	    fprintf(stderr, "xdr3dfcoord: invalid compression index %d in file\n",
		    smallidx);
	    return 0;
	}
	maxidx = MIN(LASTIDX - 1, smallidx + 8) ;
	minidx = maxidx - 8; /* often this equal smallidx */
	smaller = magicints[MAX(FIRSTIDX, smallidx-1)] / 2;
	small = magicints[smallidx] / 2;
	sizesmall[0] = sizesmall[1] = sizesmall[2] = magicints[smallidx] ;
	larger = magicints[maxidx];

    	/* Read the compressed bit buffer from the stream */

	if (xdr_int(xdrs, &(buf[0])) == 0)  /* buf[0] = byte count */
	    return 0;
	/* The byte count is attacker-controlled for an untrusted file, so
	 * check it against the space actually available before letting
	 * xdr_opaque() fill the buffer. The capacity is computed in size_t:
	 * in int it overflowed for frames above about 150 million atoms.
	 */
	buf_capacity_bytes = (size_t)(coord_bufints - 3) * sizeof(*buf);
	if (buf[0] < 0 || (size_t)buf[0] > buf_capacity_bytes) {
	    fprintf(stderr, "xdr3dfcoord: compressed block of %d bytes does "
		    "not fit the buffer for %d atoms\n", buf[0], lsize);
	    return 0;
	}
	bytes_declared = (size_t)buf[0];
	if (xdr_opaque(xdrs, (caddr_t)&(buf[3]), (u_int)buf[0]) == 0)
	    return 0;
	buf[0] = buf[1] = buf[2] = 0;  /* Reset bit-unpacking state */
	
	lfp = fp;
	inv_precision = 1.0 / * precision;  /* Precompute for int-to-float conversion */
	run = 0;
	i = 0;
	lip = ip;
	/* Decode each coordinate triple from the bit buffer */
	while ( i < lsize ) {
	    thiscoord = (int *)(lip) + i * 3;

	    if (bitsize == 0) {
		thiscoord[0] = receivebits(buf, bitsizeint[0]);
		thiscoord[1] = receivebits(buf, bitsizeint[1]);
		thiscoord[2] = receivebits(buf, bitsizeint[2]);
	    } else {
		receiveints(buf, 3, bitsize, sizeint, thiscoord);
	    }
	    
	    i++;
	    /* Reconstruct the absolute coordinate. The addition is done in
	     * unsigned arithmetic because minint[] and the decoded offset
	     * both come from the file: for a valid frame the sum is in
	     * range, but a corrupt one can push it past INT_MAX, where
	     * signed overflow would be undefined behaviour.
	     */
	    thiscoord[0] = (int)((unsigned int)thiscoord[0] + (unsigned int)minint[0]);
	    thiscoord[1] = (int)((unsigned int)thiscoord[1] + (unsigned int)minint[1]);
	    thiscoord[2] = (int)((unsigned int)thiscoord[2] + (unsigned int)minint[2]);

	    prevcoord[0] = thiscoord[0];
	    prevcoord[1] = thiscoord[1];
	    prevcoord[2] = thiscoord[2];
	    
	   
	    flag = receivebits(buf, 1);
	    is_smaller = 0;
	    if (flag == 1) {
		run = receivebits(buf, 5);
		is_smaller = run % 3;
		run -= is_smaller;
		is_smaller--;
	    }
	    /* A run decodes run/3 further triples. The writer never emits a
	     * run that overshoots the frame, but a corrupt file can, and
	     * that would write past the end of both ip[] and the caller's fp[].
	     */
	    if (run < 0 || i + run / 3 > lsize) {
		fprintf(stderr, "xdr3dfcoord: run length %d overruns the "
			"%d-atom frame\n", run, lsize);
		return 0;
	    }
	    if (run > 0) {
		thiscoord += 3;
		for (k = 0; k < run; k+=3) {
		    receiveints(buf, 3, smallidx, sizesmall, thiscoord);
		    i++;
		    /* Unsigned for the same reason as the absolute case above. */
		    thiscoord[0] = (int)((unsigned int)thiscoord[0]
					 + (unsigned int)prevcoord[0] - (unsigned int)small);
		    thiscoord[1] = (int)((unsigned int)thiscoord[1]
					 + (unsigned int)prevcoord[1] - (unsigned int)small);
		    thiscoord[2] = (int)((unsigned int)thiscoord[2]
					 + (unsigned int)prevcoord[2] - (unsigned int)small);
		    if (k == 0) {
			/* interchange first with second atom for better
			 * compression of water molecules
			 */
			tmp = thiscoord[0]; thiscoord[0] = prevcoord[0];
				prevcoord[0] = tmp;
			tmp = thiscoord[1]; thiscoord[1] = prevcoord[1];
				prevcoord[1] = tmp;
			tmp = thiscoord[2]; thiscoord[2] = prevcoord[2];
				prevcoord[2] = tmp;
			*lfp++ = prevcoord[0] * inv_precision;
			*lfp++ = prevcoord[1] * inv_precision;
			*lfp++ = prevcoord[2] * inv_precision;
		    } else {
			prevcoord[0] = thiscoord[0];
			prevcoord[1] = thiscoord[1];
			prevcoord[2] = thiscoord[2];
		    }
		    *lfp++ = thiscoord[0] * inv_precision;
		    *lfp++ = thiscoord[1] * inv_precision;
		    *lfp++ = thiscoord[2] * inv_precision;
		}
	    } else {
		*lfp++ = thiscoord[0] * inv_precision;
		*lfp++ = thiscoord[1] * inv_precision;
		*lfp++ = thiscoord[2] * inv_precision;		
	    }
	    smallidx += is_smaller;
	    /* The writer keeps smallidx inside [FIRSTIDX, LASTIDX-1]; a file
	     * that walks it outside that window is corrupt, and following it
	     * would index magicints[] out of bounds.
	     */
	    if (smallidx < FIRSTIDX || smallidx >= LASTIDX) {
		fprintf(stderr, "xdr3dfcoord: compression index %d out of "
			"range in file\n", smallidx);
		return 0;
	    }
	    if (is_smaller < 0) {
		small = smaller;
		if (smallidx > FIRSTIDX) {
		    smaller = magicints[smallidx - 1] /2;
		} else {
		    smaller = 0;
		}
	    } else if (is_smaller > 0) {
		smaller = small;
		small = magicints[smallidx] / 2;
	    }
	    sizesmall[0] = sizesmall[1] = sizesmall[2] = magicints[smallidx] ;
	}
	/* buf[0] now counts the bytes the decoder actually consumed. A valid
	 * frame never needs more than it declared; a corrupt one that does
	 * was decoded partly from bytes left in the buffer by earlier frames
	 * (or never initialised), and used to come back as success. The reads
	 * themselves stay inside the allocation: no atom takes more than 102
	 * bits, and ensure_buffers() allows 14.4 bytes per atom.
	 */
	if ((size_t)buf[0] > bytes_declared) {
	    fprintf(stderr, "xdr3dfcoord: compressed block of %d bytes is too "
		    "short for its %d atoms\n", (int)bytes_declared, lsize);
	    return 0;
	}
    }
    return 1;
}


   
