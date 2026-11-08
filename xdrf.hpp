/*_________________________________________________________________
 |
 | xdrf.hpp - C++ header-only wrapper for the xdrf library.
 |
 | Provides an RAII-based XdrFile class that wraps xdropen/xdrclose
 | and exposes typed read/write methods for XDR primitives and
 | compressed 3D coordinates.
 |
 | Usage:
 |   #include "xdrf.hpp"
 |
 |   // Write
 |   xdrf::XdrFile out("data.xdr", "w");
 |   out.write_int(42);
 |   out.write_float(3.14f);
 |   std::vector<float> coords = {1.0f, 2.0f, 3.0f, 4.0f, 5.0f, 6.0f};
 |   out.write_3dfcoord(coords, 1000.0f);
 |   out.close();   // or let destructor handle it
 |
 |   // Read
 |   xdrf::XdrFile in("data.xdr", "r");
 |   int val = in.read_int();
 |   float fval = in.read_float();
 |   auto [atoms, prec] = in.read_3dfcoord();
 |
 | The class is non-copyable but movable. All read/write methods
 | throw std::runtime_error on failure, including a write_* call on a
 | file opened for reading or a read_* call on one opened for writing.
 |
 | Link against libxdrf.a -lm (same as the C interface).
 |
*/

#ifndef XDRF_HPP
#define XDRF_HPP

#include <climits>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <memory>
#include <new>
#include <stdexcept>
#include <string>
#include <utility>
#include <vector>

#include <rpc/rpc.h>
#include <rpc/xdr.h>

/* Pull in the C API */
extern "C" {
#include "xdrf.h"
}

namespace xdrf {

/*_________________________________________________________________
 |
 | XdrFile - RAII wrapper around the xdrf C API.
 |
 | Opens an XDR file on construction, closes on destruction.
 | Provides typed read/write methods for all XDR primitives
 | and for compressed 3D coordinates via xdr3dfcoord.
 |
*/
class XdrFile {
public:
    /* Open an XDR file.
     * mode: "w" = write, "r" = read, "a" = append.
     * Throws std::runtime_error if the file cannot be opened. */
    XdrFile(const std::string &filename, const std::string &mode)
        : xdr_(new XDR), id_(0), open_(false)
    {
        id_ = xdropen(xdr_.get(), filename.c_str(), mode.c_str());
        if (id_ == 0) {
            throw std::runtime_error("xdropen failed: " + filename);
        }
        open_ = true;
    }

    /* A destructor cannot throw, so an I/O error found while flushing here
     * is only reported on stderr (by xdrclose). Call close() yourself
     * after writing if you need to act on it. */
    ~XdrFile() {
        if (open_) {
            xdrclose(xdr_.get());
        }
    }

    /* Non-copyable */
    XdrFile(const XdrFile &) = delete;
    XdrFile &operator=(const XdrFile &) = delete;

    /* Movable */
    XdrFile(XdrFile &&other) noexcept
        : xdr_(std::move(other.xdr_)), id_(other.id_), open_(other.open_)
    {
        other.open_ = false;
        other.id_ = 0;
    }

    XdrFile &operator=(XdrFile &&other) noexcept {
        if (this != &other) {
            if (open_) xdrclose(xdr_.get());
            xdr_ = std::move(other.xdr_);
            id_ = other.id_;
            open_ = other.open_;
            other.open_ = false;
            other.id_ = 0;
        }
        return *this;
    }

    /* Close the file explicitly. Safe to call multiple times.
     * Throws std::runtime_error if flushing or closing the file failed
     * (e.g. disk full), in which case written data may be incomplete. The
     * file is closed either way. */
    void close() {
        if (!open_)
            return;
        open_ = false;
        id_ = 0;
        if (!xdrclose(xdr_.get()))
            throw std::runtime_error("xdrclose failed: written data may be incomplete");
    }

    /* Returns true if the file is currently open. */
    bool is_open() const { return open_; }

    /* Returns the xdrid handle. */
    int id() const { return id_; }

    /* Access the underlying XDR struct (for advanced use). */
    XDR *xdr() { return xdr_.get(); }

    /* ---- Primitive write methods ---- */

    void write_int(int val) {
        check_writing();
        if (!xdr_int(xdr_.get(), &val))
            throw std::runtime_error("xdr_int write failed");
    }

    void write_float(float val) {
        check_writing();
        if (!xdr_float(xdr_.get(), &val))
            throw std::runtime_error("xdr_float write failed");
    }

    void write_double(double val) {
        check_writing();
        if (!xdr_double(xdr_.get(), &val))
            throw std::runtime_error("xdr_double write failed");
    }

    void write_short(short val) {
        check_writing();
        if (!xdr_short(xdr_.get(), &val))
            throw std::runtime_error("xdr_short write failed");
    }

    void write_char(char val) {
        check_writing();
        if (!xdr_char(xdr_.get(), &val))
            throw std::runtime_error("xdr_char write failed");
    }

    void write_bool(bool val) {
        check_writing();
        bool_t bval = val ? TRUE : FALSE;
        if (!xdr_bool(xdr_.get(), &bval))
            throw std::runtime_error("xdr_bool write failed");
    }

    void write_string(const std::string &val) {
        check_writing();
        /* xdr_string stops at the first NUL, so anything after one would
         * be dropped without an error. */
        if (val.find('\0') != std::string::npos)
            throw std::runtime_error("xdr_string cannot store a string containing NUL");
        /* xdr_string needs a char* (it won't modify on encode) */
        char *buf = const_cast<char *>(val.c_str());
        unsigned int maxlen = static_cast<unsigned int>(val.size() + 1);
        if (!xdr_string(xdr_.get(), &buf, maxlen))
            throw std::runtime_error("xdr_string write failed");
    }

    /* ---- Primitive read methods ---- */

    int read_int() {
        check_reading();
        int val = 0;
        if (!xdr_int(xdr_.get(), &val))
            throw std::runtime_error("xdr_int read failed");
        return val;
    }

    float read_float() {
        check_reading();
        float val = 0;
        if (!xdr_float(xdr_.get(), &val))
            throw std::runtime_error("xdr_float read failed");
        return val;
    }

    double read_double() {
        check_reading();
        double val = 0;
        if (!xdr_double(xdr_.get(), &val))
            throw std::runtime_error("xdr_double read failed");
        return val;
    }

    short read_short() {
        check_reading();
        short val = 0;
        if (!xdr_short(xdr_.get(), &val))
            throw std::runtime_error("xdr_short read failed");
        return val;
    }

    char read_char() {
        check_reading();
        char val = 0;
        if (!xdr_char(xdr_.get(), &val))
            throw std::runtime_error("xdr_char read failed");
        return val;
    }

    bool read_bool() {
        check_reading();
        bool_t val = FALSE;
        if (!xdr_bool(xdr_.get(), &val))
            throw std::runtime_error("xdr_bool read failed");
        return val != FALSE;
    }

    /* maxlen is the longest string accepted; a longer one in the file
     * makes the read fail. Pass a larger value to read longer strings. */
    std::string read_string(unsigned int maxlen = 4096) {
        check_reading();
        char *buf = nullptr;
        /* xdr_string allocates buf on decode; it can allocate and then
         * fail, so release it on the error path too. */
        if (!xdr_string(xdr_.get(), &buf, maxlen)) {
            std::free(buf);
            throw std::runtime_error("xdr_string read failed");
        }
        std::string result(buf ? buf : "");
        std::free(buf);
        return result;
    }

    /* ---- 3D coordinate methods ---- */

    /* Write compressed 3D coordinates.
     * coords:    flat array of 3*num_atoms floats (x,y,z triples).
     * precision: float-to-fixed-point multiplier (e.g. 1000.0f). */
    void write_3dfcoord(const std::vector<float> &coords, float precision) {
        check_writing();
        if (coords.size() % 3 != 0)
            throw std::runtime_error("coords size must be a multiple of 3");
        /* Without this the cast below wraps modulo 2^32 and writes a
         * different (smaller) number of atoms. */
        if (coords.size() / 3 > static_cast<size_t>(INT_MAX))
            throw std::runtime_error("too many atoms for xdr3dfcoord");
        int size = static_cast<int>(coords.size() / 3);
        /* xdr3dfcoord won't modify the data on encode, but the
         * C API takes non-const pointers */
        float *fp = const_cast<float *>(coords.data());
        if (!xdr3dfcoord(xdr_.get(), fp, &size, &precision))
            throw std::runtime_error("xdr3dfcoord write failed");
    }

    /* Write compressed 3D coordinates from a raw pointer.
     * fp:        array of 3*num_atoms floats.
     * num_atoms: number of atoms.
     * precision: float-to-fixed-point multiplier. */
    void write_3dfcoord(float *fp, int num_atoms, float precision) {
        check_writing();
        if (!xdr3dfcoord(xdr_.get(), fp, &num_atoms, &precision))
            throw std::runtime_error("xdr3dfcoord write failed");
    }

    /* Read compressed 3D coordinates.
     * Returns a pair of (coords vector, precision used). Frames of 9 or
     * fewer atoms are stored uncompressed with no precision, and give 0.
     *
     * The atom count is peeked from the frame (xdr3dfcoord_peek_size)
     * before allocating, so the buffer always matches what the file
     * actually contains. At the end of the file this throws without
     * moving the stream.
     *
     * This used to allocate a fixed 30000 floats and pass size = 0 ("accept
     * whatever count is in the file"), which silently overflowed the buffer
     * for any frame of more than 10000 atoms. Its replacement rewound with
     * xdr_getpos/xdr_setpos, whose unsigned int position wraps at 4 GiB, so
     * frames beyond that offset were read from the wrong place. */
    std::pair<std::vector<float>, float> read_3dfcoord() {
        check_reading();

        int size = 0;
        if (!xdr3dfcoord_peek_size(xdr_.get(), &size))
            throw std::runtime_error("xdr3dfcoord: could not read atom count");
        /* The count comes straight from the file, and a corrupt one used
         * to size the vector unchecked, so the call threw std::bad_alloc
         * (or std::length_error) instead of std::runtime_error. Counts
         * beyond what xdr3dfcoord accepts are refused before allocating;
         * a count it would accept but memory cannot hold is reported the
         * same way. */
        if (size < 0 || size > INT_MAX / 3)
            throw std::runtime_error("xdr3dfcoord: bad atom count in file");

        std::vector<float> coords;
        try {
            coords.resize(static_cast<size_t>(size) * 3);
        } catch (const std::bad_alloc &) {
            throw std::runtime_error("xdr3dfcoord: not enough memory for the atom count in file");
        } catch (const std::length_error &) {
            throw std::runtime_error("xdr3dfcoord: not enough memory for the atom count in file");
        }
        float precision = 0;
        if (!xdr3dfcoord(xdr_.get(), coords.data(), &size, &precision))
            throw std::runtime_error("xdr3dfcoord read failed");

        coords.resize(static_cast<size_t>(size) * 3);
        return {coords, precision};
    }

    /* Read 3D coordinates into a caller-provided buffer.
     * fp:        pre-allocated array holding at least 3*num_atoms floats.
     * num_atoms: the atom count the frame is expected to contain, or 0 to
     *            accept whatever the file says. This is a expectation, not
     *            a capacity: with 0 the library cannot tell how large fp is,
     *            so only use it when the count is known to be bounded.
     *            Throws if a nonzero value disagrees with the file.
     * precision: set on return to the precision stored in the file; left
     *            unchanged for frames of 9 or fewer atoms, which have none.
     *
     * Prefer the no-argument read_3dfcoord() overload, which sizes the
     * buffer from the file itself and cannot be given a mismatched one. */
    void read_3dfcoord(float *fp, int &num_atoms, float &precision) {
        check_reading();
        if (!xdr3dfcoord(xdr_.get(), fp, &num_atoms, &precision))
            throw std::runtime_error("xdr3dfcoord read failed");
    }

    /* ---- Position methods ----
     *
     * These use the XDR position calls, which hold the byte offset in an
     * unsigned int: they only address the first 4 GiB of a file. */

    /* Get the current stream position. */
    unsigned int getpos() {
        check_open();
        return xdr_getpos(xdr_.get());
    }

    /* Set the stream position. Returns true on success. */
    bool setpos(unsigned int pos) {
        check_open();
        return xdr_setpos(xdr_.get(), pos) != 0;
    }

private:
    std::unique_ptr<XDR> xdr_;
    int id_;
    bool open_;

    void check_open() const {
        if (!open_)
            throw std::runtime_error("XdrFile is not open");
    }

    /* XDR filters run in whichever direction the stream was opened, so
     * without these a write_* call on a read stream silently read from the
     * file instead (write_3dfcoord even read into the caller's const
     * vector), and a read_* call on a write stream silently wrote. */
    void check_writing() const {
        check_open();
        if (xdr_->x_op != XDR_ENCODE)
            throw std::runtime_error("XdrFile is open for reading, not writing");
    }

    void check_reading() const {
        check_open();
        if (xdr_->x_op != XDR_DECODE)
            throw std::runtime_error("XdrFile is open for writing, not reading");
    }
};

} /* namespace xdrf */

#endif /* XDRF_HPP */
