c     ================================================================
c     test_fortran.f - Test suite for the xdrf Fortran interface.
c
c     Tests all Fortran wrapper functions: xdrfopen, xdrfclose,
c     xdrfint, xdrffloat, xdrfdouble, xdrfshort, xdrfchar, xdrfbool,
c     xdrflong, xdrfulong, xdrfopaque, xdrf3dfcoord, xdrfstring,
c     xdrfwrapstring, xdrfsetpos, xdrf, and xdrfvector, plus the
c     handling of an id that does not name an open file.
c
c     Exit code: 0 if all tests pass, 1 on failure.
c     Prints PASS/FAIL for each test to stderr.
c     ================================================================

      program test_fortran
      implicit none
      integer npass, nfail
      npass = 0
      nfail = 0

      write(0,*) ''
      write(0,*) '=== xdrf Fortran API test suite ==='
      write(0,*) ''

      call test_int_roundtrip(npass, nfail)
      call test_float_roundtrip(npass, nfail)
      call test_double_roundtrip(npass, nfail)
      call test_short_roundtrip(npass, nfail)
      call test_char_roundtrip(npass, nfail)
      call test_bool_roundtrip(npass, nfail)
      call test_mixed_types(npass, nfail)
      call test_3dfcoord_small(npass, nfail)
      call test_3dfcoord_compressed(npass, nfail)
      call test_3dfcoord_100(npass, nfail)
      call test_multi_frame(npass, nfail)
      call test_negative_coords(npass, nfail)
      call test_setpos_getpos(npass, nfail)
      call test_vector_float(npass, nfail)
      call test_reopen(npass, nfail)
      call test_string_roundtrip(npass, nfail)
      call test_opaque_roundtrip(npass, nfail)
      call test_long_roundtrip(npass, nfail)
      call test_vector_long(npass, nfail)
      call test_vector_empty(npass, nfail)
      call test_bad_handle(npass, nfail)
      call test_wrapstring_too_long(npass, nfail)

      write(0,*) ''
      write(0,'(A,I3,A,I3,A,I3,A)') ' === Results: ',
     &  npass, ' passed, ', nfail, ' failed, ',
     &  npass+nfail, ' total ==='
      write(0,*) ''

      if (nfail .gt. 0) then
        call exit(1)
      end if
      end


c     ================================================================
c     test_int_roundtrip - Write and read back integers
c     ================================================================
      subroutine test_int_roundtrip(npass, nfail)
      implicit none
      integer npass, nfail
      integer xd, ret, i
      integer vals(5), rvals(5)

      vals(1) = 0
      vals(2) = 1
      vals(3) = -1
      vals(4) = 2147483647
      vals(5) = -2147483647

      call xdrfopen(xd, 'tmp_ftest_int.xdr', 'w', ret)
      if (ret .eq. 0) goto 900
      do i = 1, 5
        call xdrfint(xd, vals(i), ret)
      end do
      call xdrfclose(xd, ret)

      call xdrfopen(xd, 'tmp_ftest_int.xdr', 'r', ret)
      if (ret .eq. 0) goto 900
      do i = 1, 5
        rvals(i) = 0
        call xdrfint(xd, rvals(i), ret)
        if (rvals(i) .ne. vals(i)) goto 900
      end do
      call xdrfclose(xd, ret)

      write(0,*) '  test_int_roundtrip ... ok'
      npass = npass + 1
      return

 900  write(0,*) '  test_int_roundtrip ... FAIL'
      nfail = nfail + 1
      return
      end


c     ================================================================
c     test_float_roundtrip - Write and read back floats
c     ================================================================
      subroutine test_float_roundtrip(npass, nfail)
      implicit none
      integer npass, nfail
      integer xd, ret, i
      real vals(4), rvals(4)

      vals(1) = 0.0
      vals(2) = 3.14159
      vals(3) = -1.0e10
      vals(4) = 1.0e-10

      call xdrfopen(xd, 'tmp_ftest_flt.xdr', 'w', ret)
      do i = 1, 4
        call xdrffloat(xd, vals(i), ret)
      end do
      call xdrfclose(xd, ret)

      call xdrfopen(xd, 'tmp_ftest_flt.xdr', 'r', ret)
      do i = 1, 4
        rvals(i) = 0.0
        call xdrffloat(xd, rvals(i), ret)
        if (abs(rvals(i) - vals(i)) .gt. 1.0e-5 * abs(vals(i)+1.0))
     &    goto 900
      end do
      call xdrfclose(xd, ret)

      write(0,*) '  test_float_roundtrip ... ok'
      npass = npass + 1
      return

 900  write(0,*) '  test_float_roundtrip ... FAIL'
      nfail = nfail + 1
      return
      end


c     ================================================================
c     test_double_roundtrip - Write and read back doubles
c     ================================================================
      subroutine test_double_roundtrip(npass, nfail)
      implicit none
      integer npass, nfail
      integer xd, ret, i
      double precision vals(3), rvals(3)

      vals(1) = 0.0d0
      vals(2) = 3.141592653589793d0
      vals(3) = -1.0d100

      call xdrfopen(xd, 'tmp_ftest_dbl.xdr', 'w', ret)
      do i = 1, 3
        call xdrfdouble(xd, vals(i), ret)
      end do
      call xdrfclose(xd, ret)

      call xdrfopen(xd, 'tmp_ftest_dbl.xdr', 'r', ret)
      do i = 1, 3
        rvals(i) = 0.0d0
        call xdrfdouble(xd, rvals(i), ret)
        if (abs(rvals(i) - vals(i)) .gt. 1.0d-10 * abs(vals(i)+1.0d0))
     &    goto 900
      end do
      call xdrfclose(xd, ret)

      write(0,*) '  test_double_roundtrip ... ok'
      npass = npass + 1
      return

 900  write(0,*) '  test_double_roundtrip ... FAIL'
      nfail = nfail + 1
      return
      end


c     ================================================================
c     test_short_roundtrip - Write and read back short integers
c     ================================================================
      subroutine test_short_roundtrip(npass, nfail)
      implicit none
      integer npass, nfail
      integer xd, ret, i
      integer*2 vals(3), rvals(3)

      vals(1) = 0
      vals(2) = 32767
      vals(3) = -32768

      call xdrfopen(xd, 'tmp_ftest_sht.xdr', 'w', ret)
      do i = 1, 3
        call xdrfshort(xd, vals(i), ret)
      end do
      call xdrfclose(xd, ret)

      call xdrfopen(xd, 'tmp_ftest_sht.xdr', 'r', ret)
      do i = 1, 3
        rvals(i) = 0
        call xdrfshort(xd, rvals(i), ret)
        if (rvals(i) .ne. vals(i)) goto 900
      end do
      call xdrfclose(xd, ret)

      write(0,*) '  test_short_roundtrip ... ok'
      npass = npass + 1
      return

 900  write(0,*) '  test_short_roundtrip ... FAIL'
      nfail = nfail + 1
      return
      end


c     ================================================================
c     test_char_roundtrip - Write and read back characters
c     ================================================================
      subroutine test_char_roundtrip(npass, nfail)
      implicit none
      integer npass, nfail
      integer xd, ret
      character c1, c2, c3, r1, r2, r3

      c1 = 'A'
      c2 = 'z'
      c3 = '0'

      call xdrfopen(xd, 'tmp_ftest_chr.xdr', 'w', ret)
      call xdrfchar(xd, c1, ret)
      call xdrfchar(xd, c2, ret)
      call xdrfchar(xd, c3, ret)
      call xdrfclose(xd, ret)

      call xdrfopen(xd, 'tmp_ftest_chr.xdr', 'r', ret)
      call xdrfchar(xd, r1, ret)
      call xdrfchar(xd, r2, ret)
      call xdrfchar(xd, r3, ret)
      call xdrfclose(xd, ret)

      if (r1 .ne. 'A' .or. r2 .ne. 'z' .or. r3 .ne. '0') goto 900

      write(0,*) '  test_char_roundtrip ... ok'
      npass = npass + 1
      return

 900  write(0,*) '  test_char_roundtrip ... FAIL'
      nfail = nfail + 1
      return
      end


c     ================================================================
c     test_bool_roundtrip - Write and read back booleans
c     ================================================================
      subroutine test_bool_roundtrip(npass, nfail)
      implicit none
      integer npass, nfail
      integer xd, ret
      integer b1, b2, b3, r1, r2, r3

      b1 = 1
      b2 = 0
      b3 = 1

      call xdrfopen(xd, 'tmp_ftest_bool.xdr', 'w', ret)
      call xdrfbool(xd, b1, ret)
      call xdrfbool(xd, b2, ret)
      call xdrfbool(xd, b3, ret)
      call xdrfclose(xd, ret)

      r1 = -1
      r2 = -1
      r3 = -1
      call xdrfopen(xd, 'tmp_ftest_bool.xdr', 'r', ret)
      call xdrfbool(xd, r1, ret)
      call xdrfbool(xd, r2, ret)
      call xdrfbool(xd, r3, ret)
      call xdrfclose(xd, ret)

      if (r1 .ne. 1 .or. r2 .ne. 0 .or. r3 .ne. 1) goto 900

      write(0,*) '  test_bool_roundtrip ... ok'
      npass = npass + 1
      return

 900  write(0,*) '  test_bool_roundtrip ... FAIL'
      nfail = nfail + 1
      return
      end


c     ================================================================
c     test_mixed_types - Write and read a mix of types in one file
c     ================================================================
      subroutine test_mixed_types(npass, nfail)
      implicit none
      integer npass, nfail
      integer xd, ret
      integer wi, ri
      real wf, rf
      double precision wd, rd
      character wc, rc

      wi = 42
      wf = 3.14
      wd = 2.718281828d0
      wc = 'X'

      call xdrfopen(xd, 'tmp_ftest_mix.xdr', 'w', ret)
      call xdrfint(xd, wi, ret)
      call xdrffloat(xd, wf, ret)
      call xdrfdouble(xd, wd, ret)
      call xdrfchar(xd, wc, ret)
      call xdrfclose(xd, ret)

      ri = 0
      rf = 0.0
      rd = 0.0d0
      rc = ' '
      call xdrfopen(xd, 'tmp_ftest_mix.xdr', 'r', ret)
      call xdrfint(xd, ri, ret)
      call xdrffloat(xd, rf, ret)
      call xdrfdouble(xd, rd, ret)
      call xdrfchar(xd, rc, ret)
      call xdrfclose(xd, ret)

      if (ri .ne. 42) goto 900
      if (abs(rf - 3.14) .gt. 1.0e-5) goto 900
      if (abs(rd - 2.718281828d0) .gt. 1.0d-9) goto 900
      if (rc .ne. 'X') goto 900

      write(0,*) '  test_mixed_types ... ok'
      npass = npass + 1
      return

 900  write(0,*) '  test_mixed_types ... FAIL'
      nfail = nfail + 1
      return
      end


c     ================================================================
c     test_3dfcoord_small - Test with <=9 atoms (uncompressed path)
c     ================================================================
      subroutine test_3dfcoord_small(npass, nfail)
      implicit none
      integer npass, nfail
      integer xd, ret, i
      integer size
      real prec, rprec
      real coords(15), coords2(15)

      size = 5
      prec = 1000.0
      do i = 1, 15
        coords(i) = real(i) * 0.123
      end do

      call xdrfopen(xd, 'tmp_ftest_3ds.xdr', 'w', ret)
      if (ret .eq. 0) goto 900
      call xdrf3dfcoord(xd, coords, size, prec, ret)
      if (ret .eq. 0) goto 900
      call xdrfclose(xd, ret)

      do i = 1, 15
        coords2(i) = 0.0
      end do
      size = 0
      rprec = 0.0
      call xdrfopen(xd, 'tmp_ftest_3ds.xdr', 'r', ret)
      call xdrf3dfcoord(xd, coords2, size, rprec, ret)
      if (ret .eq. 0) goto 900
      call xdrfclose(xd, ret)

      if (size .ne. 5) goto 900
      do i = 1, 15
        if (abs(coords2(i) - coords(i)) .gt. 0.001) goto 900
      end do

      write(0,*) '  test_3dfcoord_small ... ok'
      npass = npass + 1
      return

 900  write(0,*) '  test_3dfcoord_small ... FAIL'
      nfail = nfail + 1
      return
      end


c     ================================================================
c     test_3dfcoord_compressed - Test with >9 atoms (compressed path)
c     ================================================================
      subroutine test_3dfcoord_compressed(npass, nfail)
      implicit none
      integer npass, nfail
      integer xd, ret, i
      integer size
      real prec, rprec
      real coords(60), coords2(60)

      size = 20
      prec = 1000.0
      do i = 1, 60
        coords(i) = 1.0 + real(mod(i, 10)) * 0.1
      end do

      call xdrfopen(xd, 'tmp_ftest_3dc.xdr', 'w', ret)
      call xdrf3dfcoord(xd, coords, size, prec, ret)
      if (ret .eq. 0) goto 900
      call xdrfclose(xd, ret)

      do i = 1, 60
        coords2(i) = 0.0
      end do
      size = 0
      rprec = 0.0
      call xdrfopen(xd, 'tmp_ftest_3dc.xdr', 'r', ret)
      call xdrf3dfcoord(xd, coords2, size, rprec, ret)
      if (ret .eq. 0) goto 900
      call xdrfclose(xd, ret)

      if (size .ne. 20) goto 900
      if (abs(rprec - 1000.0) .gt. 0.001) goto 900
      do i = 1, 60
        if (abs(coords2(i) - coords(i)) .gt. 0.002) goto 900
      end do

      write(0,*) '  test_3dfcoord_compressed ... ok'
      npass = npass + 1
      return

 900  write(0,*) '  test_3dfcoord_compressed ... FAIL'
      nfail = nfail + 1
      return
      end


c     ================================================================
c     test_3dfcoord_100 - Test with 100 atoms
c     ================================================================
      subroutine test_3dfcoord_100(npass, nfail)
      implicit none
      integer npass, nfail
      integer xd, ret, i
      integer size
      real prec, rprec
      real coords(300), coords2(300)

      size = 100
      prec = 1000.0
      do i = 1, 300
        coords(i) = real(mod(i, 50)) * 0.1
      end do

      call xdrfopen(xd, 'tmp_ftest_3d100.xdr', 'w', ret)
      call xdrf3dfcoord(xd, coords, size, prec, ret)
      if (ret .eq. 0) goto 900
      call xdrfclose(xd, ret)

      do i = 1, 300
        coords2(i) = 0.0
      end do
      size = 0
      rprec = 0.0
      call xdrfopen(xd, 'tmp_ftest_3d100.xdr', 'r', ret)
      call xdrf3dfcoord(xd, coords2, size, rprec, ret)
      if (ret .eq. 0) goto 900
      call xdrfclose(xd, ret)

      if (size .ne. 100) goto 900
      do i = 1, 300
        if (abs(coords2(i) - coords(i)) .gt. 0.002) goto 900
      end do

      write(0,*) '  test_3dfcoord_100 ... ok'
      npass = npass + 1
      return

 900  write(0,*) '  test_3dfcoord_100 ... FAIL'
      nfail = nfail + 1
      return
      end


c     ================================================================
c     test_multi_frame - Test multiple frames in one file
c     ================================================================
      subroutine test_multi_frame(npass, nfail)
      implicit none
      integer npass, nfail
      integer xd, ret, i, j
      integer nframes, size
      real prec, rprec
      real coords(150), coords2(150)

      nframes = 3
      size = 50
      prec = 1000.0

      call xdrfopen(xd, 'tmp_ftest_mf.xdr', 'w', ret)
      call xdrfint(xd, nframes, ret)
      do j = 1, nframes
        do i = 1, 150
          coords(i) = real(j * 150 + i) * 0.001
        end do
        call xdrf3dfcoord(xd, coords, size, prec, ret)
        if (ret .eq. 0) goto 900
      end do
      call xdrfclose(xd, ret)

      call xdrfopen(xd, 'tmp_ftest_mf.xdr', 'r', ret)
      nframes = 0
      call xdrfint(xd, nframes, ret)
      if (nframes .ne. 3) goto 900

      do j = 1, 3
        size = 0
        rprec = 0.0
        call xdrf3dfcoord(xd, coords2, size, rprec, ret)
        if (ret .eq. 0) goto 900
        if (size .ne. 50) goto 900
c       Regenerate expected
        do i = 1, 150
          coords(i) = real(j * 150 + i) * 0.001
        end do
        do i = 1, 150
          if (abs(coords2(i) - coords(i)) .gt. 0.002) goto 900
        end do
      end do
      call xdrfclose(xd, ret)

      write(0,*) '  test_multi_frame ... ok'
      npass = npass + 1
      return

 900  write(0,*) '  test_multi_frame ... FAIL'
      nfail = nfail + 1
      return
      end


c     ================================================================
c     test_negative_coords - Test negative coordinate values
c     ================================================================
      subroutine test_negative_coords(npass, nfail)
      implicit none
      integer npass, nfail
      integer xd, ret, i
      integer size
      real prec, rprec
      real coords(60), coords2(60)

      size = 20
      prec = 1000.0
      do i = 1, 60
        coords(i) = -5.0 + real(i) * 0.1
      end do

      call xdrfopen(xd, 'tmp_ftest_neg.xdr', 'w', ret)
      call xdrf3dfcoord(xd, coords, size, prec, ret)
      if (ret .eq. 0) goto 900
      call xdrfclose(xd, ret)

      do i = 1, 60
        coords2(i) = 0.0
      end do
      size = 0
      rprec = 0.0
      call xdrfopen(xd, 'tmp_ftest_neg.xdr', 'r', ret)
      call xdrf3dfcoord(xd, coords2, size, rprec, ret)
      if (ret .eq. 0) goto 900
      call xdrfclose(xd, ret)

      if (size .ne. 20) goto 900
      do i = 1, 60
        if (abs(coords2(i) - coords(i)) .gt. 0.002) goto 900
      end do

      write(0,*) '  test_negative_coords ... ok'
      npass = npass + 1
      return

 900  write(0,*) '  test_negative_coords ... FAIL'
      nfail = nfail + 1
      return
      end


c     ================================================================
c     test_setpos_getpos - Test xdrfsetpos and xdrf (getpos)
c     ================================================================
      subroutine test_setpos_getpos(npass, nfail)
      implicit none
      integer npass, nfail
      integer xd, ret
      integer v1, v2, v3, rv, pos

      v1 = 11
      v2 = 22
      v3 = 33

      call xdrfopen(xd, 'tmp_ftest_pos.xdr', 'w', ret)
      call xdrfint(xd, v1, ret)
      call xdrf(xd, pos)
      call xdrfint(xd, v2, ret)
      call xdrfint(xd, v3, ret)
      call xdrfclose(xd, ret)

c     Read: seek past first int, read v2
      call xdrfopen(xd, 'tmp_ftest_pos.xdr', 'r', ret)
      call xdrfsetpos(xd, pos, ret)
      if (ret .eq. 0) goto 900
      rv = 0
      call xdrfint(xd, rv, ret)
      if (rv .ne. 22) goto 900
      rv = 0
      call xdrfint(xd, rv, ret)
      if (rv .ne. 33) goto 900
      call xdrfclose(xd, ret)

      write(0,*) '  test_setpos_getpos ... ok'
      npass = npass + 1
      return

 900  write(0,*) '  test_setpos_getpos ... FAIL'
      nfail = nfail + 1
      return
      end


c     ================================================================
c     test_vector_float - Test xdrfvector with float data
c     ================================================================
      subroutine test_vector_float(npass, nfail)
      implicit none
      integer npass, nfail
      integer xd, ret, i
      integer size
      real data(10), rdata(10)
      external xdrffloat

      size = 10
      do i = 1, 10
        data(i) = real(i) * 1.1
      end do

      call xdrfopen(xd, 'tmp_ftest_vec.xdr', 'w', ret)
      call xdrfvector(xd, data, size, xdrffloat, ret)
      call xdrfclose(xd, ret)

      do i = 1, 10
        rdata(i) = 0.0
      end do
      call xdrfopen(xd, 'tmp_ftest_vec.xdr', 'r', ret)
      call xdrfvector(xd, rdata, size, xdrffloat, ret)
      call xdrfclose(xd, ret)

      do i = 1, 10
        if (abs(rdata(i) - data(i)) .gt. 1.0e-5) goto 900
      end do

      write(0,*) '  test_vector_float ... ok'
      npass = npass + 1
      return

 900  write(0,*) '  test_vector_float ... FAIL'
      nfail = nfail + 1
      return
      end


c     ================================================================
c     test_reopen - Write, close, read multiple times
c     ================================================================
      subroutine test_reopen(npass, nfail)
      implicit none
      integer npass, nfail
      integer xd, ret, i
      integer wval, rval

      do i = 1, 3
        wval = i * 100

        call xdrfopen(xd, 'tmp_ftest_reopen.xdr', 'w', ret)
        if (ret .eq. 0) goto 900
        call xdrfint(xd, wval, ret)
        call xdrfclose(xd, ret)

        rval = 0
        call xdrfopen(xd, 'tmp_ftest_reopen.xdr', 'r', ret)
        if (ret .eq. 0) goto 900
        call xdrfint(xd, rval, ret)
        call xdrfclose(xd, ret)

        if (rval .ne. i * 100) goto 900
      end do

      write(0,*) '  test_reopen ... ok'
      npass = npass + 1
      return

 900  write(0,*) '  test_reopen ... FAIL'
      nfail = nfail + 1
      return
      end


c     ================================================================
c     test_string_roundtrip - xdrfstring and xdrfwrapstring, and
c     ret = 0 (not -1) when xdrfstring is given a negative maxsize
c     ================================================================
      subroutine test_string_roundtrip(npass, nfail)
      implicit none
      integer npass, nfail
      integer xd, ret, maxsize
      character*16 s, back

      s = 'hello xdr'
      maxsize = 16

      call xdrfopen(xd, 'tmp_ftest_str.xdr', 'w', ret)
      if (ret .eq. 0) goto 900
      call xdrfstring(xd, s, maxsize, ret)
      if (ret .eq. 0) goto 900
      call xdrfwrapstring(xd, s, ret)
      if (ret .eq. 0) goto 900
      call xdrfclose(xd, ret)

      call xdrfopen(xd, 'tmp_ftest_str.xdr', 'r', ret)
      if (ret .eq. 0) goto 900
      back = 'xxxxxxxxxxxxxxxx'
      call xdrfstring(xd, back, maxsize, ret)
      if (ret .eq. 0 .or. back .ne. s) goto 900
      back = 'xxxxxxxxxxxxxxxx'
      call xdrfwrapstring(xd, back, ret)
      if (ret .eq. 0 .or. back .ne. s) goto 900
      call xdrfclose(xd, ret)

      call xdrfopen(xd, 'tmp_ftest_str.xdr', 'r', ret)
      maxsize = -1
      ret = -99
      call xdrfstring(xd, back, maxsize, ret)
      if (ret .ne. 0) goto 900
      call xdrfclose(xd, ret)

      write(0,*) '  test_string_roundtrip ... ok'
      npass = npass + 1
      return

 900  write(0,*) '  test_string_roundtrip ... FAIL'
      nfail = nfail + 1
      return
      end


c     ================================================================
c     test_opaque_roundtrip - xdrfopaque on an ordinary array. It used
c     to take the first bytes of the data as an address and crash.
c     ================================================================
      subroutine test_opaque_roundtrip(npass, nfail)
      implicit none
      integer npass, nfail
      integer xd, ret, nbytes
      real wbuf(2), rbuf(2)

      wbuf(1) = 1.5
      wbuf(2) = -2.25
      rbuf(1) = 0.0
      rbuf(2) = 0.0
      nbytes = 8

      call xdrfopen(xd, 'tmp_ftest_opaque.xdr', 'w', ret)
      if (ret .eq. 0) goto 900
      call xdrfopaque(xd, wbuf, nbytes, ret)
      if (ret .eq. 0) goto 900
      call xdrfclose(xd, ret)

      call xdrfopen(xd, 'tmp_ftest_opaque.xdr', 'r', ret)
      if (ret .eq. 0) goto 900
      call xdrfopaque(xd, rbuf, nbytes, ret)
      if (ret .eq. 0) goto 900
      call xdrfclose(xd, ret)

      if (rbuf(1) .ne. wbuf(1) .or. rbuf(2) .ne. wbuf(2)) goto 900

      write(0,*) '  test_opaque_roundtrip ... ok'
      npass = npass + 1
      return

 900  write(0,*) '  test_opaque_roundtrip ... FAIL'
      nfail = nfail + 1
      return
      end


c     ================================================================
c     test_long_roundtrip - xdrflong and xdrfulong on default integers.
c     They used to store 8 bytes into the 4-byte integer, zeroing the
c     next variable. An xdr long is an xdr int on the wire, so the
c     file must also read back with xdrfint.
c     ================================================================
      subroutine test_long_roundtrip(npass, nfail)
      implicit none
      integer npass, nfail
      integer xd, ret
      integer vals(3), back(4)

      vals(1) = 123456
      vals(2) = -7
      vals(3) = 2147483647

      call xdrfopen(xd, 'tmp_ftest_long.xdr', 'w', ret)
      if (ret .eq. 0) goto 900
      call xdrflong(xd, vals(1), ret)
      if (ret .eq. 0) goto 900
      call xdrflong(xd, vals(2), ret)
      if (ret .eq. 0) goto 900
      call xdrfulong(xd, vals(3), ret)
      if (ret .eq. 0) goto 900
      call xdrfclose(xd, ret)

c     back(2) and back(4) are sentinels for the neighbour overwrite
      back(1) = 0
      back(2) = 777
      back(3) = 0
      back(4) = 888
      call xdrfopen(xd, 'tmp_ftest_long.xdr', 'r', ret)
      if (ret .eq. 0) goto 900
      call xdrflong(xd, back(1), ret)
      if (ret .eq. 0) goto 900
      if (back(2) .ne. 777) goto 900
      call xdrflong(xd, back(2), ret)
      if (ret .eq. 0) goto 900
      call xdrfulong(xd, back(3), ret)
      if (ret .eq. 0) goto 900
      call xdrfclose(xd, ret)
      if (back(1) .ne. vals(1)) goto 900
      if (back(2) .ne. vals(2)) goto 900
      if (back(3) .ne. vals(3)) goto 900
      if (back(4) .ne. 888) goto 900

      call xdrfopen(xd, 'tmp_ftest_long.xdr', 'r', ret)
      back(1) = 0
      call xdrfint(xd, back(1), ret)
      call xdrfclose(xd, ret)
      if (back(1) .ne. vals(1)) goto 900

      write(0,*) '  test_long_roundtrip ... ok'
      npass = npass + 1
      return

 900  write(0,*) '  test_long_roundtrip ... FAIL'
      nfail = nfail + 1
      return
      end


c     ================================================================
c     test_vector_long - xdrfvector over xdrflong. The old 8-byte
c     stride skipped every other element and wrote past the array.
c     The integers share storage with a real array (equivalence)
c     because gfortran rejects passing different types to the same
c     external routine within one file.
c     ================================================================
      subroutine test_vector_long(npass, nfail)
      implicit none
      integer npass, nfail
      integer xd, ret, i, size
      integer ivals(4), iback(5)
      real rvals(4), rback(5)
      equivalence (ivals, rvals), (iback, rback)
      external xdrflong

      size = 4
      do i = 1, 4
        ivals(i) = 10 * i
      end do
      do i = 1, 5
        iback(i) = -1
      end do

      call xdrfopen(xd, 'tmp_ftest_veclong.xdr', 'w', ret)
      if (ret .eq. 0) goto 900
      call xdrfvector(xd, rvals, size, xdrflong, ret)
      if (ret .eq. 0) goto 900
      call xdrfclose(xd, ret)

      call xdrfopen(xd, 'tmp_ftest_veclong.xdr', 'r', ret)
      if (ret .eq. 0) goto 900
      call xdrfvector(xd, rback, size, xdrflong, ret)
      if (ret .eq. 0) goto 900
      call xdrfclose(xd, ret)

      do i = 1, 4
        if (iback(i) .ne. ivals(i)) goto 900
      end do
      if (iback(5) .ne. -1) goto 900

      write(0,*) '  test_vector_long ... ok'
      npass = npass + 1
      return

 900  write(0,*) '  test_vector_long ... FAIL'
      nfail = nfail + 1
      return
      end


c     ================================================================
c     test_vector_empty - xdrfvector with size 0 must report success;
c     ret used to be left unset
c     ================================================================
      subroutine test_vector_empty(npass, nfail)
      implicit none
      integer npass, nfail
      integer xd, ret, size
      real data(1)
      external xdrffloat

      size = 0
      call xdrfopen(xd, 'tmp_ftest_vecempty.xdr', 'w', ret)
      if (ret .eq. 0) goto 900
      ret = -99
      call xdrfvector(xd, data, size, xdrffloat, ret)
      if (ret .ne. 1) goto 900
      call xdrfclose(xd, ret)

      write(0,*) '  test_vector_empty ... ok'
      npass = npass + 1
      return

 900  write(0,*) '  test_vector_empty ... FAIL'
      nfail = nfail + 1
      return
      end


c     ================================================================
c     test_bad_handle - routines given an id that does not name an
c     open file (from a failed open, or already closed) report
c     ret = 0. They used to dereference a NULL stream and crash.
c     ================================================================
      subroutine test_bad_handle(npass, nfail)
      implicit none
      integer npass, nfail
      integer xd, ret, ival, pos, size
      real rdummy(1)
      external xdrffloat

      ival = 0
      call xdrfopen(xd, 'no_such_dir/tmp_ftest_x.xdr', 'r', ret)
      if (ret .ne. 0) goto 900

      ret = -99
      call xdrfint(xd, ival, ret)
      if (ret .ne. 0) goto 900
      call xdrf(xd, pos)
      if (pos .ne. -1) goto 900
      ret = -99
      call xdrfclose(xd, ret)
      if (ret .ne. 0) goto 900

      call xdrfopen(xd, 'tmp_ftest_bad.xdr', 'w', ret)
      if (ret .eq. 0) goto 900
      call xdrfclose(xd, ret)
      ret = -99
      call xdrfint(xd, ival, ret)
      if (ret .ne. 0) goto 900
c     an empty vector never calls the element routine, so xdrfvector
c     has to check the id itself (it used to report success). The
c     arguments match the other xdrfvector calls in this file, which
c     gfortran 10 and later require.
      size = 0
      ret = -99
      call xdrfvector(xd, rdummy, size, xdrffloat, ret)
      if (ret .ne. 0) goto 900

      write(0,*) '  test_bad_handle ... ok'
      npass = npass + 1
      return

 900  write(0,*) '  test_bad_handle ... FAIL'
      nfail = nfail + 1
      return
      end

c     ================================================================
c     test_wrapstring_too_long - a string one character longer than
c     the variable it is read into must be refused, not truncated
c     (xdrfwrapstring used to allow one extra character and drop it)
c     ================================================================
      subroutine test_wrapstring_too_long(npass, nfail)
      implicit none
      integer npass, nfail
      integer xd, ret
      character*10 s10
      character*9 s9

      s10 = 'ABCDEFGHIJ'
      call xdrfopen(xd, 'tmp_ftest_wrap.xdr', 'w', ret)
      if (ret .eq. 0) goto 900
      call xdrfwrapstring(xd, s10, ret)
      if (ret .eq. 0) goto 900
      call xdrfclose(xd, ret)

      call xdrfopen(xd, 'tmp_ftest_wrap.xdr', 'r', ret)
      if (ret .eq. 0) goto 900
      s9 = '?????????'
      ret = -99
      call xdrfwrapstring(xd, s9, ret)
      if (ret .ne. 0 .or. s9 .ne. '?????????') goto 900
      call xdrfclose(xd, ret)

      write(0,*) '  test_wrapstring_too_long ... ok'
      npass = npass + 1
      return

 900  write(0,*) '  test_wrapstring_too_long ... FAIL'
      nfail = nfail + 1
      return
      end
