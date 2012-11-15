# tap-autotools-bootstrap

## Example

```bash
$ tap-autotools-bootstrap/bootstrap.sh \
      test-project \
      /Users/too1/Development/opt/port/share/automake-1.12/tap-driver.sh

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

