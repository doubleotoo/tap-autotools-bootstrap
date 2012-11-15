# tap-autotools-bootstrap

Tested with these Autotools:

```bash
$ autoconf --version
autoconf (GNU Autoconf) 2.69
Copyright (C) 2012 Free Software Foundation, Inc.
License GPLv3+/Autoconf: GNU GPL version 3 or later
<http://gnu.org/licenses/gpl.html>, <http://gnu.org/licenses/exceptions.html>
This is free software: you are free to change and redistribute it.
There is NO WARRANTY, to the extent permitted by law.

Written by David J. MacKenzie and Akim Demaille.

$ automake --version
automake (GNU automake) 1.12
Copyright (C) 2011 Free Software Foundation, Inc.
License GPLv2+: GNU GPL version 2 or later <http://gnu.org/licenses/gpl-2.0.html>
This is free software: you are free to change and redistribute it.
There is NO WARRANTY, to the extent permitted by law.

Written by Tom Tromey <tromey@redhat.com>
       and Alexandre Duret-Lutz <adl@gnu.org>.
```

## Example

```bash
$ tap-autotools-bootstrap/bootstrap.sh test-project
$ cd test-project

$ ./configure
$ make check
make  check-TESTS
PASS: tests/hello.test 1 - Swallows fly
XFAIL: tests/hello.test 2 - Caterpillars fly # TODO metamorphosis in progress
SKIP: tests/hello.test 3 - Pigs fly # SKIP not enough acid
PASS: tests/hello.test 4 - Flies fly too :-)
make[3]: Nothing to be done for `all'.
============================================================================
Testsuite summary for test 1.0
============================================================================
# TOTAL: 4
# PASS:  2
# SKIP:  1
# XFAIL: 1
# FAIL:  0
# XPASS: 0
# ERROR: 0
============================================================================
```

