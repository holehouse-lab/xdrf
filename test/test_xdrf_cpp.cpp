/*____________________________________________________________________________
 |
 | test_xdrf_cpp.cpp - Comprehensive test suite for the xdrf C++ API.
 |
 | Tests xdrf::XdrFile wrapper including RAII, typed read/write methods,
 | move semantics, exception handling, and xdr3dfcoord round-trips.
 |
 | Exit code: 0 if all tests pass, 1 if any test fails.
 |
*/

#include <climits>
#include <cmath>
#include <csignal>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <stdexcept>
#include <string>
#include <utility>
#include <vector>
#include <sys/resource.h>
#include <sys/wait.h>
#include <unistd.h>

#include "../xdrf.hpp"

/* ---------- Minimal test framework ---------- */

static int tests_run = 0;
static int tests_passed = 0;
static int tests_failed = 0;

#define ASSERT_MSG(cond, msg) do { \
    tests_run++; \
    if (!(cond)) { \
        fprintf(stderr, "  FAIL: %s (line %d): %s\n", __func__, __LINE__, msg); \
        tests_failed++; \
        return 1; \
    } else { tests_passed++; } \
} while(0)

#define ASSERT_INT_EQ(a, b) do { \
    int _a = (a), _b = (b); \
    tests_run++; \
    if (_a != _b) { \
        fprintf(stderr, "  FAIL: %s (line %d): expected %d, got %d\n", \
                __func__, __LINE__, _b, _a); \
        tests_failed++; \
        return 1; \
    } else { tests_passed++; } \
} while(0)

#define ASSERT_FLOAT_EQ(a, b, eps) do { \
    float _a = (a), _b = (b); \
    tests_run++; \
    if (!(std::fabs(_a - _b) <= eps)) {  /* written so that NaN fails */ \
        fprintf(stderr, "  FAIL: %s (line %d): expected %f, got %f (eps=%e)\n", \
                __func__, __LINE__, (double)_b, (double)_a, (double)eps); \
        tests_failed++; \
        return 1; \
    } else { tests_passed++; } \
} while(0)

#define ASSERT_DOUBLE_EQ(a, b, eps) do { \
    double _a = (a), _b = (b); \
    tests_run++; \
    if (!(std::fabs(_a - _b) <= eps)) {  /* written so that NaN fails */ \
        fprintf(stderr, "  FAIL: %s (line %d): expected %f, got %f (eps=%e)\n", \
                __func__, __LINE__, _b, _a, eps); \
        tests_failed++; \
        return 1; \
    } else { tests_passed++; } \
} while(0)

#define ASSERT_THROWS(expr, exc_type) do { \
    tests_run++; \
    bool caught = false; \
    try { expr; } catch (const exc_type &) { caught = true; } \
    if (!caught) { \
        fprintf(stderr, "  FAIL: %s (line %d): expected exception\n", \
                __func__, __LINE__); \
        tests_failed++; \
        return 1; \
    } else { tests_passed++; } \
} while(0)

#define RUN_TEST(fn) do { \
    int _r; \
    fprintf(stderr, "  %s ... ", #fn); \
    _r = fn(); \
    if (_r == 0) fprintf(stderr, "ok\n"); \
    else fprintf(stderr, "\n"); \
} while(0)

static void cleanup(const char *path) { unlink(path); }


/* ================================================================
 * TEST: Construction / RAII
 * ================================================================ */

static int test_open_close_raii(void) {
    const char *f = "tmp_cpp_raii.xdr";
    {
        xdrf::XdrFile out(f, "w");
        ASSERT_MSG(out.is_open(), "file should be open after construction");
        ASSERT_MSG(out.id() != 0, "id should be nonzero");
    } /* destructor closes */
    /* Verify we can reopen (file was properly closed) */
    {
        xdrf::XdrFile in(f, "r");
        ASSERT_MSG(in.is_open(), "should reopen successfully");
    }
    cleanup(f);
    return 0;
}

static int test_explicit_close(void) {
    const char *f = "tmp_cpp_close.xdr";
    xdrf::XdrFile out(f, "w");
    out.close();
    ASSERT_MSG(!out.is_open(), "should be closed after close()");
    /* Double close is safe */
    out.close();
    ASSERT_MSG(!out.is_open(), "still closed after second close()");
    cleanup(f);
    return 0;
}

static int test_open_nonexistent(void) {
    ASSERT_THROWS(
        xdrf::XdrFile bad("/nonexistent/path/file.xdr", "r"),
        std::runtime_error
    );
    return 0;
}

static int test_move_semantics(void) {
    const char *f = "tmp_cpp_move.xdr";
    xdrf::XdrFile a(f, "w");
    a.write_int(42);

    /* Move construct */
    xdrf::XdrFile b(std::move(a));
    ASSERT_MSG(b.is_open(), "moved-to should be open");
    ASSERT_MSG(!a.is_open(), "moved-from should be closed");
    b.write_int(99);
    b.close();

    /* Verify both values were written */
    xdrf::XdrFile in(f, "r");
    ASSERT_INT_EQ(in.read_int(), 42);
    ASSERT_INT_EQ(in.read_int(), 99);
    in.close();
    cleanup(f);
    return 0;
}

static int test_move_assign(void) {
    const char *f1 = "tmp_cpp_ma1.xdr";
    const char *f2 = "tmp_cpp_ma2.xdr";
    xdrf::XdrFile a(f1, "w");
    a.write_int(1);
    xdrf::XdrFile b(f2, "w");
    b.write_int(2);

    /* Move assign: b's old file should be closed, b now owns a's file */
    b = std::move(a);
    ASSERT_MSG(b.is_open(), "b should be open after move assign");
    ASSERT_MSG(!a.is_open(), "a should be closed after move assign");
    b.write_int(3);
    b.close();

    xdrf::XdrFile in(f1, "r");
    ASSERT_INT_EQ(in.read_int(), 1);
    ASSERT_INT_EQ(in.read_int(), 3);
    in.close();
    cleanup(f1);
    cleanup(f2);
    return 0;
}

static int test_operations_on_closed(void) {
    const char *f = "tmp_cpp_closed.xdr";
    xdrf::XdrFile out(f, "w");
    out.close();
    ASSERT_THROWS(out.write_int(1), std::runtime_error);
    ASSERT_THROWS(out.read_int(), std::runtime_error);
    cleanup(f);
    return 0;
}


/* ================================================================
 * TEST: Primitive round-trips
 * ================================================================ */

static int test_int_roundtrip(void) {
    const char *f = "tmp_cpp_int.xdr";
    int values[] = {0, 1, -1, 42, -999, 2147483647, -2147483647};
    int n = sizeof(values) / sizeof(values[0]);
    {
        xdrf::XdrFile out(f, "w");
        for (int i = 0; i < n; i++) out.write_int(values[i]);
    }
    {
        xdrf::XdrFile in(f, "r");
        for (int i = 0; i < n; i++) ASSERT_INT_EQ(in.read_int(), values[i]);
    }
    cleanup(f);
    return 0;
}

static int test_float_roundtrip(void) {
    const char *f = "tmp_cpp_float.xdr";
    float values[] = {0.0f, 1.5f, -3.14f, 1.0e10f, -1.0e-10f};
    int n = sizeof(values) / sizeof(values[0]);
    {
        xdrf::XdrFile out(f, "w");
        for (int i = 0; i < n; i++) out.write_float(values[i]);
    }
    {
        xdrf::XdrFile in(f, "r");
        for (int i = 0; i < n; i++)
            ASSERT_FLOAT_EQ(in.read_float(), values[i], 1e-15f);
    }
    cleanup(f);
    return 0;
}

static int test_double_roundtrip(void) {
    const char *f = "tmp_cpp_double.xdr";
    double values[] = {0.0, 1.23456789012345, -9.87654321e100, 1.0e-300};
    int n = sizeof(values) / sizeof(values[0]);
    {
        xdrf::XdrFile out(f, "w");
        for (int i = 0; i < n; i++) out.write_double(values[i]);
    }
    {
        xdrf::XdrFile in(f, "r");
        for (int i = 0; i < n; i++)
            ASSERT_DOUBLE_EQ(in.read_double(), values[i], 1e-15);
    }
    cleanup(f);
    return 0;
}

static int test_short_roundtrip(void) {
    const char *f = "tmp_cpp_short.xdr";
    short values[] = {0, 1, -1, 32767, -32768, 12345};
    int n = sizeof(values) / sizeof(values[0]);
    {
        xdrf::XdrFile out(f, "w");
        for (int i = 0; i < n; i++) out.write_short(values[i]);
    }
    {
        xdrf::XdrFile in(f, "r");
        for (int i = 0; i < n; i++) {
            short v = in.read_short();
            tests_run++;
            if (v != values[i]) {
                fprintf(stderr, "  FAIL: expected %d, got %d\n", values[i], v);
                tests_failed++;
                return 1;
            } else { tests_passed++; }
        }
    }
    cleanup(f);
    return 0;
}

static int test_char_roundtrip(void) {
    const char *f = "tmp_cpp_char.xdr";
    char values[] = {'A', 'z', '0', ' ', '\n'};
    int n = sizeof(values) / sizeof(values[0]);
    {
        xdrf::XdrFile out(f, "w");
        for (int i = 0; i < n; i++) out.write_char(values[i]);
    }
    {
        xdrf::XdrFile in(f, "r");
        for (int i = 0; i < n; i++) {
            char v = in.read_char();
            tests_run++;
            if (v != values[i]) {
                fprintf(stderr, "  FAIL: expected '%c', got '%c'\n",
                        values[i], v);
                tests_failed++;
                return 1;
            } else { tests_passed++; }
        }
    }
    cleanup(f);
    return 0;
}

static int test_bool_roundtrip(void) {
    const char *f = "tmp_cpp_bool.xdr";
    {
        xdrf::XdrFile out(f, "w");
        out.write_bool(true);
        out.write_bool(false);
        out.write_bool(true);
    }
    {
        xdrf::XdrFile in(f, "r");
        ASSERT_MSG(in.read_bool() == true, "first bool should be true");
        ASSERT_MSG(in.read_bool() == false, "second bool should be false");
        ASSERT_MSG(in.read_bool() == true, "third bool should be true");
    }
    cleanup(f);
    return 0;
}

static int test_string_roundtrip(void) {
    const char *f = "tmp_cpp_string.xdr";
    std::string s1 = "Hello, XDR!";
    std::string s2 = "";
    std::string s3 = "A somewhat longer test string with numbers 12345 and symbols !@#$%";
    {
        xdrf::XdrFile out(f, "w");
        out.write_string(s1);
        out.write_string(s2);
        out.write_string(s3);
    }
    {
        xdrf::XdrFile in(f, "r");
        ASSERT_MSG(in.read_string() == s1, "first string mismatch");
        ASSERT_MSG(in.read_string() == s2, "empty string mismatch");
        ASSERT_MSG(in.read_string() == s3, "third string mismatch");
    }
    cleanup(f);
    return 0;
}

static int test_mixed_types(void) {
    const char *f = "tmp_cpp_mixed.xdr";
    {
        xdrf::XdrFile out(f, "w");
        out.write_int(42);
        out.write_float(3.14f);
        out.write_double(2.71828);
        out.write_short(static_cast<short>(-100));
        out.write_char('X');
        out.write_bool(true);
        out.write_string("mixed test");
    }
    {
        xdrf::XdrFile in(f, "r");
        ASSERT_INT_EQ(in.read_int(), 42);
        ASSERT_FLOAT_EQ(in.read_float(), 3.14f, 1e-6f);
        ASSERT_DOUBLE_EQ(in.read_double(), 2.71828, 1e-10);
        short s = in.read_short();
        tests_run++;
        if (s != -100) { tests_failed++; return 1; } else { tests_passed++; }
        char c = in.read_char();
        tests_run++;
        if (c != 'X') { tests_failed++; return 1; } else { tests_passed++; }
        ASSERT_MSG(in.read_bool() == true, "bool mismatch");
        ASSERT_MSG(in.read_string() == "mixed test", "string mismatch");
    }
    cleanup(f);
    return 0;
}


/* ================================================================
 * TEST: xdr3dfcoord
 * ================================================================ */

static int test_3dfcoord_vector(void) {
    const char *f = "tmp_cpp_3df_vec.xdr";
    std::vector<float> coords = {
        1.0f, 2.0f, 3.0f,
        4.5f, 5.5f, 6.5f,
        -1.0f, -2.0f, -3.0f
    };
    float prec = 1000.0f;
    {
        xdrf::XdrFile out(f, "w");
        out.write_3dfcoord(coords, prec);
    }
    {
        xdrf::XdrFile in(f, "r");
        auto [result, rprec] = in.read_3dfcoord();
        ASSERT_INT_EQ(static_cast<int>(result.size()), 9);
        /* <10 atoms: xdr3dfcoord uses uncompressed mode, precision not stored */
        for (int i = 0; i < 9; i++)
            ASSERT_FLOAT_EQ(result[i], coords[i], 0.002f);
    }
    cleanup(f);
    return 0;
}

static int test_3dfcoord_rawptr(void) {
    const char *f = "tmp_cpp_3df_raw.xdr";
    int natoms = 5;
    float coords[15], coords2[15];
    float prec = 1000.0f;
    for (int i = 0; i < 15; i++)
        coords[i] = static_cast<float>(i) * 0.123f;
    {
        xdrf::XdrFile out(f, "w");
        out.write_3dfcoord(coords, natoms, prec);
    }
    {
        xdrf::XdrFile in(f, "r");
        float rprec = 0;
        int rnatoms = 0; /* 0 = accept whatever count is in the file */
        in.read_3dfcoord(coords2, rnatoms, rprec);
        ASSERT_INT_EQ(rnatoms, natoms);
        /* <10 atoms: xdr3dfcoord uses uncompressed mode, precision not stored */
        for (int i = 0; i < 15; i++)
            ASSERT_FLOAT_EQ(coords2[i], coords[i], 0.002f);
    }
    cleanup(f);
    return 0;
}

static int test_3dfcoord_100_atoms(void) {
    const char *f = "tmp_cpp_3df_100.xdr";
    int natoms = 100;
    std::vector<float> coords(natoms * 3);
    float prec = 1000.0f;
    for (int i = 0; i < natoms * 3; i++)
        coords[i] = static_cast<float>(i % 50) * 0.1f - 2.5f;
    {
        xdrf::XdrFile out(f, "w");
        out.write_3dfcoord(coords, prec);
    }
    {
        xdrf::XdrFile in(f, "r");
        auto [result, rprec] = in.read_3dfcoord();
        ASSERT_INT_EQ(static_cast<int>(result.size()), natoms * 3);
        for (int i = 0; i < natoms * 3; i++)
            ASSERT_FLOAT_EQ(result[i], coords[i], 0.002f);
    }
    cleanup(f);
    return 0;
}

static int test_3dfcoord_1000_atoms(void) {
    const char *f = "tmp_cpp_3df_1k.xdr";
    int natoms = 1000;
    std::vector<float> coords(natoms * 3);
    float prec = 1000.0f;
    for (int i = 0; i < natoms; i++) {
        coords[i * 3]     = static_cast<float>(i % 10) * 0.5f;
        coords[i * 3 + 1] = static_cast<float>((i / 10) % 10) * 0.5f;
        coords[i * 3 + 2] = static_cast<float>((i / 100) % 10) * 0.5f;
    }
    {
        xdrf::XdrFile out(f, "w");
        out.write_3dfcoord(coords, prec);
    }
    {
        xdrf::XdrFile in(f, "r");
        auto [result, rprec] = in.read_3dfcoord();
        ASSERT_INT_EQ(static_cast<int>(result.size()), natoms * 3);
        for (int i = 0; i < natoms * 3; i++)
            ASSERT_FLOAT_EQ(result[i], coords[i], 0.002f);
    }
    cleanup(f);
    return 0;
}

static int test_3dfcoord_precision(void) {
    const char *f = "tmp_cpp_3df_prec.xdr";
    std::vector<float> coords = {1.23456f, 2.34567f, 3.45678f};
    float precisions[] = {10.0f, 100.0f, 1000.0f, 10000.0f};
    float tolerances[] = {0.1f, 0.01f, 0.001f, 0.0001f};
    int np = 4;
    {
        xdrf::XdrFile out(f, "w");
        for (int p = 0; p < np; p++)
            out.write_3dfcoord(coords, precisions[p]);
    }
    {
        xdrf::XdrFile in(f, "r");
        for (int p = 0; p < np; p++) {
            auto [result, rprec] = in.read_3dfcoord();
            ASSERT_INT_EQ(static_cast<int>(result.size()), 3);
            for (int i = 0; i < 3; i++)
                ASSERT_FLOAT_EQ(result[i], coords[i], tolerances[p]);
        }
    }
    cleanup(f);
    return 0;
}

static int test_3dfcoord_bad_size(void) {
    /* coords.size() not a multiple of 3 should throw */
    const char *f = "tmp_cpp_3df_bad.xdr";
    xdrf::XdrFile out(f, "w");
    std::vector<float> bad = {1.0f, 2.0f};
    ASSERT_THROWS(out.write_3dfcoord(bad, 1000.0f), std::runtime_error);
    out.close();
    cleanup(f);
    return 0;
}


/* ================================================================
 * TEST: Multi-frame
 * ================================================================ */

static int test_multi_frame(void) {
    const char *f = "tmp_cpp_mf.xdr";
    int nframes = 5;
    int natoms = 20;
    float prec = 1000.0f;
    std::vector<std::vector<float>> frames(nframes);

    /* Generate frames with slightly different coords */
    for (int fr = 0; fr < nframes; fr++) {
        frames[fr].resize(natoms * 3);
        for (int i = 0; i < natoms * 3; i++)
            frames[fr][i] = static_cast<float>(i) * 0.01f +
                            static_cast<float>(fr) * 0.5f;
    }

    {
        xdrf::XdrFile out(f, "w");
        out.write_int(nframes);
        out.write_int(natoms);
        for (int fr = 0; fr < nframes; fr++)
            out.write_3dfcoord(frames[fr], prec);
    }
    {
        xdrf::XdrFile in(f, "r");
        ASSERT_INT_EQ(in.read_int(), nframes);
        ASSERT_INT_EQ(in.read_int(), natoms);
        for (int fr = 0; fr < nframes; fr++) {
            auto [result, rprec] = in.read_3dfcoord();
            ASSERT_INT_EQ(static_cast<int>(result.size()), natoms * 3);
            for (int i = 0; i < natoms * 3; i++)
                ASSERT_FLOAT_EQ(result[i], frames[fr][i], 0.002f);
        }
    }
    cleanup(f);
    return 0;
}


/* ================================================================
 * TEST: setpos / getpos
 * ================================================================ */

static int test_setpos_getpos(void) {
    const char *f = "tmp_cpp_pos.xdr";
    unsigned int pos_after_first;
    {
        xdrf::XdrFile out(f, "w");
        out.write_int(111);
        pos_after_first = out.getpos();
        out.write_int(222);
        out.write_int(333);
    }
    {
        xdrf::XdrFile in(f, "r");
        ASSERT_INT_EQ(in.read_int(), 111);
        in.read_int(); /* skip 222 */
        ASSERT_INT_EQ(in.read_int(), 333);
        /* Seek back to second value */
        ASSERT_MSG(in.setpos(pos_after_first), "setpos should succeed");
        ASSERT_INT_EQ(in.read_int(), 222);
    }
    cleanup(f);
    return 0;
}


/* ================================================================
 * TEST: Append mode
 * ================================================================ */

static int test_append_mode(void) {
    const char *f = "tmp_cpp_append.xdr";
    {
        xdrf::XdrFile out(f, "w");
        out.write_int(1);
    }
    {
        xdrf::XdrFile out(f, "a");
        out.write_int(2);
    }
    {
        xdrf::XdrFile in(f, "r");
        ASSERT_INT_EQ(in.read_int(), 1);
        ASSERT_INT_EQ(in.read_int(), 2);
    }
    cleanup(f);
    return 0;
}


/* ================================================================
 * TEST: Compression ratio
 * ================================================================ */

static int test_compression_ratio(void) {
    const char *f = "tmp_cpp_compress.xdr";
    int natoms = 1000;
    std::vector<float> coords(natoms * 3);
    float prec = 1000.0f;
    /* Water-like repeating pattern (highly compressible) */
    for (int i = 0; i < natoms; i++) {
        coords[i * 3]     = static_cast<float>(i % 10) * 0.3f;
        coords[i * 3 + 1] = static_cast<float>((i / 10) % 10) * 0.3f;
        coords[i * 3 + 2] = static_cast<float>(i / 100) * 0.3f;
    }
    {
        xdrf::XdrFile out(f, "w");
        out.write_3dfcoord(coords, prec);
    }
    /* Check file size is smaller than raw float data */
    FILE *fp = fopen(f, "rb");
    fseek(fp, 0, SEEK_END);
    long fsize = ftell(fp);
    fclose(fp);
    long raw_size = natoms * 3 * static_cast<long>(sizeof(float));
    ASSERT_MSG(fsize < raw_size,
               "compressed file should be smaller than raw floats");
    cleanup(f);
    return 0;
}


/* ================================================================
 * TEST: Robustness (regressions)
 * ================================================================ */

/* read_3dfcoord() peeks the atom count before reading. At the end of
 * the file it must throw and leave the stream where it was. */
static int test_read_3dfcoord_at_end(void) {
    const char *f = "tmp_cpp_eof.xdr";
    std::vector<float> coords(60);
    for (int i = 0; i < 60; i++)
        coords[i] = static_cast<float>(i) * 0.05f;
    {
        xdrf::XdrFile out(f, "w");
        out.write_3dfcoord(coords, 1000.0f);
    }
    {
        xdrf::XdrFile in(f, "r");
        auto [result, rprec] = in.read_3dfcoord();
        ASSERT_INT_EQ(static_cast<int>(result.size()), 60);
        unsigned int at_end = in.getpos();
        ASSERT_THROWS(in.read_3dfcoord(), std::runtime_error);
        ASSERT_MSG(in.getpos() == at_end, "a failed peek must not move the stream");
    }
    cleanup(f);
    return 0;
}

/* xdr_string stops at the first NUL, so the tail would be lost silently */
static int test_write_string_rejects_nul(void) {
    const char *f = "tmp_cpp_nul.xdr";
    xdrf::XdrFile out(f, "w");
    std::string with_nul("ab\0cd", 5);
    ASSERT_THROWS(out.write_string(with_nul), std::runtime_error);
    out.close();
    cleanup(f);
    return 0;
}

/* write_* on a read stream used to read instead (write_3dfcoord even into
 * the caller's const vector), and read_* on a write stream used to write */
static int test_direction_enforced(void) {
    const char *f = "tmp_cpp_direction.xdr";
    std::vector<float> coords(60);
    for (int i = 0; i < 60; i++)
        coords[i] = static_cast<float>(i) * 0.05f;
    {
        xdrf::XdrFile out(f, "w");
        out.write_3dfcoord(coords, 1000.0f);
        out.write_int(7);
    }
    {
        xdrf::XdrFile in(f, "r");
        const std::vector<float> mine(60, 5.0f);
        ASSERT_THROWS(in.write_3dfcoord(mine, 1000.0f), std::runtime_error);
        ASSERT_FLOAT_EQ(mine[3], 5.0f, 0.0f);
        ASSERT_THROWS(in.write_int(99), std::runtime_error);
        /* nothing was consumed: the frame and the int are still there */
        auto [result, rprec] = in.read_3dfcoord();
        ASSERT_INT_EQ(static_cast<int>(result.size()), 60);
        ASSERT_INT_EQ(in.read_int(), 7);
    }
    {
        xdrf::XdrFile out(f, "w");
        ASSERT_THROWS(out.read_int(), std::runtime_error);
        ASSERT_THROWS(out.read_3dfcoord(), std::runtime_error);
        out.close();
    }
    FILE *fp = fopen(f, "rb");
    ASSERT_MSG(fp != nullptr, "file should exist");
    fseek(fp, 0, SEEK_END);
    long bytes = ftell(fp);
    fclose(fp);
    ASSERT_MSG(bytes == 0, "a read on a write stream must not write");
    cleanup(f);
    return 0;
}

/* The atom count is peeked from the file and used to size the vector; a
 * corrupt one used to be allocated unchecked (std::bad_alloc, not
 * std::runtime_error, for a large one) */
static int test_read_3dfcoord_bad_count(void) {
    const char *f = "tmp_cpp_badcount.xdr";
    const int counts[] = {-16, INT_MAX};
    for (int c = 0; c < 2; c++) {
        {
            xdrf::XdrFile out(f, "w");
            out.write_int(counts[c]);
            for (int i = 0; i < 16; i++)
                out.write_int(0);
        }
        xdrf::XdrFile in(f, "r");
        ASSERT_THROWS(in.read_3dfcoord(), std::runtime_error);
    }
    cleanup(f);
    return 0;
}

/* "W" is a documented write mode; xdr3dfcoord used to treat it as read */
static int test_uppercase_mode_3dfcoord(void) {
    const char *f = "tmp_cpp_upper.xdr";
    std::vector<float> coords(60);
    for (int i = 0; i < 60; i++)
        coords[i] = static_cast<float>(i) * 0.03f;
    {
        xdrf::XdrFile out(f, "W");
        out.write_3dfcoord(coords, 1000.0f);
    }
    {
        xdrf::XdrFile in(f, "r");
        auto [result, rprec] = in.read_3dfcoord();
        ASSERT_INT_EQ(static_cast<int>(result.size()), 60);
        for (int i = 0; i < 60; i++)
            ASSERT_FLOAT_EQ(result[i], coords[i], 0.001f);
    }
    cleanup(f);
    return 0;
}

/* close() must surface a write that only fails at the final flush. A
 * file-size limit stands in for a full disk, in a child process so the
 * limit stays out of the other tests. */
static int test_close_reports_write_error(void) {
    const char *f = "tmp_cpp_efbig.xdr";
    pid_t child = fork();
    ASSERT_MSG(child >= 0, "fork should succeed");
    if (child == 0) {
        struct rlimit rl;
        rl.rlim_cur = rl.rlim_max = 1000;
        signal(SIGXFSZ, SIG_IGN);  /* get EFBIG instead of being killed */
        setrlimit(RLIMIT_FSIZE, &rl);
        xdrf::XdrFile out(f, "w");
        for (int i = 0; i < 500; i++)  /* 2000 bytes, twice the limit */
            out.write_int(i);
        try {
            out.close();
        } catch (const std::runtime_error &) {
            _exit(0);  /* expected */
        }
        _exit(1);
    }
    int status = -1;
    waitpid(child, &status, 0);
    ASSERT_MSG(WIFEXITED(status), "child should exit normally");
    ASSERT_INT_EQ(WEXITSTATUS(status), 0);
    cleanup(f);
    return 0;
}


/* ================================================================
 * main
 * ================================================================ */

int main() {
    fprintf(stderr, "\n=== xdrf C++ API test suite ===\n\n");

    fprintf(stderr, "--- Construction / RAII ---\n");
    RUN_TEST(test_open_close_raii);
    RUN_TEST(test_explicit_close);
    RUN_TEST(test_open_nonexistent);
    RUN_TEST(test_move_semantics);
    RUN_TEST(test_move_assign);
    RUN_TEST(test_operations_on_closed);

    fprintf(stderr, "\n--- Primitive round-trips ---\n");
    RUN_TEST(test_int_roundtrip);
    RUN_TEST(test_float_roundtrip);
    RUN_TEST(test_double_roundtrip);
    RUN_TEST(test_short_roundtrip);
    RUN_TEST(test_char_roundtrip);
    RUN_TEST(test_bool_roundtrip);
    RUN_TEST(test_string_roundtrip);
    RUN_TEST(test_mixed_types);

    fprintf(stderr, "\n--- xdr3dfcoord ---\n");
    RUN_TEST(test_3dfcoord_vector);
    RUN_TEST(test_3dfcoord_rawptr);
    RUN_TEST(test_3dfcoord_100_atoms);
    RUN_TEST(test_3dfcoord_1000_atoms);
    RUN_TEST(test_3dfcoord_precision);
    RUN_TEST(test_3dfcoord_bad_size);

    fprintf(stderr, "\n--- Advanced ---\n");
    RUN_TEST(test_multi_frame);
    RUN_TEST(test_setpos_getpos);
    RUN_TEST(test_append_mode);
    RUN_TEST(test_compression_ratio);

    fprintf(stderr, "\n--- Robustness (regressions) ---\n");
    RUN_TEST(test_read_3dfcoord_at_end);
    RUN_TEST(test_write_string_rejects_nul);
    RUN_TEST(test_uppercase_mode_3dfcoord);
    RUN_TEST(test_close_reports_write_error);
    RUN_TEST(test_direction_enforced);
    RUN_TEST(test_read_3dfcoord_bad_count);

    fprintf(stderr, "\n=== Results: %d passed, %d failed, %d total ===\n\n",
            tests_passed, tests_failed, tests_run);

    return tests_failed > 0 ? 1 : 0;
}
