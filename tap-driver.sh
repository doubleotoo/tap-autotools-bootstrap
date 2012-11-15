#! /bin/sh
#
# Copied version:
#
#   $ automake --version
#   automake (GNU automake) 1.12
#   Copyright (C) 2011 Free Software Foundation, Inc.
#   License GPLv2+: GNU GPL version 2 or later <http://gnu.org/licenses/gpl-2.0.html>
#   This is free software: you are free to change and redistribute it.
#   There is NO WARRANTY, to the extent permitted by law.
#
#   Written by Tom Tromey <tromey@redhat.com>
#          and Alexandre Duret-Lutz <adl@gnu.org>.
#
# ---
#
# Copyright (C) 2011-2012 Free Software Foundation, Inc.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2, or (at your option)
# any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

# As a special exception to the GNU General Public License, if you
# distribute this file as part of a program that contains a
# configuration script generated by Autoconf, you may include it under
# the same distribution terms that you use for the rest of that program.

# This file is maintained in Automake, please report
# bugs to <bug-automake@gnu.org> or send patches to
# <automake-patches@gnu.org>.

scriptversion=2011-12-27.17; # UTC

# Make unconditional expansion of undefined variables an error.  This
# helps a lot in preventing typo-related bugs.
set -u

me=tap-driver.sh

fatal ()
{
  echo "$me: fatal: $*" >&2
  exit 1
}

usage_error ()
{
  echo "$me: $*" >&2
  print_usage >&2
  exit 2
}

print_usage ()
{
  cat <<END
Usage:
  tap-driver.sh --test-name=NAME --log-file=PATH --trs-file=PATH
                [--expect-failure={yes|no}] [--color-tests={yes|no}]
                [--enable-hard-errors={yes|no}] [--ignore-exit]
                [--diagnostic-string=STRING] [--merge|--no-merge]
                [--comments|--no-comments] [--] TEST-COMMAND
The \`--test-name', \`--log-file' and \`--trs-file' options are mandatory.
END
}

# TODO: better error handling in option parsing (in particular, ensure
# TODO: $log_file, $trs_file and $test_name are defined).
test_name= # Used for reporting.
log_file=  # Where to save the result and output of the test script.
trs_file=  # Where to save the metadata of the test run.
expect_failure=0
color_tests=0
merge=0
ignore_exit=0
comments=0
diag_string='#'
while test $# -gt 0; do
  case $1 in
  --help) print_usage; exit $?;;
  --version) echo "$me $scriptversion"; exit $?;;
  --test-name) test_name=$2; shift;;
  --log-file) log_file=$2; shift;;
  --trs-file) trs_file=$2; shift;;
  --color-tests) color_tests=$2; shift;;
  --expect-failure) expect_failure=$2; shift;;
  --enable-hard-errors) shift;; # No-op.
  --merge) merge=1;;
  --no-merge) merge=0;;
  --ignore-exit) ignore_exit=1;;
  --comments) comments=1;;
  --no-comments) comments=0;;
  --diagnostic-string) diag_string=$2; shift;;
  --) shift; break;;
  -*) usage_error "invalid option: '$1'";;
  esac
  shift
done

test $# -gt 0 || usage_error "missing test command"

case $expect_failure in
  yes) expect_failure=1;;
    *) expect_failure=0;;
esac

if test $color_tests = yes; then
  init_colors='
    color_map["red"]="[0;31m" # Red.
    color_map["grn"]="[0;32m" # Green.
    color_map["lgn"]="[1;32m" # Light green.
    color_map["blu"]="[1;34m" # Blue.
    color_map["mgn"]="[0;35m" # Magenta.
    color_map["std"]="[m"     # No color.
    color_for_result["ERROR"] = "mgn"
    color_for_result["PASS"]  = "grn"
    color_for_result["XPASS"] = "red"
    color_for_result["FAIL"]  = "red"
    color_for_result["XFAIL"] = "lgn"
    color_for_result["SKIP"]  = "blu"'
else
  init_colors=''
fi

# :; is there to work around a bug in bash 3.2 (and earlier) which
# does not always set '$?' properly on redirection failure.
# See the Autoconf manual for more details.
:;{
  (
    # Ignore common signals (in this subshell only!), to avoid potential
    # problems with Korn shells.  Some Korn shells are known to propagate
    # to themselves signals that have killed a child process they were
    # waiting for; this is done at least for SIGINT (and usually only for
    # it, in truth).  Without the `trap' below, such a behaviour could
    # cause a premature exit in the current subshell, e.g., in case the
    # test command it runs gets terminated by a SIGINT.  Thus, the awk
    # script we are piping into would never seen the exit status it
    # expects on its last input line (which is displayed below by the
    # last `echo $?' statement), and would thus die reporting an internal
    # error.
    # For more information, see the Autoconf manual and the threads:
    # <http://lists.gnu.org/archive/html/bug-autoconf/2011-09/msg00004.html>
    # <http://mail.opensolaris.org/pipermail/ksh93-integration-discuss/2009-February/004121.html>
    trap : 1 3 2 13 15
    if test $merge -gt 0; then
      exec 2>&1
    else
      exec 2>&3
    fi
    "$@"
    echo $?
  ) | LC_ALL=C ${AM_TAP_AWK-awk} \
        -v me="$me" \
        -v test_script_name="$test_name" \
        -v log_file="$log_file" \
        -v trs_file="$trs_file" \
        -v expect_failure="$expect_failure" \
        -v merge="$merge" \
        -v ignore_exit="$ignore_exit" \
        -v comments="$comments" \
        -v diag_string="$diag_string" \
'
# FIXME: the usages of "cat >&3" below could be optimized when using
# FIXME: GNU awk, and/on on systems that supports /dev/fd/.

# Implementation note: in what follows, `result_obj` will be an
# associative array that (partly) simulates a TAP result object
# from the `TAP::Parser` perl module.

## ----------- ##
##  FUNCTIONS  ##
## ----------- ##

function fatal(msg)
{
  print me ": " msg | "cat >&2"
  exit 1
}

function abort(where)
{
  fatal("internal error " where)
}

# Convert a boolean to a "yes"/"no" string.
function yn(bool)
{
  return bool ? "yes" : "no";
}

function add_test_result(result)
{
  if (!test_results_index)
    test_results_index = 0
  test_results_list[test_results_index] = result
  test_results_index += 1
  test_results_seen[result] = 1;
}

# Whether the test script should be re-run by "make recheck".
function must_recheck()
{
  for (k in test_results_seen)
    if (k != "XFAIL" && k != "PASS" && k != "SKIP")
      return 1
  return 0
}

# Whether the content of the log file associated to this test should
# be copied into the "global" test-suite.log.
function copy_in_global_log()
{
  for (k in test_results_seen)
    if (k != "PASS")
      return 1
  return 0
}

# FIXME: this can certainly be improved ...
function get_global_test_result()
{
    if ("ERROR" in test_results_seen)
      return "ERROR"
    if ("FAIL" in test_results_seen || "XPASS" in test_results_seen)
      return "FAIL"
    all_skipped = 1
    for (k in test_results_seen)
      if (k != "SKIP")
        all_skipped = 0
    if (all_skipped)
      return "SKIP"
    return "PASS";
}

function stringify_result_obj(result_obj)
{
  if (result_obj["is_unplanned"] || result_obj["number"] != testno)
    return "ERROR"

  if (plan_seen == LATE_PLAN)
    return "ERROR"

  if (result_obj["directive"] == "TODO")
    return result_obj["is_ok"] ? "XPASS" : "XFAIL"

  if (result_obj["directive"] == "SKIP")
    return result_obj["is_ok"] ? "SKIP" : COOKED_FAIL;

  if (length(result_obj["directive"]))
      abort("in function stringify_result_obj()")

  return result_obj["is_ok"] ? COOKED_PASS : COOKED_FAIL
}

function decorate_result(result)
{
  color_name = color_for_result[result]
  if (color_name)
    return color_map[color_name] "" result "" color_map["std"]
  # If we are not using colorized output, or if we do not know how
  # to colorize the given result, we should return it unchanged.
  return result
}

function report(result, details)
{
  if (result ~ /^(X?(PASS|FAIL)|SKIP|ERROR)/)
    {
      msg = ": " test_script_name
      add_test_result(result)
    }
  else if (result == "#")
    {
      msg = " " test_script_name ":"
    }
  else
    {
      abort("in function report()")
    }
  if (length(details))
    msg = msg " " details
  # Output on console might be colorized.
  print decorate_result(result) msg
  # Log the result in the log file too, to help debugging (this is
  # especially true when said result is a TAP error or "Bail out!").
  print result msg | "cat >&3";
}

function testsuite_error(error_message)
{
  report("ERROR", "- " error_message)
}

function handle_tap_result()
{
  details = result_obj["number"];
  if (length(result_obj["description"]))
    details = details " " result_obj["description"]

  if (plan_seen == LATE_PLAN)
    {
      details = details " # AFTER LATE PLAN";
    }
  else if (result_obj["is_unplanned"])
    {
       details = details " # UNPLANNED";
    }
  else if (result_obj["number"] != testno)
    {
       details = sprintf("%s # OUT-OF-ORDER (expecting %d)",
                         details, testno);
    }
  else if (result_obj["directive"])
    {
      details = details " # " result_obj["directive"];
      if (length(result_obj["explanation"]))
        details = details " " result_obj["explanation"]
    }

  report(stringify_result_obj(result_obj), details)
}

# `skip_reason` should be empty whenever planned > 0.
function handle_tap_plan(planned, skip_reason)
{
  planned += 0 # Avoid getting confused if, say, `planned` is "00"
  if (length(skip_reason) && planned > 0)
    abort("in function handle_tap_plan()")
  if (plan_seen)
    {
      # Error, only one plan per stream is acceptable.
      testsuite_error("multiple test plans")
      return;
    }
  planned_tests = planned
  # The TAP plan can come before or after *all* the TAP results; we speak
  # respectively of an "early" or a "late" plan.  If we see the plan line
  # after at least one TAP result has been seen, assume we have a late
  # plan; in this case, any further test result seen after the plan will
  # be flagged as an error.
  plan_seen = (testno >= 1 ? LATE_PLAN : EARLY_PLAN)
  # If testno > 0, we have an error ("too many tests run") that will be
  # automatically dealt with later, so do not worry about it here.  If
  # $plan_seen is true, we have an error due to a repeated plan, and that
  # has already been dealt with above.  Otherwise, we have a valid "plan
  # with SKIP" specification, and should report it as a particular kind
  # of SKIP result.
  if (planned == 0 && testno == 0)
    {
      if (length(skip_reason))
        skip_reason = "- "  skip_reason;
      report("SKIP", skip_reason);
    }
}

function extract_tap_comment(line)
{
  if (index(line, diag_string) == 1)
    {
      # Strip leading `diag_string` from `line`.
      line = substr(line, length(diag_string) + 1)
      # And strip any leading and trailing whitespace left.
      sub("^[ \t]*", "", line)
      sub("[ \t]*$", "", line)
      # Return what is left (if any).
      return line;
    }
  return "";
}

# When this function is called, we know that line is a TAP result line,
# so that it matches the (perl) RE "^(not )?ok\b".
function setup_result_obj(line)
{
  # Get the result, and remove it from the line.
  result_obj["is_ok"] = (substr(line, 1, 2) == "ok" ? 1 : 0)
  sub("^(not )?ok[ \t]*", "", line)

  # If the result has an explicit number, get it and strip it; otherwise,
  # automatically assing the next progresive number to it.
  if (line ~ /^[0-9]+$/ || line ~ /^[0-9]+[^a-zA-Z0-9_]/)
    {
      match(line, "^[0-9]+")
      # The final `+ 0` is to normalize numbers with leading zeros.
      result_obj["number"] = substr(line, 1, RLENGTH) + 0
      line = substr(line, RLENGTH + 1)
    }
  else
    {
      result_obj["number"] = testno
    }

  if (plan_seen == LATE_PLAN)
    # No further test results are acceptable after a "late" TAP plan
    # has been seen.
    result_obj["is_unplanned"] = 1
  else if (plan_seen && testno > planned_tests)
    result_obj["is_unplanned"] = 1
  else
    result_obj["is_unplanned"] = 0

  # Strip trailing and leading whitespace.
  sub("^[ \t]*", "", line)
  sub("[ \t]*$", "", line)

  # This will have to be corrected if we have a "TODO"/"SKIP" directive.
  result_obj["description"] = line
  result_obj["directive"] = ""
  result_obj["explanation"] = ""

  if (index(line, "#") == 0)
    return # No possible directive, nothing more to do.

  # Directives are case-insensitive.
  rx = "[ \t]*#[ \t]*([tT][oO][dD][oO]|[sS][kK][iI][pP])[ \t]*"

  # See whether we have the directive, and if yes, where.
  pos = match(line, rx "$")
  if (!pos)
    pos = match(line, rx "[^a-zA-Z0-9_]")

  # If there was no TAP directive, we have nothing more to do.
  if (!pos)
    return

  # Let`s now see if the TAP directive has been escaped.  For example:
  #  escaped:     ok \# SKIP
  #  not escaped: ok \\# SKIP
  #  escaped:     ok \\\\\# SKIP
  #  not escaped: ok \ # SKIP
  if (substr(line, pos, 1) == "#")
    {
      bslash_count = 0
      for (i = pos; i > 1 && substr(line, i - 1, 1) == "\\"; i--)
        bslash_count += 1
      if (bslash_count % 2)
        return # Directive was escaped.
    }

  # Strip the directive and its explanation (if any) from the test
  # description.
  result_obj["description"] = substr(line, 1, pos - 1)
  # Now remove the test description from the line, that has been dealt
  # with already.
  line = substr(line, pos)
  # Strip the directive, and save its value (normalized to upper case).
  sub("^[ \t]*#[ \t]*", "", line)
  result_obj["directive"] = toupper(substr(line, 1, 4))
  line = substr(line, 5)
  # Now get the explanation for the directive (if any), with leading
  # and trailing whitespace removed.
  sub("^[ \t]*", "", line)
  sub("[ \t]*$", "", line)
  result_obj["explanation"] = line
}

function get_test_exit_message(status)
{
  if (status == 0)
    return ""
  if (status !~ /^[1-9][0-9]*$/)
    abort("getting exit status")
  if (status < 127)
    exit_details = ""
  else if (status == 127)
    exit_details = " (command not found?)"
  else if (status >= 128 && status <= 255)
    exit_details = sprintf(" (terminated by signal %d?)", status - 128)
  else if (status > 256 && status <= 384)
    # We used to report an "abnormal termination" here, but some Korn
    # shells, when a child process die due to signal number n, can leave
    # in $? an exit status of 256+n instead of the more standard 128+n.
    # Apparently, both behaviours are allowed by POSIX (2008), so be
    # prepared to handle them both.  See also Austing Group report ID
    # 0000051 <http://www.austingroupbugs.net/view.php?id=51>
    exit_details = sprintf(" (terminated by signal %d?)", status - 256)
  else
    # Never seen in practice.
    exit_details = " (abnormal termination)"
  return sprintf("exited with status %d%s", status, exit_details)
}

function write_test_results()
{
  print ":global-test-result: " get_global_test_result() > trs_file
  print ":recheck: "  yn(must_recheck()) > trs_file
  print ":copy-in-global-log: " yn(copy_in_global_log()) > trs_file
  for (i = 0; i < test_results_index; i += 1)
    print ":test-result: " test_results_list[i] > trs_file
  close(trs_file);
}

BEGIN {

## ------- ##
##  SETUP  ##
## ------- ##

'"$init_colors"'

# Properly initialized once the TAP plan is seen.
planned_tests = 0

COOKED_PASS = expect_failure ? "XPASS": "PASS";
COOKED_FAIL = expect_failure ? "XFAIL": "FAIL";

# Enumeration-like constants to remember which kind of plan (if any)
# has been seen.  It is important that NO_PLAN evaluates "false" as
# a boolean.
NO_PLAN = 0
EARLY_PLAN = 1
LATE_PLAN = 2

testno = 0     # Number of test results seen so far.
bailed_out = 0 # Whether a "Bail out!" directive has been seen.

# Whether the TAP plan has been seen or not, and if yes, which kind
# it is ("early" is seen before any test result, "late" otherwise).
plan_seen = NO_PLAN

## --------- ##
##  PARSING  ##
## --------- ##

is_first_read = 1

while (1)
  {
    # Involutions required so that we are able to read the exit status
    # from the last input line.
    st = getline
    if (st < 0) # I/O error.
      fatal("I/O error while reading from input stream")
    else if (st == 0) # End-of-input
      {
        if (is_first_read)
          abort("in input loop: only one input line")
        break
      }
    if (is_first_read)
      {
        is_first_read = 0
        nextline = $0
        continue
      }
    else
      {
        curline = nextline
        nextline = $0
        $0 = curline
      }
    # Copy any input line verbatim into the log file.
    print | "cat >&3"
    # Parsing of TAP input should stop after a "Bail out!" directive.
    if (bailed_out)
      continue

    # TAP test result.
    if ($0 ~ /^(not )?ok$/ || $0 ~ /^(not )?ok[^a-zA-Z0-9_]/)
      {
        testno += 1
        setup_result_obj($0)
        handle_tap_result()
      }
    # TAP plan (normal or "SKIP" without explanation).
    else if ($0 ~ /^1\.\.[0-9]+[ \t]*$/)
      {
        # The next two lines will put the number of planned tests in $0.
        sub("^1\\.\\.", "")
        sub("[^0-9]*$", "")
        handle_tap_plan($0, "")
        continue
      }
    # TAP "SKIP" plan, with an explanation.
    else if ($0 ~ /^1\.\.0+[ \t]*#/)
      {
        # The next lines will put the skip explanation in $0, stripping
        # any leading and trailing whitespace.  This is a little more
        # tricky in truth, since we want to also strip a potential leading
        # "SKIP" string from the message.
        sub("^[^#]*#[ \t]*(SKIP[: \t][ \t]*)?", "")
        sub("[ \t]*$", "");
        handle_tap_plan(0, $0)
      }
    # "Bail out!" magic.
    # Older versions of prove and TAP::Harness (e.g., 3.17) did not
    # recognize a "Bail out!" directive when preceded by leading
    # whitespace, but more modern versions (e.g., 3.23) do.  So we
    # emulate the latter, "more modern" behaviour.
    else if ($0 ~ /^[ \t]*Bail out!/)
      {
        bailed_out = 1
        # Get the bailout message (if any), with leading and trailing
        # whitespace stripped.  The message remains stored in `$0`.
        sub("^[ \t]*Bail out![ \t]*", "");
        sub("[ \t]*$", "");
        # Format the error message for the
        bailout_message = "Bail out!"
        if (length($0))
          bailout_message = bailout_message " " $0
        testsuite_error(bailout_message)
      }
    # Maybe we have too look for dianogtic comments too.
    else if (comments != 0)
      {
        comment = extract_tap_comment($0);
        if (length(comment))
          report("#", comment);
      }
  }

## -------- ##
##  FINISH  ##
## -------- ##

# A "Bail out!" directive should cause us to ignore any following TAP
# error, as well as a non-zero exit status from the TAP producer.
if (!bailed_out)
  {
    if (!plan_seen)
      {
        testsuite_error("missing test plan")
      }
    else if (planned_tests != testno)
      {
        bad_amount = testno > planned_tests ? "many" : "few"
        testsuite_error(sprintf("too %s tests run (expected %d, got %d)",
                                bad_amount, planned_tests, testno))
      }
    if (!ignore_exit)
      {
        # Fetch exit status from the last line.
        exit_message = get_test_exit_message(nextline)
        if (exit_message)
          testsuite_error(exit_message)
      }
  }

write_test_results()

exit 0

} # End of "BEGIN" block.
'

# TODO: document that we consume the file descriptor 3 :-(
} 3>"$log_file"

test $? -eq 0 || fatal "I/O or internal error"

# Local Variables:
# mode: shell-script
# sh-indentation: 2
# eval: (add-hook 'write-file-hooks 'time-stamp)
# time-stamp-start: "scriptversion="
# time-stamp-format: "%:y-%02m-%02d.%02H"
# time-stamp-time-zone: "UTC"
# time-stamp-end: "; # UTC"
# End:
