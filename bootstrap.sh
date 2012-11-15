#!/bin/bash -ex
#
# == Example ==
#
#   $ tap-autotools-bootstrap/bootstrap.sh \
#         test-project \
#         /Users/too1/Development/opt/port/share/automake-1.12/tap-driver.sh
#
#   $ cd test-project
#   $ ./configure
#   $ make check
#   make  check-TESTS
#   PASS: tests/hello.test 1 - Swallows fly
#   XFAIL: tests/hello.test 2 - Caterpillars fly # TODO metamorphosis in progress
#   SKIP: tests/hello.test 3 - Pigs fly # SKIP not enough acid
#   PASS: tests/hello.test 4 - Flies fly too :-)
#   make[3]: Nothing to be done for `all'.
#   ============================================================================
#   Testsuite summary for test 1.0
#   ============================================================================
#   # TOTAL: 4
#   # PASS:  2
#   # SKIP:  1
#   # XFAIL: 1
#   # FAIL:  0
#   # XPASS: 0
#   # ERROR: 0
#   ============================================================================

: ${CONFIG_AUX_DIR:=build-aux}
: ${ABS_SRCDIR:=$(cd "$(dirname "$0")" && pwd)}
: ${TAP_DRIVER:=${ABS_SRCDIR}/tap-driver.sh}
: ${LIBTAP_SH:=${ABS_SRCDIR}/c-tap-harness/tests/tap/libtap.sh}

if [ $# -ne 1 ]; then
    echo "Usage: $0 project_name"
    exit 1
else
    pushd "$(dirname "$0")"
        git submodule init
        git submodule update
    popd

    PROJECT=$1
    mkdir $PROJECT
    cd $PROJECT
fi


mkdir "$CONFIG_AUX_DIR"
cp "$TAP_DRIVER" "$CONFIG_AUX_DIR"

#------------------------------------------------------------------------------
# configure.ac
#------------------------------------------------------------------------------
cat > configure.ac <<-EOF
dnl ---------------------------------------------------------------------------
dnl Initialize Autoconf Project
dnl
AC_INIT([$PROJECT], [1.0])


dnl ---------------------------------------------------------------------------
dnl Setup Automake-TAP testing
dnl
dnl   Automake - Built-in parallel testing harness
dnl   TAP - TestAnythingProtocol
dnl

dnl
dnl Look for test-driver in this directory.
dnl See http://www.gnu.org/software/automake/manual/html_node/Optional.html
dnl
AC_CONFIG_AUX_DIR([$CONFIG_AUX_DIR])

dnl
dnl Use Automake's parallel testing harness
dnl
AM_INIT_AUTOMAKE([foreign parallel-tests -Wall -Werror])
AC_REQUIRE_AUX_FILE([tap-driver.sh])
AC_PROG_AWK


dnl ---------------------------------------------------------------------------
dnl Build Support
dnl

dnl Uncomment for C/C++ Autotools Support
dnl AC_PROG_CC
dnl AC_PROG_CXX

dnl Uncomment for Java Autotools Support
dnl JAVAC=javac
dnl AC_CHECK_CLASSPATH
dnl AC_PROG_JAVAC
dnl AC_PROG_JAVA


dnl ---------------------------------------------------------------------------
dnl Generate files
dnl

AC_CONFIG_FILES([
Makefile
])

AC_OUTPUT

cat <<-MSG

Configure complete, now type 'make check' to run the test suite.

MSG
EOF


#------------------------------------------------------------------------------
# Makefile.am
#------------------------------------------------------------------------------
cat > Makefile.am <<-EOF
# Make the libtap.sh file available to the Shell test scripts
export am_libtap_sh=\${abs_top_srcdir}/tests/libtap.sh

# Verbose use tap-driver.sh CLI option '--comments'
TEST_LOG_DRIVER = env AM_TAP_AWK='\$(AWK)' \$(SHELL) \\
                      \$(top_srcdir)/build-aux/tap-driver.sh
TESTS = tests/hello.test
EXTRA_DIST = \$(TESTS)
EOF

mkdir tests

pushd tests
  cp "$LIBTAP_SH" .
  chmod +x libtap.sh
popd

cat > tests/hello.test <<-EOF
#!/bin/sh

source \$am_libtap_sh

plan  4
ok    'Swallows fly' true
ok    'Caterpillars fly # TODO metamorphosis in progress' false
skip  'Pigs fly # SKIP not enough acid'
diag  '# I just love word plays ...'
ok    'Flies fly too :-)' true
EOF
chmod +x tests/hello.test


#------------------------------------------------------------------------------
# Autotools Bootstrap!
#------------------------------------------------------------------------------
cat > bootstrap.sh <<-EOF
#!/bin/bash -x
aclocal
autoconf
automake -a
EOF
chmod +x bootstrap.sh
./bootstrap.sh

cat <<-EOF

Bootstrapping complete, now type './configure' to configure your project with Autoconf.

EOF

cat > .gitignore <<-EOF
# Editor backups
*~
# libtool temp dir
.libs
# .svn files
.svn
# editor temp file
.*swo
*.swp
*.dump2
*.o
# /
Makefile.in
/aclocal.m4
/rose_config.h.in
/configure
/autom4te.cache
/*.tar.gz
/libltdl

# /config/
config.guess
config.sub
install-sh
ltmain.sh
depcomp
missing

#

workspace
build_tree

# OS X Finder files
.DS_Store
EOF

git init .
git add .
git commit -a -m "Add initial content from bootstrap"

mkdir build_tree
cd build_tree

../configure
make check
