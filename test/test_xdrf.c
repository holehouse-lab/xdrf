/*____________________________________________________________________________
 |
 | test_xdrf.c - Comprehensive test suite for the xdrf C API.
 |
 | Tests xdropen, xdrclose, xdr3dfcoord, and the standard XDR primitives
 | accessed through xdropen-managed streams. Each test writes data to a
 | temporary XDR file, reads it back, and verifies correctness.
 |
 | Exit code: 0 if all tests pass, 1 if any test fails.
 |
*/

#include <float.h>
#include <limits.h>
#include <math.h>
#include <rpc/rpc.h>
#include <rpc/xdr.h>
#include <signal.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <sys/resource.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <unistd.h>

#include "../xdrf.h"

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
    } else { \
        tests_passed++; \
    } \
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
    if (!(fabs(_a - _b) <= eps)) {  /* written so that NaN fails */ \
        fprintf(stderr, "  FAIL: %s (line %d): expected %f, got %f (eps=%e)\n", \
                __func__, __LINE__, (double)_b, (double)_a, (double)eps); \
        tests_failed++; \
        return 1; \
    } else { tests_passed++; } \
} while(0)

#define ASSERT_DOUBLE_EQ(a, b, eps) do { \
    double _a = (a), _b = (b); \
    tests_run++; \
    if (!(fabs(_a - _b) <= eps)) {  /* written so that NaN fails */ \
        fprintf(stderr, "  FAIL: %s (line %d): expected %f, got %f (eps=%e)\n", \
                __func__, __LINE__, _b, _a, eps); \
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


/* ---------- Helper: remove temp file ---------- */

static void cleanup(const char *path) {
    unlink(path);
}


/* ================================================================
 * TEST: xdropen / xdrclose basics
 * ================================================================ */

static int test_open_close_write(void) {
    XDR xd;
    int id;
    const char *f = "tmp_test_oc.xdr";

    id = xdropen(&xd, f, "w");
    ASSERT_MSG(id != 0, "xdropen(w) should return nonzero id");

    int val = 42;
    int ok = xdr_int(&xd, &val);
    ASSERT_MSG(ok != 0, "xdr_int write should succeed");

    int rc = xdrclose(&xd);
    ASSERT_INT_EQ(rc, 1);

    cleanup(f);
    return 0;
}

static int test_open_close_read(void) {
    XDR xd;
    int id;
    const char *f = "tmp_test_ocr.xdr";

    /* Write something first */
    id = xdropen(&xd, f, "w");
    ASSERT_MSG(id != 0, "xdropen(w) should succeed");
    int val = 99;
    xdr_int(&xd, &val);
    xdrclose(&xd);

    /* Read it back */
    id = xdropen(&xd, f, "r");
    ASSERT_MSG(id != 0, "xdropen(r) should succeed");
    int rval = 0;
    xdr_int(&xd, &rval);
    ASSERT_INT_EQ(rval, 99);
    xdrclose(&xd);

    cleanup(f);
    return 0;
}

static int test_open_nonexistent_read(void) {
    XDR xd;
    int id;

    id = xdropen(&xd, "nonexistent_file_xyzzy.xdr", "r");
    ASSERT_INT_EQ(id, 0);

    return 0;
}


/* ================================================================
 * TEST: Standard XDR primitives through xdropen
 * ================================================================ */

static int test_int_roundtrip(void) {
    XDR xd;
    const char *f = "tmp_test_int.xdr";
    int values[] = {0, 1, -1, INT_MAX, INT_MIN, 12345, -67890};
    int n = sizeof(values) / sizeof(values[0]);
    int i;

    xdropen(&xd, f, "w");
    for (i = 0; i < n; i++)
        xdr_int(&xd, &values[i]);
    xdrclose(&xd);

    xdropen(&xd, f, "r");
    for (i = 0; i < n; i++) {
        int v = 0;
        xdr_int(&xd, &v);
        ASSERT_INT_EQ(v, values[i]);
    }
    xdrclose(&xd);

    cleanup(f);
    return 0;
}

static int test_float_roundtrip(void) {
    XDR xd;
    const char *f = "tmp_test_float.xdr";
    float values[] = {0.0f, 1.0f, -1.0f, 3.14159f, 1e10f, -1e-10f, 1e30f};
    int n = sizeof(values) / sizeof(values[0]);
    int i;

    xdropen(&xd, f, "w");
    for (i = 0; i < n; i++)
        xdr_float(&xd, &values[i]);
    xdrclose(&xd);

    xdropen(&xd, f, "r");
    for (i = 0; i < n; i++) {
        float v = 0;
        xdr_float(&xd, &v);
        ASSERT_FLOAT_EQ(v, values[i], 1e-30f);
    }
    xdrclose(&xd);

    cleanup(f);
    return 0;
}

static int test_double_roundtrip(void) {
    XDR xd;
    const char *f = "tmp_test_double.xdr";
    double values[] = {0.0, 1.0, -1.0, 3.141592653589793, 1e100, -1e-100};
    int n = sizeof(values) / sizeof(values[0]);
    int i;

    xdropen(&xd, f, "w");
    for (i = 0; i < n; i++)
        xdr_double(&xd, &values[i]);
    xdrclose(&xd);

    xdropen(&xd, f, "r");
    for (i = 0; i < n; i++) {
        double v = 0;
        xdr_double(&xd, &v);
        ASSERT_DOUBLE_EQ(v, values[i], 1e-200);
    }
    xdrclose(&xd);

    cleanup(f);
    return 0;
}

static int test_short_roundtrip(void) {
    XDR xd;
    const char *f = "tmp_test_short.xdr";
    short values[] = {0, 1, -1, SHRT_MAX, SHRT_MIN, 1234, -5678};
    int n = sizeof(values) / sizeof(values[0]);
    int i;

    xdropen(&xd, f, "w");
    for (i = 0; i < n; i++)
        xdr_short(&xd, &values[i]);
    xdrclose(&xd);

    xdropen(&xd, f, "r");
    for (i = 0; i < n; i++) {
        short v = 0;
        xdr_short(&xd, &v);
        ASSERT_MSG(v == values[i], "short roundtrip mismatch");
    }
    xdrclose(&xd);

    cleanup(f);
    return 0;
}

static int test_char_roundtrip(void) {
    XDR xd;
    const char *f = "tmp_test_char.xdr";
    char values[] = {'A', 'z', '0', '\n', '\0'};
    int n = sizeof(values) / sizeof(values[0]);
    int i;

    xdropen(&xd, f, "w");
    for (i = 0; i < n; i++)
        xdr_char(&xd, &values[i]);
    xdrclose(&xd);

    xdropen(&xd, f, "r");
    for (i = 0; i < n; i++) {
        char v = '?';
        xdr_char(&xd, &v);
        ASSERT_MSG(v == values[i], "char roundtrip mismatch");
    }
    xdrclose(&xd);

    cleanup(f);
    return 0;
}

static int test_string_roundtrip(void) {
    XDR xd;
    const char *f = "tmp_test_string.xdr";
    char *str_write = "Hello, XDR world!";
    char *str_read = NULL;

    xdropen(&xd, f, "w");
    xdr_string(&xd, &str_write, 256);
    xdrclose(&xd);

    xdropen(&xd, f, "r");
    xdr_string(&xd, &str_read, 256);
    ASSERT_MSG(str_read != NULL, "xdr_string read should allocate");
    ASSERT_MSG(strcmp(str_read, str_write) == 0, "string content mismatch");
    free(str_read);
    xdrclose(&xd);

    cleanup(f);
    return 0;
}

static int test_bool_roundtrip(void) {
    XDR xd;
    const char *f = "tmp_test_bool.xdr";
    bool_t values[] = {TRUE, FALSE, TRUE, TRUE, FALSE};
    int n = sizeof(values) / sizeof(values[0]);
    int i;

    xdropen(&xd, f, "w");
    for (i = 0; i < n; i++)
        xdr_bool(&xd, &values[i]);
    xdrclose(&xd);

    xdropen(&xd, f, "r");
    for (i = 0; i < n; i++) {
        bool_t v = FALSE;
        xdr_bool(&xd, &v);
        ASSERT_MSG(v == values[i], "bool roundtrip mismatch");
    }
    xdrclose(&xd);

    cleanup(f);
    return 0;
}


/* ================================================================
 * TEST: Mixed types in a single file
 * ================================================================ */

static int test_mixed_types(void) {
    XDR xd;
    const char *f = "tmp_test_mixed.xdr";

    int wi = 42;
    float wf = 3.14f;
    double wd = 2.718281828;
    short ws = -1234;
    char wc = 'X';

    xdropen(&xd, f, "w");
    xdr_int(&xd, &wi);
    xdr_float(&xd, &wf);
    xdr_double(&xd, &wd);
    xdr_short(&xd, &ws);
    xdr_char(&xd, &wc);
    xdrclose(&xd);

    int ri = 0; float rf = 0; double rd = 0; short rs = 0; char rc = 0;
    xdropen(&xd, f, "r");
    xdr_int(&xd, &ri);
    xdr_float(&xd, &rf);
    xdr_double(&xd, &rd);
    xdr_short(&xd, &rs);
    xdr_char(&xd, &rc);
    xdrclose(&xd);

    ASSERT_INT_EQ(ri, 42);
    ASSERT_FLOAT_EQ(rf, 3.14f, 1e-6f);
    ASSERT_DOUBLE_EQ(rd, 2.718281828, 1e-9);
    ASSERT_MSG(rs == -1234, "short mismatch");
    ASSERT_MSG(rc == 'X', "char mismatch");

    cleanup(f);
    return 0;
}


/* ================================================================
 * TEST: xdr3dfcoord compression
 * ================================================================ */

/* Test with a very small set of coordinates (<=9 atoms).
 * These are stored uncompressed as raw floats. */
static int test_3dfcoord_small(void) {
    XDR xd;
    const char *f = "tmp_test_3df_small.xdr";
    int size = 5;
    float prec = 1000.0f;
    float coords[15], coords2[15];
    int i;

    /* Generate simple coordinates */
    for (i = 0; i < 15; i++)
        coords[i] = (float)(i) * 0.123f;

    xdropen(&xd, f, "w");
    int ret = xdr3dfcoord(&xd, coords, &size, &prec);
    ASSERT_MSG(ret != 0, "xdr3dfcoord write (small) should succeed");
    xdrclose(&xd);

    int rsize = 0;
    float rprec = 0;
    memset(coords2, 0, sizeof(coords2));
    xdropen(&xd, f, "r");
    ret = xdr3dfcoord(&xd, coords2, &rsize, &rprec);
    ASSERT_MSG(ret != 0, "xdr3dfcoord read (small) should succeed");
    ASSERT_INT_EQ(rsize, 5);
    xdrclose(&xd);

    for (i = 0; i < 15; i++)
        ASSERT_FLOAT_EQ(coords2[i], coords[i], 0.001f);

    cleanup(f);
    return 0;
}

/* Test with exactly 9 atoms (boundary of uncompressed path) */
static int test_3dfcoord_boundary_9(void) {
    XDR xd;
    const char *f = "tmp_test_3df_9.xdr";
    int size = 9;
    float prec = 1000.0f;
    float coords[27], coords2[27];
    int i;

    for (i = 0; i < 27; i++)
        coords[i] = (float)(i % 10) * 0.5f - 2.0f;

    xdropen(&xd, f, "w");
    xdr3dfcoord(&xd, coords, &size, &prec);
    xdrclose(&xd);

    int rsize = 0;
    float rprec = 0;
    memset(coords2, 0, sizeof(coords2));
    xdropen(&xd, f, "r");
    xdr3dfcoord(&xd, coords2, &rsize, &rprec);
    ASSERT_INT_EQ(rsize, 9);
    xdrclose(&xd);

    for (i = 0; i < 27; i++)
        ASSERT_FLOAT_EQ(coords2[i], coords[i], 0.001f);

    cleanup(f);
    return 0;
}

/* Test with 10 atoms (smallest compressed case) */
static int test_3dfcoord_10_atoms(void) {
    XDR xd;
    const char *f = "tmp_test_3df_10.xdr";
    int size = 10;
    float prec = 1000.0f;
    float coords[30], coords2[30];
    int i;

    for (i = 0; i < 30; i++)
        coords[i] = (float)(i % 7) * 0.25f + 1.0f;

    xdropen(&xd, f, "w");
    int ret = xdr3dfcoord(&xd, coords, &size, &prec);
    ASSERT_MSG(ret != 0, "xdr3dfcoord write should succeed for 10 atoms");
    xdrclose(&xd);

    int rsize = 0;
    float rprec = 0;
    memset(coords2, 0, sizeof(coords2));
    xdropen(&xd, f, "r");
    ret = xdr3dfcoord(&xd, coords2, &rsize, &rprec);
    ASSERT_MSG(ret != 0, "xdr3dfcoord read should succeed for 10 atoms");
    ASSERT_INT_EQ(rsize, 10);
    xdrclose(&xd);

    for (i = 0; i < 30; i++)
        ASSERT_FLOAT_EQ(coords2[i], coords[i], 0.002f);

    cleanup(f);
    return 0;
}

/* Test with a moderate number of atoms in a tight cluster */
static int test_3dfcoord_100_atoms(void) {
    XDR xd;
    const char *f = "tmp_test_3df_100.xdr";
    int size = 100;
    float prec = 1000.0f;
    int i;

    float *coords = (float *)malloc(300 * sizeof(float));
    float *coords2 = (float *)malloc(300 * sizeof(float));

    /* Simulate a small protein: atoms in a tight cluster */
    for (i = 0; i < 300; i++)
        coords[i] = 1.0f + (float)(i % 50) * 0.1f;

    xdropen(&xd, f, "w");
    int ret = xdr3dfcoord(&xd, coords, &size, &prec);
    ASSERT_MSG(ret != 0, "write 100 atoms should succeed");
    xdrclose(&xd);

    int rsize = 0;
    float rprec = 0;
    memset(coords2, 0, 300 * sizeof(float));
    xdropen(&xd, f, "r");
    ret = xdr3dfcoord(&xd, coords2, &rsize, &rprec);
    ASSERT_MSG(ret != 0, "read 100 atoms should succeed");
    ASSERT_INT_EQ(rsize, 100);
    xdrclose(&xd);

    for (i = 0; i < 300; i++)
        ASSERT_FLOAT_EQ(coords2[i], coords[i], 0.002f);

    free(coords);
    free(coords2);
    cleanup(f);
    return 0;
}

/* Test with varying precision values */
static int test_3dfcoord_precision(void) {
    XDR xd;
    const char *f = "tmp_test_3df_prec.xdr";
    int size = 20;
    int i;
    float coords[60], coords2[60];

    for (i = 0; i < 60; i++)
        coords[i] = (float)(i) * 0.01f;

    /* Low precision */
    float prec = 10.0f;
    xdropen(&xd, f, "w");
    xdr3dfcoord(&xd, coords, &size, &prec);
    xdrclose(&xd);

    int rsize = 0;
    float rprec = 0;
    xdropen(&xd, f, "r");
    xdr3dfcoord(&xd, coords2, &rsize, &rprec);
    xdrclose(&xd);

    ASSERT_FLOAT_EQ(rprec, 10.0f, 0.001f);
    for (i = 0; i < 60; i++)
        ASSERT_FLOAT_EQ(coords2[i], coords[i], 0.11f);  /* 1/10 precision */

    /* High precision */
    prec = 10000.0f;
    xdropen(&xd, f, "w");
    size = 20;
    xdr3dfcoord(&xd, coords, &size, &prec);
    xdrclose(&xd);

    rsize = 0;
    rprec = 0;
    xdropen(&xd, f, "r");
    xdr3dfcoord(&xd, coords2, &rsize, &rprec);
    xdrclose(&xd);

    ASSERT_FLOAT_EQ(rprec, 10000.0f, 0.001f);
    for (i = 0; i < 60; i++)
        ASSERT_FLOAT_EQ(coords2[i], coords[i], 0.0002f);  /* 1/10000 precision */

    cleanup(f);
    return 0;
}


/* ================================================================
 * TEST: Multiple frames
 * ================================================================ */

static int test_multiple_frames(void) {
    XDR xd;
    const char *f = "tmp_test_multi.xdr";
    int nframes = 5;
    int size = 50;
    float prec = 1000.0f;
    int i, j;

    float *coords = (float *)malloc(150 * sizeof(float));
    float *coords2 = (float *)malloc(150 * sizeof(float));

    /* Write multiple frames */
    xdropen(&xd, f, "w");
    xdr_int(&xd, &nframes);
    xdr_int(&xd, &size);
    for (j = 0; j < nframes; j++) {
        for (i = 0; i < 150; i++)
            coords[i] = (float)(j * 150 + i) * 0.001f;
        int ret = xdr3dfcoord(&xd, coords, &size, &prec);
        ASSERT_MSG(ret != 0, "write frame should succeed");
    }
    xdrclose(&xd);

    /* Read back all frames */
    xdropen(&xd, f, "r");
    int rnframes = 0, rsize = 0;
    float rprec = 0;
    xdr_int(&xd, &rnframes);
    xdr_int(&xd, &rsize);
    ASSERT_INT_EQ(rnframes, nframes);
    ASSERT_INT_EQ(rsize, size);

    for (j = 0; j < nframes; j++) {
        int rs = 0;
        int ret = xdr3dfcoord(&xd, coords2, &rs, &rprec);
        ASSERT_MSG(ret != 0, "read frame should succeed");
        ASSERT_INT_EQ(rs, size);

        /* Regenerate expected coords */
        for (i = 0; i < 150; i++)
            coords[i] = (float)(j * 150 + i) * 0.001f;
        for (i = 0; i < 150; i++)
            ASSERT_FLOAT_EQ(coords2[i], coords[i], 0.002f);
    }
    xdrclose(&xd);

    free(coords);
    free(coords2);
    cleanup(f);
    return 0;
}


/* ================================================================
 * TEST: Negative coordinates
 * ================================================================ */

static int test_negative_coords(void) {
    XDR xd;
    const char *f = "tmp_test_neg.xdr";
    int size = 20;
    float prec = 1000.0f;
    int i;

    float coords[60], coords2[60];
    for (i = 0; i < 60; i++)
        coords[i] = -5.0f + (float)(i) * 0.1f;  /* range: -5.0 to 0.9 */

    xdropen(&xd, f, "w");
    xdr3dfcoord(&xd, coords, &size, &prec);
    xdrclose(&xd);

    int rsize = 0;
    float rprec = 0;
    xdropen(&xd, f, "r");
    xdr3dfcoord(&xd, coords2, &rsize, &rprec);
    xdrclose(&xd);

    ASSERT_INT_EQ(rsize, 20);
    for (i = 0; i < 60; i++)
        ASSERT_FLOAT_EQ(coords2[i], coords[i], 0.002f);

    cleanup(f);
    return 0;
}


/* ================================================================
 * TEST: Large coordinate values
 * ================================================================ */

static int test_large_coords(void) {
    XDR xd;
    const char *f = "tmp_test_large.xdr";
    int size = 20;
    float prec = 100.0f;
    int i;

    float coords[60], coords2[60];
    for (i = 0; i < 60; i++)
        coords[i] = 1000.0f + (float)(i) * 10.0f;

    xdropen(&xd, f, "w");
    xdr3dfcoord(&xd, coords, &size, &prec);
    xdrclose(&xd);

    int rsize = 0;
    float rprec = 0;
    xdropen(&xd, f, "r");
    xdr3dfcoord(&xd, coords2, &rsize, &rprec);
    xdrclose(&xd);

    ASSERT_INT_EQ(rsize, 20);
    for (i = 0; i < 60; i++)
        ASSERT_FLOAT_EQ(coords2[i], coords[i], 0.02f);

    cleanup(f);
    return 0;
}


/* ================================================================
 * TEST: Append mode
 * ================================================================ */

static int test_append_mode(void) {
    XDR xd;
    const char *f = "tmp_test_append.xdr";
    int i;

    /* Write first batch */
    xdropen(&xd, f, "w");
    int n1 = 3;
    xdr_int(&xd, &n1);
    for (i = 0; i < n1; i++) {
        int v = i * 10;
        xdr_int(&xd, &v);
    }
    xdrclose(&xd);

    /* Append second batch */
    xdropen(&xd, f, "a");
    int n2 = 2;
    xdr_int(&xd, &n2);
    for (i = 0; i < n2; i++) {
        int v = 100 + i;
        xdr_int(&xd, &v);
    }
    xdrclose(&xd);

    /* Read everything back */
    xdropen(&xd, f, "r");
    int rn1 = 0;
    xdr_int(&xd, &rn1);
    ASSERT_INT_EQ(rn1, 3);
    for (i = 0; i < 3; i++) {
        int v = 0;
        xdr_int(&xd, &v);
        ASSERT_INT_EQ(v, i * 10);
    }
    int rn2 = 0;
    xdr_int(&xd, &rn2);
    ASSERT_INT_EQ(rn2, 2);
    for (i = 0; i < 2; i++) {
        int v = 0;
        xdr_int(&xd, &v);
        ASSERT_INT_EQ(v, 100 + i);
    }
    xdrclose(&xd);

    cleanup(f);
    return 0;
}


/* ================================================================
 * TEST: Multiple simultaneous open files
 * ================================================================ */

static int test_multiple_open_files(void) {
    XDR xd1, xd2;
    const char *f1 = "tmp_test_multi1.xdr";
    const char *f2 = "tmp_test_multi2.xdr";

    int id1 = xdropen(&xd1, f1, "w");
    int id2 = xdropen(&xd2, f2, "w");
    ASSERT_MSG(id1 != 0, "first open should succeed");
    ASSERT_MSG(id2 != 0, "second open should succeed");
    ASSERT_MSG(id1 != id2, "ids should be different");

    int v1 = 111, v2 = 222;
    xdr_int(&xd1, &v1);
    xdr_int(&xd2, &v2);
    xdrclose(&xd1);
    xdrclose(&xd2);

    /* Read back independently */
    xdropen(&xd1, f1, "r");
    xdropen(&xd2, f2, "r");
    int r1 = 0, r2 = 0;
    xdr_int(&xd1, &r1);
    xdr_int(&xd2, &r2);
    ASSERT_INT_EQ(r1, 111);
    ASSERT_INT_EQ(r2, 222);
    xdrclose(&xd1);
    xdrclose(&xd2);

    cleanup(f1);
    cleanup(f2);
    return 0;
}


/* ================================================================
 * TEST: Reopen same file multiple times
 * ================================================================ */

static int test_reopen_file(void) {
    XDR xd;
    const char *f = "tmp_test_reopen.xdr";
    int i;

    /* Write, close, read, close -- repeated */
    for (i = 1; i <= 3; i++) {
        xdropen(&xd, f, "w");
        int v = i * 100;
        xdr_int(&xd, &v);
        xdrclose(&xd);

        xdropen(&xd, f, "r");
        int rv = 0;
        xdr_int(&xd, &rv);
        ASSERT_INT_EQ(rv, i * 100);
        xdrclose(&xd);
    }

    cleanup(f);
    return 0;
}


/* ================================================================
 * TEST: xdr3dfcoord with water-like molecule pattern
 * (O-H-H triples that trigger the atom-swap optimization)
 * ================================================================ */

static int test_3dfcoord_water_pattern(void) {
    XDR xd;
    const char *f = "tmp_test_water.xdr";
    int nwaters = 100;
    int size = nwaters * 3;  /* O + H + H per water */
    float prec = 1000.0f;
    int i;

    float *coords = (float *)malloc(size * 3 * sizeof(float));
    float *coords2 = (float *)malloc(size * 3 * sizeof(float));

    /* Generate water-like coordinates: each water has O, H1, H2
     * with H atoms close to O (within ~0.1 nm as in real water) */
    for (i = 0; i < nwaters; i++) {
        float cx = (float)(i % 10) * 0.3f;
        float cy = (float)((i / 10) % 10) * 0.3f;
        float cz = (float)(i / 100) * 0.3f;
        /* Oxygen */
        coords[(i*3+0)*3 + 0] = cx;
        coords[(i*3+0)*3 + 1] = cy;
        coords[(i*3+0)*3 + 2] = cz;
        /* Hydrogen 1 (close to O) */
        coords[(i*3+1)*3 + 0] = cx + 0.096f;
        coords[(i*3+1)*3 + 1] = cy;
        coords[(i*3+1)*3 + 2] = cz;
        /* Hydrogen 2 (close to O) */
        coords[(i*3+2)*3 + 0] = cx - 0.024f;
        coords[(i*3+2)*3 + 1] = cy + 0.093f;
        coords[(i*3+2)*3 + 2] = cz;
    }

    xdropen(&xd, f, "w");
    int ret = xdr3dfcoord(&xd, coords, &size, &prec);
    ASSERT_MSG(ret != 0, "write water coords should succeed");
    xdrclose(&xd);

    int rsize = 0;
    float rprec = 0;
    xdropen(&xd, f, "r");
    ret = xdr3dfcoord(&xd, coords2, &rsize, &rprec);
    ASSERT_MSG(ret != 0, "read water coords should succeed");
    ASSERT_INT_EQ(rsize, size);
    xdrclose(&xd);

    for (i = 0; i < size * 3; i++)
        ASSERT_FLOAT_EQ(coords2[i], coords[i], 0.002f);

    free(coords);
    free(coords2);
    cleanup(f);
    return 0;
}


/* ================================================================
 * TEST: xdr3dfcoord with 1000 atoms (larger dataset)
 * ================================================================ */

static int test_3dfcoord_1000_atoms(void) {
    XDR xd;
    const char *f = "tmp_test_3df_1000.xdr";
    int size = 1000;
    float prec = 1000.0f;
    int i;

    float *coords = (float *)malloc(3000 * sizeof(float));
    float *coords2 = (float *)malloc(3000 * sizeof(float));

    /* Simulate atoms distributed in a 10x10x10 nm box */
    for (i = 0; i < 3000; i++)
        coords[i] = (float)(i % 1000) * 0.01f;

    xdropen(&xd, f, "w");
    int ret = xdr3dfcoord(&xd, coords, &size, &prec);
    ASSERT_MSG(ret != 0, "write 1000 atoms should succeed");
    xdrclose(&xd);

    int rsize = 0;
    float rprec = 0;
    xdropen(&xd, f, "r");
    ret = xdr3dfcoord(&xd, coords2, &rsize, &rprec);
    ASSERT_MSG(ret != 0, "read 1000 atoms should succeed");
    ASSERT_INT_EQ(rsize, 1000);
    xdrclose(&xd);

    for (i = 0; i < 3000; i++)
        ASSERT_FLOAT_EQ(coords2[i], coords[i], 0.002f);

    free(coords);
    free(coords2);
    cleanup(f);
    return 0;
}


/* ================================================================
 * TEST: Compression effectiveness
 * (verify compressed file is smaller than raw float storage)
 * ================================================================ */

static int test_compression_ratio(void) {
    XDR xd;
    const char *f = "tmp_test_compress.xdr";
    int size = 500;
    float prec = 1000.0f;
    int i;
    long filesize;

    float *coords = (float *)malloc(1500 * sizeof(float));

    /* Clustered coordinates (good for compression) */
    for (i = 0; i < 1500; i++)
        coords[i] = 1.0f + (float)(i % 100) * 0.05f;

    xdropen(&xd, f, "w");
    xdr3dfcoord(&xd, coords, &size, &prec);
    xdrclose(&xd);

    /* Check file size */
    FILE *fp = fopen(f, "rb");
    fseek(fp, 0, SEEK_END);
    filesize = ftell(fp);
    fclose(fp);

    long raw_size = 1500 * sizeof(float);  /* 6000 bytes */
    ASSERT_MSG(filesize < raw_size,
        "compressed file should be smaller than raw float storage");

    free(coords);
    cleanup(f);
    return 0;
}


/* ================================================================
 * TEST: xdr_setpos / xdr_getpos through xdropen
 * ================================================================ */

static int test_setpos_getpos(void) {
    XDR xd;
    const char *f = "tmp_test_pos.xdr";

    xdropen(&xd, f, "w");
    int v1 = 11, v2 = 22, v3 = 33;
    xdr_int(&xd, &v1);
    unsigned int pos_after_v1 = xdr_getpos(&xd);
    xdr_int(&xd, &v2);
    xdr_int(&xd, &v3);
    xdrclose(&xd);

    /* Read: skip first int using setpos */
    xdropen(&xd, f, "r");
    xdr_setpos(&xd, pos_after_v1);
    int rv2 = 0;
    xdr_int(&xd, &rv2);
    ASSERT_INT_EQ(rv2, 22);
    int rv3 = 0;
    xdr_int(&xd, &rv3);
    ASSERT_INT_EQ(rv3, 33);
    xdrclose(&xd);

    cleanup(f);
    return 0;
}


/* ================================================================
 * TEST: xdr3dfcoord with identical coordinates
 * (worst case for delta encoding)
 * ================================================================ */

static int test_3dfcoord_identical_coords(void) {
    XDR xd;
    const char *f = "tmp_test_3df_ident.xdr";
    int size = 50;
    float prec = 1000.0f;
    int i;

    float coords[150], coords2[150];
    for (i = 0; i < 150; i += 3) {
        coords[i]   = 1.234f;
        coords[i+1] = 5.678f;
        coords[i+2] = 9.012f;
    }

    xdropen(&xd, f, "w");
    int ret = xdr3dfcoord(&xd, coords, &size, &prec);
    ASSERT_MSG(ret != 0, "write identical coords should succeed");
    xdrclose(&xd);

    int rsize = 0;
    float rprec = 0;
    xdropen(&xd, f, "r");
    ret = xdr3dfcoord(&xd, coords2, &rsize, &rprec);
    ASSERT_MSG(ret != 0, "read identical coords should succeed");
    ASSERT_INT_EQ(rsize, 50);
    xdrclose(&xd);

    for (i = 0; i < 150; i++)
        ASSERT_FLOAT_EQ(coords2[i], coords[i], 0.002f);

    cleanup(f);
    return 0;
}


/* ================================================================
 * TEST: xdr3dfcoord with widely scattered coordinates
 * (stress test for large ranges)
 * ================================================================ */

static int test_3dfcoord_scattered(void) {
    XDR xd;
    const char *f = "tmp_test_3df_scatter.xdr";
    int size = 30;
    float prec = 100.0f;
    int i;

    float coords[90], coords2[90];
    for (i = 0; i < 90; i++)
        coords[i] = (i % 2 == 0) ? (float)(i) * 100.0f : (float)(-i) * 100.0f;

    xdropen(&xd, f, "w");
    int ret = xdr3dfcoord(&xd, coords, &size, &prec);
    /* This may or may not succeed depending on overflow — just test the path */
    xdrclose(&xd);

    if (ret != 0) {
        int rsize = 0;
        float rprec = 0;
        xdropen(&xd, f, "r");
        xdr3dfcoord(&xd, coords2, &rsize, &rprec);
        ASSERT_INT_EQ(rsize, 30);
        xdrclose(&xd);

        for (i = 0; i < 90; i++)
            ASSERT_FLOAT_EQ(coords2[i], coords[i], 0.02f);
    }

    cleanup(f);
    return 0;
}


/* ================================================================
 * TEST: xdr3dfcoord intermixed with other XDR data
 * (simulating a real trajectory file format)
 * ================================================================ */

static int test_3dfcoord_with_metadata(void) {
    XDR xd;
    const char *f = "tmp_test_3df_meta.xdr";
    int size = 50;
    float prec = 1000.0f;
    int i;

    float *coords = (float *)malloc(150 * sizeof(float));
    float *coords2 = (float *)malloc(150 * sizeof(float));
    for (i = 0; i < 150; i++)
        coords[i] = (float)(i) * 0.032f;

    /* Write: header + 3dfcoord + trailer */
    xdropen(&xd, f, "w");
    int step = 42;
    float time_val = 1.5f;
    float box[9] = {3.0f, 0, 0, 0, 3.0f, 0, 0, 0, 3.0f};
    xdr_int(&xd, &step);
    xdr_float(&xd, &time_val);
    for (i = 0; i < 9; i++)
        xdr_float(&xd, &box[i]);
    xdr3dfcoord(&xd, coords, &size, &prec);
    int checksum = 12345;
    xdr_int(&xd, &checksum);
    xdrclose(&xd);

    /* Read back */
    xdropen(&xd, f, "r");
    int rstep = 0;
    float rtime = 0;
    float rbox[9];
    xdr_int(&xd, &rstep);
    xdr_float(&xd, &rtime);
    for (i = 0; i < 9; i++)
        xdr_float(&xd, &rbox[i]);
    ASSERT_INT_EQ(rstep, 42);
    ASSERT_FLOAT_EQ(rtime, 1.5f, 1e-6f);
    ASSERT_FLOAT_EQ(rbox[0], 3.0f, 1e-6f);
    ASSERT_FLOAT_EQ(rbox[4], 3.0f, 1e-6f);

    int rsize = 0;
    float rprec = 0;
    xdr3dfcoord(&xd, coords2, &rsize, &rprec);
    ASSERT_INT_EQ(rsize, 50);

    int rchecksum = 0;
    xdr_int(&xd, &rchecksum);
    ASSERT_INT_EQ(rchecksum, 12345);
    xdrclose(&xd);

    for (i = 0; i < 150; i++)
        ASSERT_FLOAT_EQ(coords2[i], coords[i], 0.002f);

    free(coords);
    free(coords2);
    cleanup(f);
    return 0;
}


/* ================================================================
 * TEST: mixing caller-owned and library-owned XDR structs
 *
 * xdropen(NULL, ...) makes the library allocate the XDR struct (the
 * path the Fortran wrappers use); passing a struct makes the caller
 * own it. Ownership used to be recorded in one shared slot that each
 * open overwrote, so closing a caller-owned file while a library-owned
 * one was open called free() on the caller's struct -- an abort when,
 * as here, that struct is on the stack.
 * ================================================================ */

/* The Fortran wrapper, used here to close a library-owned handle by id.
 * The trailing underscore matches conf/linux.m4 and conf/darwin.m4, the
 * two configurations this test suite builds for. */
extern void xdrfclose_(int *xdrid, int *ret);

static int test_mixed_ownership_close_order(void) {
    XDR c_xdr;
    const char *fc = "tmp_test_own_c.xdr";
    const char *ff = "tmp_test_own_f.xdr";
    int fid, ret, v;

    /* Caller-owned open, then library-owned open */
    ASSERT_MSG(xdropen(&c_xdr, fc, "w") != 0, "caller-owned open should succeed");
    fid = xdropen(NULL, ff, "w");
    ASSERT_MSG(fid != 0, "library-owned open should succeed");

    v = 1;
    xdr_int(&c_xdr, &v);

    /* Close the caller-owned one first: must not free the caller's struct */
    ASSERT_INT_EQ(xdrclose(&c_xdr), 1);
    ret = 0; xdrfclose_(&fid, &ret);
    ASSERT_INT_EQ(ret, 1);

    /* Now the other order: library-owned opened first */
    fid = xdropen(NULL, ff, "w");
    ASSERT_MSG(fid != 0, "library-owned open should succeed");
    ASSERT_MSG(xdropen(&c_xdr, fc, "w") != 0, "caller-owned open should succeed");
    ret = 0; xdrfclose_(&fid, &ret);
    ASSERT_INT_EQ(ret, 1);
    ASSERT_INT_EQ(xdrclose(&c_xdr), 1);

    cleanup(fc);
    cleanup(ff);
    return 0;
}

/* ================================================================
 * TEST: a size that disagrees with the file is refused
 *
 * fp is only guaranteed to hold the caller's stated number of
 * triples, so decoding a different count would run off its end.
 * This used to print a warning and then do it anyway.
 * ================================================================ */

static int test_3dfcoord_size_mismatch_refused(void) {
    XDR xd;
    const char *f = "tmp_test_mismatch.xdr";
    float coords[60], back[60];
    int n = 20, i, rc;
    float prec = 1000.0f;

    for (i = 0; i < 60; i++) coords[i] = (float)i * 0.01f;
    xdropen(&xd, f, "w");
    xdr3dfcoord(&xd, coords, &n, &prec);
    xdrclose(&xd);

    xdropen(&xd, f, "r");
    n = 15;  /* deliberately wrong: the file holds 20 */
    rc = xdr3dfcoord(&xd, back, &n, &prec);
    ASSERT_INT_EQ(rc, 0);
    xdrclose(&xd);

    cleanup(f);
    return 0;
}

/* ================================================================
 * TEST: corrupt frames are rejected rather than followed
 *
 * Each field below indexes or sizes something, and each used to be
 * trusted straight out of the file: smallidx indexed magicints[] out
 * of bounds, a max one below min gave a zero divisor in receiveints(),
 * and an oversized byte count overran the decode buffer. The unpatched
 * frame is read back first, so each rejection below is the patch's
 * doing rather than, say, a file that failed to open.
 * ================================================================ */

static int write_reference_frame(const char *path, int natoms) {
    XDR xd;
    float *coords = (float *)malloc(natoms * 3 * sizeof(float));
    float prec = 1000.0f;
    int i, n = natoms;

    for (i = 0; i < natoms * 3; i++) coords[i] = (float)(i % 97) * 0.013f;
    xdropen(&xd, path, "w");
    xdr3dfcoord(&xd, coords, &n, &prec);
    xdrclose(&xd);
    free(coords);
    return 0;
}

/* Overwrite the big-endian int at byte offset 'off' */
static void patch_be32(const char *path, long off, unsigned int val) {
    FILE *f = fopen(path, "r+b");
    unsigned char b[4];
    b[0] = (unsigned char)(val >> 24); b[1] = (unsigned char)(val >> 16);
    b[2] = (unsigned char)(val >> 8);  b[3] = (unsigned char)val;
    fseek(f, off, SEEK_SET);
    fwrite(b, 1, 4, f);
    fclose(f);
}

/* Append 'count' zero bytes to the file */
static void append_zeros(const char *path, long count) {
    FILE *f = fopen(path, "ab");
    char zeros[4096];
    memset(zeros, 0, sizeof(zeros));
    while (count > 0) {
        long chunk = count < (long)sizeof(zeros) ? count : (long)sizeof(zeros);
        fwrite(zeros, 1, (size_t)chunk, f);
        count -= chunk;
    }
    fclose(f);
}

/* Read the first frame of path into a buffer of natoms triples, passing
 * *n as the expected count, and return xdr3dfcoord's result (-1 if the
 * file cannot be opened, so that is never mistaken for a rejection). */
static int read_frame_rc(const char *path, int natoms, int *n) {
    XDR xd;
    float *back = (float *)malloc(natoms * 3 * sizeof(float));
    float prec = 0;
    int rc;

    if (xdropen(&xd, path, "r") == 0) {
        free(back);
        return -1;
    }
    rc = xdr3dfcoord(&xd, back, n, &prec);
    xdrclose(&xd);
    free(back);
    return rc;
}

/* Read the first frame of path expecting failure, and return the stream
 * position afterwards: how far the reader got before it gave up. Returns
 * -1 if the file cannot be opened or the read succeeded. */
static long position_after_failed_read(const char *path, int natoms) {
    XDR xd;
    float *back = (float *)malloc(natoms * 3 * sizeof(float));
    float prec = 0;
    int n = natoms;
    long pos = -1;

    if (xdropen(&xd, path, "r") == 0) {
        free(back);
        return -1;
    }
    if (xdr3dfcoord(&xd, back, &n, &prec) == 0)
        pos = (long)xdr_getpos(&xd);
    xdrclose(&xd);
    free(back);
    return pos;
}

/* As read_frame_rc, expecting exactly natoms */
static int read_back_rc(const char *path, int natoms) {
    int n = natoms;
    return read_frame_rc(path, natoms, &n);
}

static int test_3dfcoord_rejects_corrupt_frames(void) {
    const char *f = "tmp_test_corrupt.xdr";
    const int natoms = 50;

    /* Frame layout: size, precision, minint[3], maxint[3], smallidx, nbytes */
    const long off_minint0  = 8;
    const long off_maxint0  = 20;
    const long off_smallidx = 32;
    const long off_nbytes   = 36;
    int n;

    /* positive control: the unpatched frame reads back */
    write_reference_frame(f, natoms);
    ASSERT_INT_EQ(read_back_rc(f, natoms), 1);

    /* smallidx far past the end of magicints[] */
    write_reference_frame(f, natoms);
    patch_be32(f, off_smallidx, 100000u);
    ASSERT_INT_EQ(read_back_rc(f, natoms), 0);

    /* smallidx below the first usable entry */
    write_reference_frame(f, natoms);
    patch_be32(f, off_smallidx, 0u);
    ASSERT_INT_EQ(read_back_rc(f, natoms), 0);

    /* max one below min -> axis range max - min + 1 of zero -> division
     * by zero in receiveints */
    write_reference_frame(f, natoms);
    patch_be32(f, off_minint0, 1000u);
    patch_be32(f, off_maxint0, 999u);
    ASSERT_INT_EQ(read_back_rc(f, natoms), 0);

    /* compressed block far larger than the buffer for this atom count.
     * The bytes are really in the file, so only the capacity check stops
     * xdr_opaque() writing them past the end of the buffer, and it must
     * do so before reading any of them: the stream has to stop right
     * after the byte count. Checking the return value alone is not
     * enough, because the overrunning read usually fails too, but only
     * after corrupting memory (and without the padding it just failed at
     * end of file). 1 MiB is beyond the buffer for any frame this suite
     * decodes; the buffer only ever grows. */
    write_reference_frame(f, natoms);
    patch_be32(f, off_nbytes, 1u << 20);
    append_zeros(f, 1L << 20);
    ASSERT_INT_EQ((int)position_after_failed_read(f, natoms), (int)off_nbytes + 4);

    /* a negative atom count, read with n = 0 so that the size-mismatch
     * check cannot be what rejects it; n must come back untouched */
    write_reference_frame(f, natoms);
    patch_be32(f, 0, 0xfffffff0u);
    n = 0;
    ASSERT_INT_EQ(read_frame_rc(f, natoms, &n), 0);
    ASSERT_INT_EQ(n, 0);

    /* min = INT_MIN, max = INT_MAX on one axis: a range of 2^32 values
     * wraps the axis size to 0, a zero divisor in receiveints (SIGFPE on
     * x86) that the max < min check does not catch */
    write_reference_frame(f, natoms);
    patch_be32(f, off_minint0 + 4, 0x80000000u);
    patch_be32(f, off_maxint0 + 4, 0x7fffffffu);
    ASSERT_INT_EQ(read_back_rc(f, natoms), 0);

    /* a precision of zero would make every coordinate inf or NaN */
    write_reference_frame(f, natoms);
    patch_be32(f, 4, 0u);
    ASSERT_INT_EQ(read_back_rc(f, natoms), 0);

    /* a compressed block too short for the atoms it has to hold: the
     * decoder used to read on into stale buffer contents and succeed */
    write_reference_frame(f, natoms);
    patch_be32(f, off_nbytes, 4u);
    ASSERT_INT_EQ(read_back_rc(f, natoms), 0);

    /* a file cut off inside the header: the unread fields used to be
     * used uninitialised (visible only under valgrind; here the read
     * just has to fail) */
    write_reference_frame(f, natoms);
    ASSERT_INT_EQ(truncate(f, off_minint0 + 6), 0);
    ASSERT_INT_EQ(read_back_rc(f, natoms), 0);

    cleanup(f);
    return 0;
}

/* ================================================================
 * TEST: upper-case modes
 *
 * xdropen documents "W" and "A" as write modes, and opened the file
 * that way, but xdr3dfcoord took the direction from the mode letter
 * and only recognised lower case: on a "W" stream it ran the read
 * path, writing an uninitialised atom count into the file.
 * ================================================================ */

static int test_uppercase_modes(void) {
    XDR xd;
    const char *f = "tmp_test_upper.xdr";
    float coords[60], back[60];
    float prec = 1000.0f, rprec = 0;
    int n, i;

    for (i = 0; i < 60; i++) coords[i] = (float)i * 0.021f;

    ASSERT_MSG(xdropen(&xd, f, "W") != 0, "xdropen(W) should succeed");
    n = 20;
    ASSERT_INT_EQ(xdr3dfcoord(&xd, coords, &n, &prec), 1);
    ASSERT_INT_EQ(xdrclose(&xd), 1);

    ASSERT_MSG(xdropen(&xd, f, "A") != 0, "xdropen(A) should succeed");
    for (i = 0; i < 60; i++) coords[i] += 1.0f;
    n = 20;
    ASSERT_INT_EQ(xdr3dfcoord(&xd, coords, &n, &prec), 1);
    ASSERT_INT_EQ(xdrclose(&xd), 1);

    xdropen(&xd, f, "r");
    n = 20;
    ASSERT_INT_EQ(xdr3dfcoord(&xd, back, &n, &rprec), 1);
    for (i = 0; i < 60; i++)
        ASSERT_FLOAT_EQ(back[i], coords[i] - 1.0f, 0.001f);
    n = 20;
    ASSERT_INT_EQ(xdr3dfcoord(&xd, back, &n, &rprec), 1);
    for (i = 0; i < 60; i++)
        ASSERT_FLOAT_EQ(back[i], coords[i], 0.001f);
    xdrclose(&xd);

    cleanup(f);
    return 0;
}

/* ================================================================
 * TEST: streams that xdropen did not open are refused, not followed
 *
 * The stream lookup in xdr3dfcoord started at table slot 0, which is
 * never used and always NULL, so a NULL stream "matched" it and was
 * then dereferenced.
 * ================================================================ */

static int test_unknown_stream_refused(void) {
    XDR mem;
    char membuf[1024];
    float coords[60] = {0};
    float prec = 1000.0f;
    int n = 20;

    ASSERT_INT_EQ(xdr3dfcoord(NULL, coords, &n, &prec), 0);
    ASSERT_INT_EQ(xdr3dfcoord_peek_size(NULL, &n), 0);

    xdrmem_create(&mem, membuf, sizeof(membuf), XDR_ENCODE);
    n = 20;
    ASSERT_INT_EQ(xdr3dfcoord(&mem, coords, &n, &prec), 0);
    ASSERT_INT_EQ(xdrclose(&mem), 0);
    return 0;
}

/* ================================================================
 * TEST: a frame that cannot be stored is refused before anything is
 * written
 *
 * NaN used to be converted to int (undefined; 0 on arm64), so it was
 * written as a zero coordinate and the call succeeded. Infinite and
 * out-of-range values, and coordinate ranges too wide to encode,
 * returned 0 but only after writing the whole garbage frame. A zero
 * precision succeeded and read back as NaN.
 * ================================================================ */

static int write_should_be_refused(XDR *xd, float *coords, float prec) {
    int n = 20;
    unsigned int before = xdr_getpos(xd);
    int rc = xdr3dfcoord(xd, coords, &n, &prec);
    /* 1 only if refused and the stream is untouched */
    return rc == 0 && xdr_getpos(xd) == before;
}

static int test_3dfcoord_rejects_unstorable_input(void) {
    XDR xd;
    const char *f = "tmp_test_unstorable.xdr";
    float coords[60], back[60];
    float prec = 1000.0f, rprec = 0;
    int n, i;

#define RESET_COORDS() for (i = 0; i < 60; i++) coords[i] = (float)i * 0.037f

    ASSERT_MSG(xdropen(&xd, f, "w") != 0, "open should succeed");

    RESET_COORDS(); coords[7] = NAN;
    ASSERT_MSG(write_should_be_refused(&xd, coords, prec), "NaN coordinate");
    RESET_COORDS(); coords[7] = INFINITY;
    ASSERT_MSG(write_should_be_refused(&xd, coords, prec), "+inf coordinate");
    RESET_COORDS(); coords[7] = -INFINITY;
    ASSERT_MSG(write_should_be_refused(&xd, coords, prec), "-inf coordinate");
    RESET_COORDS(); coords[7] = 1e10f;
    ASSERT_MSG(write_should_be_refused(&xd, coords, prec), "coordinate beyond int range");
    /* each value fits on its own, but the range between them does not */
    RESET_COORDS(); coords[0] = -1.5e6f; coords[3] = 1.5e6f;
    ASSERT_MSG(write_should_be_refused(&xd, coords, prec), "range beyond 2^31");
    RESET_COORDS();
    ASSERT_MSG(write_should_be_refused(&xd, coords, 0.0f), "zero precision");
    ASSERT_MSG(write_should_be_refused(&xd, coords, NAN), "NaN precision");
    ASSERT_MSG(write_should_be_refused(&xd, coords, INFINITY), "infinite precision");
    /* a negative precision rounded the wrong way: up to 1.5/|precision| off */
    ASSERT_MSG(write_should_be_refused(&xd, coords, -1000.0f), "negative precision");
    /* 1/precision is inf for a subnormal precision, so every coordinate
     * read back as inf or NaN */
    ASSERT_MSG(write_should_be_refused(&xd, coords, FLT_MIN / 4.0f), "subnormal precision");
    /* FLT_MAX scales to 4 at precision FLT_MIN, and 4 / FLT_MIN overflows */
    RESET_COORDS(); coords[7] = FLT_MAX;
    ASSERT_MSG(write_should_be_refused(&xd, coords, FLT_MIN), "coordinate that reads back as inf");
    RESET_COORDS();

    /* the stream is still clean: a good frame written now is the first */
    n = 20;
    ASSERT_INT_EQ(xdr3dfcoord(&xd, coords, &n, &prec), 1);
    ASSERT_INT_EQ(xdrclose(&xd), 1);

    xdropen(&xd, f, "r");
    n = 20;
    ASSERT_INT_EQ(xdr3dfcoord(&xd, back, &n, &rprec), 1);
    xdrclose(&xd);
    for (i = 0; i < 60; i++)
        ASSERT_FLOAT_EQ(back[i], coords[i], 0.001f);

#undef RESET_COORDS
    cleanup(f);
    return 0;
}

/* ================================================================
 * Deterministic test data for the high-precision and golden-byte
 * tests. Coordinates are built from integers (in units of 0.001 nm)
 * and converted with one correctly rounded division, so they are the
 * same on every IEEE machine whatever the compiler does with fused
 * multiply-adds.
 * ================================================================ */

static unsigned int lcg_next(unsigned int *state) {
    *state = *state * 1664525u + 1013904223u;
    return *state >> 8;
}

/* kind 0: random walk with steps of up to 0.15 nm per axis (chain-like)
 * kind 1: water-like triples on a 0.31 nm lattice
 * kind 2: uniform in a 10 nm box
 * kind 3: the kind 0 walk, jumping anywhere in a 2000 nm box every 50
 *         atoms. At precisions of 1e5 and up an axis spans more than 2^24
 *         scaled units, which selects the per-axis (large range) encoding,
 *         and at 1e6 a jump can exceed 2^31 scaled units of Manhattan
 *         distance, the overflow that wrapped_manhattan_distance()
 *         reproduces. */
static void make_test_frame(int kind, int natoms, unsigned int *state, float *coords) {
    int walk[3] = {2000, 2000, 2000};  /* chain position, 0.001 nm units */
    int i, k;
    for (i = 0; i < natoms; i++) {
        for (k = 0; k < 3; k++) {
            int milli_nm;
            if (kind == 0) {
                walk[k] += (int)(lcg_next(state) % 301u) - 150;
                milli_nm = walk[k];
            } else if (kind == 1) {
                int mol = i / 3;
                int cell = (k == 0) ? mol % 10 : (k == 1) ? (mol / 10) % 10 : (mol / 100) % 10;
                milli_nm = 310 * cell;
                if (i % 3 != 0) milli_nm += (int)(lcg_next(state) % 101u) - 50;
            } else if (kind == 2) {
                milli_nm = (int)(lcg_next(state) % 10000u);
            } else {
                if (i % 50 == 0)
                    walk[k] = (int)(lcg_next(state) % 2000000u);
                else
                    walk[k] += (int)(lcg_next(state) % 301u) - 150;
                milli_nm = walk[k];
            }
            coords[3 * i + k] = (float)milli_nm / 1000.0f;
        }
    }
}

/* ================================================================
 * TEST: high precisions round-trip
 *
 * At precisions around 1e5 and above, the encoder's step-down test
 * overflowed int and the decoder's receiveints shifted into the sign
 * bit -- both undefined behaviour. Run under UBSan this exercises
 * both paths. Kind 3 also exercises the large-range encoding.
 * ================================================================ */

static int test_3dfcoord_high_precision(void) {
    XDR xd;
    const char *f = "tmp_test_hiprec.xdr";
    const int natoms = 500;
    const float precisions[] = {1e5f, 1e6f};
    float *coords = (float *)malloc(natoms * 3 * sizeof(float));
    float *back = (float *)malloc(natoms * 3 * sizeof(float));
    int p, kind, i, n;

    for (p = 0; p < 2; p++) {
        for (kind = 0; kind < 4; kind++) {
            unsigned int state = 777u + (unsigned int)kind;
            float prec = precisions[p], rprec = 0;
            make_test_frame(kind, natoms, &state, coords);
            xdropen(&xd, f, "w");
            n = natoms;
            ASSERT_INT_EQ(xdr3dfcoord(&xd, coords, &n, &prec), 1);
            xdrclose(&xd);

            xdropen(&xd, f, "r");
            n = natoms;
            ASSERT_INT_EQ(xdr3dfcoord(&xd, back, &n, &rprec), 1);
            xdrclose(&xd);
            /* half a fixed-point step, plus float spacing: near 10 nm for
             * kinds 0-2, and up to 2000 nm for kind 3, where the spacing
             * is 1.2e-4 nm and the scaled value is rounded too */
            for (i = 0; i < natoms * 3; i++) {
                float spacing = (kind == 3) ? 2.0f * FLT_EPSILON * fabsf(coords[i]) : 1e-6f;
                ASSERT_FLOAT_EQ(back[i], coords[i], 0.5f / prec + spacing);
            }
        }
    }
    free(coords);
    free(back);
    cleanup(f);
    return 0;
}

/* ================================================================
 * TEST: the bytes written are pinned
 *
 * xdr3dfcoord's output is a file format shared with other XTC
 * readers and writers, so it must not drift. The hashes below were
 * produced by versions 1.5 and 1.6 built with GNU gcc (they agree),
 * and the cases at 1e5 and 1e6 drive the step-down heuristic into the
 * int overflow those versions had. (Optimised clang builds of 1.6
 * differ in those cases, because clang compared the overflowed values
 * as unsigned; see wrapped_sqr_distance in libxdrf.m4.) The kind 3
 * cases pin the large-range encoding, and at 1e6 the overflowed
 * Manhattan distance that picks the initial compression index (see
 * wrapped_manhattan_distance); summing it exactly changes those bytes.
 * ================================================================ */

static unsigned int fnv1a_file(const char *path) {
    FILE *fp = fopen(path, "rb");
    unsigned int hash = 2166136261u;
    int ch;
    if (fp == NULL) return 0;
    while ((ch = fgetc(fp)) != EOF) {
        hash ^= (unsigned int)ch;
        hash *= 16777619u;
    }
    fclose(fp);
    return hash;
}

static int test_3dfcoord_golden_bytes(void) {
    static const struct { int kind; float precision; unsigned int hash; } cases[] = {
        {0, 1e3f, 0x82d74392u},
        {0, 1e6f, 0x478224a4u},
        {1, 1e3f, 0xb6f5824cu},
        {1, 1e6f, 0xb24abb7fu},
        {2, 1e3f, 0x3a39ead4u},
        {2, 1e5f, 0x8c6b63b5u},
        {3, 1e5f, 0x2c012bd6u},
        {3, 1e6f, 0xc61c3bfdu},
    };
    const char *f = "tmp_test_golden.xdr";
    const int natoms = 500;
    float *coords = (float *)malloc(natoms * 3 * sizeof(float));
    int c, frame;

    for (c = 0; c < (int)(sizeof(cases) / sizeof(cases[0])); c++) {
        XDR xd;
        unsigned int state = 12345u + 31u * (unsigned int)cases[c].kind;
        unsigned int hash;
        float prec = cases[c].precision;
        int n;

        xdropen(&xd, f, "w");
        for (frame = 0; frame < 3; frame++) {
            make_test_frame(cases[c].kind, natoms, &state, coords);
            n = natoms;
            xdr3dfcoord(&xd, coords, &n, &prec);
        }
        xdrclose(&xd);
        hash = fnv1a_file(f);
        if (hash != cases[c].hash)
            fprintf(stderr, "\n    kind %d precision %g: hash %08x, expected %08x",
                    cases[c].kind, (double)prec, hash, cases[c].hash);
        ASSERT_MSG(hash == cases[c].hash, "xdr3dfcoord output bytes changed");
    }
    free(coords);
    cleanup(f);
    return 0;
}

/* ================================================================
 * TEST: xdr3dfcoord_peek_size reports the count without consuming it
 * ================================================================ */

static int test_peek_size(void) {
    XDR xd;
    const char *f = "tmp_test_peek.xdr";
    float coords[60], back[60];
    float prec = 1000.0f, rprec = 0;
    int n, peeked, sentinel = 4242, i;

    for (i = 0; i < 60; i++) coords[i] = (float)i * 0.05f;

    xdropen(&xd, f, "w");
    ASSERT_INT_EQ(xdr3dfcoord_peek_size(&xd, &peeked), 0); /* write stream */
    n = 20; xdr3dfcoord(&xd, coords, &n, &prec);           /* compressed */
    n = 5;  xdr3dfcoord(&xd, coords, &n, &prec);           /* uncompressed */
    xdr_int(&xd, &sentinel);
    xdrclose(&xd);

    xdropen(&xd, f, "r");
    peeked = 0;
    ASSERT_INT_EQ(xdr3dfcoord_peek_size(&xd, &peeked), 1);
    ASSERT_INT_EQ(peeked, 20);
    peeked = 0;
    ASSERT_INT_EQ(xdr3dfcoord_peek_size(&xd, &peeked), 1);  /* again: not consumed */
    ASSERT_INT_EQ(peeked, 20);
    n = peeked;
    ASSERT_INT_EQ(xdr3dfcoord(&xd, back, &n, &rprec), 1);

    ASSERT_INT_EQ(xdr3dfcoord_peek_size(&xd, &peeked), 1);
    ASSERT_INT_EQ(peeked, 5);
    n = peeked;
    ASSERT_INT_EQ(xdr3dfcoord(&xd, back, &n, &rprec), 1);
    for (i = 0; i < 15; i++)
        ASSERT_FLOAT_EQ(back[i], coords[i], 1e-6f);

    sentinel = 0;
    ASSERT_INT_EQ(xdr_int(&xd, &sentinel), 1);
    ASSERT_INT_EQ(sentinel, 4242);
    ASSERT_INT_EQ(xdr3dfcoord_peek_size(&xd, &peeked), 0);  /* end of file */
    xdrclose(&xd);

    cleanup(f);
    return 0;
}

/* ================================================================
 * TEST: xdrclose reports a write that never reached the disk
 *
 * The xdr calls only fill the stdio buffer, so running out of space
 * often first fails at the flush inside xdrclose, which used to
 * ignore it and return 1. A file-size limit stands in for a full disk;
 * it runs in a child process so the limit cannot leak into other
 * tests.
 * ================================================================ */

static int test_xdrclose_reports_write_error(void) {
    const char *f = "tmp_test_efbig.xdr";
    const rlim_t limit_bytes = 1000;
    pid_t child;
    int status = -1;

    child = fork();
    ASSERT_MSG(child >= 0, "fork should succeed");
    if (child == 0) {
        XDR xd;
        struct rlimit rl;
        int i, value = 7;
        rl.rlim_cur = rl.rlim_max = limit_bytes;
        signal(SIGXFSZ, SIG_IGN);  /* get EFBIG instead of being killed */
        setrlimit(RLIMIT_FSIZE, &rl);
        if (xdropen(&xd, f, "w") == 0) _exit(2);
        for (i = 0; i < 500; i++)  /* 2000 bytes, twice the limit */
            xdr_int(&xd, &value);
        _exit(xdrclose(&xd) == 0 ? 0 : 1);
    }
    waitpid(child, &status, 0);
    ASSERT_MSG(WIFEXITED(status), "child should exit normally");
    ASSERT_INT_EQ(WEXITSTATUS(status), 0);  /* 0: xdrclose returned 0 */

    cleanup(f);
    return 0;
}


/* ================================================================
 * MAIN
 * ================================================================ */

int main(void) {
    fprintf(stderr, "\n=== xdrf C API test suite ===\n\n");

    fprintf(stderr, "--- Open/Close ---\n");
    RUN_TEST(test_open_close_write);
    RUN_TEST(test_open_close_read);
    RUN_TEST(test_open_nonexistent_read);

    fprintf(stderr, "\n--- XDR primitive round-trips ---\n");
    RUN_TEST(test_int_roundtrip);
    RUN_TEST(test_float_roundtrip);
    RUN_TEST(test_double_roundtrip);
    RUN_TEST(test_short_roundtrip);
    RUN_TEST(test_char_roundtrip);
    RUN_TEST(test_string_roundtrip);
    RUN_TEST(test_bool_roundtrip);
    RUN_TEST(test_mixed_types);

    fprintf(stderr, "\n--- xdr3dfcoord ---\n");
    RUN_TEST(test_3dfcoord_small);
    RUN_TEST(test_3dfcoord_boundary_9);
    RUN_TEST(test_3dfcoord_10_atoms);
    RUN_TEST(test_3dfcoord_100_atoms);
    RUN_TEST(test_3dfcoord_1000_atoms);
    RUN_TEST(test_3dfcoord_precision);
    RUN_TEST(test_negative_coords);
    RUN_TEST(test_large_coords);
    RUN_TEST(test_3dfcoord_identical_coords);
    RUN_TEST(test_3dfcoord_scattered);
    RUN_TEST(test_3dfcoord_water_pattern);

    fprintf(stderr, "\n--- Advanced ---\n");
    RUN_TEST(test_append_mode);
    RUN_TEST(test_multiple_open_files);
    RUN_TEST(test_reopen_file);
    RUN_TEST(test_setpos_getpos);
    RUN_TEST(test_multiple_frames);
    RUN_TEST(test_3dfcoord_with_metadata);
    RUN_TEST(test_compression_ratio);

    fprintf(stderr, "\n--- Robustness (regressions) ---\n");
    RUN_TEST(test_mixed_ownership_close_order);
    RUN_TEST(test_3dfcoord_size_mismatch_refused);
    RUN_TEST(test_3dfcoord_rejects_corrupt_frames);
    RUN_TEST(test_uppercase_modes);
    RUN_TEST(test_unknown_stream_refused);
    RUN_TEST(test_3dfcoord_rejects_unstorable_input);
    RUN_TEST(test_3dfcoord_high_precision);
    RUN_TEST(test_3dfcoord_golden_bytes);
    RUN_TEST(test_peek_size);
    RUN_TEST(test_xdrclose_reports_write_error);

    fprintf(stderr, "\n=== Results: %d passed, %d failed, %d total ===\n\n",
            tests_passed, tests_failed, tests_run);

    return tests_failed > 0 ? 1 : 0;
}
