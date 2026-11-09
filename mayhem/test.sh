#!/usr/bin/env bash
#
# mayhem/test.sh - run yaf's own phpt suite (tests/*.phpt) against the unsanitized extension that
# build.sh produced, plus a few direct known-answer probes.
#
# The phpt runner (run-tests.php) executes under the system php; the tests themselves run under the
# private copy of the php binary in mayhem/build/test, so a neutered program fails them. The probes
# below call that same binary directly and compare exact output.
set -uo pipefail
[ -n "${SOURCE_DATE_EPOCH:-}" ] || unset SOURCE_DATE_EPOCH
: "${MAYHEM_JOBS:=$(nproc)}"
cd "$SRC"

emit_ctrf() {
  local tool="$1" passed="$2" failed="$3" skipped="${4:-0}" pending="${5:-0}" other="${6:-0}"
  local tests=$(( passed + failed + skipped + pending + other ))
  cat > "${CTRF_REPORT:-$SRC/ctrf-report.json}" <<JSON
{
  "results": {
    "tool": { "name": "$tool" },
    "summary": {
      "tests": $tests,
      "passed": $passed,
      "failed": $failed,
      "pending": $pending,
      "skipped": $skipped,
      "other": $other
    }
  }
}
JSON
  printf 'CTRF {"results":{"tool":{"name":"%s"},"summary":{"tests":%d,"passed":%d,"failed":%d,"pending":%d,"skipped":%d,"other":%d}}}\n' \
    "$tool" "$tests" "$passed" "$failed" "$pending" "$skipped" "$other"
  [ "$failed" -eq 0 ]
}

T="$SRC/mayhem/build/test"
EXT="$T/modules/yaf.so"
PHP="$T/php"
RUNNER="$T/run-tests.php"
for f in "$EXT" "$PHP" "$RUNNER"; do
  [ -e "$f" ] || { echo "missing $f (build.sh should have produced it)" >&2; emit_ctrf cli-kat 0 1 0; exit 1; }
done

passed=0 failed=0 skipped=0

# --- direct known-answer probes through the private php binary ---------------------------------
probe() { # <name> <expected> <php code>
  local out
  out="$("$PHP" -n -d "extension=$EXT" -r "$3" 2>&1)"
  if [ "$out" = "$2" ]; then passed=$((passed+1)); else
    failed=$((failed+1)); echo "PROBE FAIL $1: expected [$2] got [$out]" >&2; fi
}
probe config_simple '42' 'echo (new Yaf_Config_Simple(["a" => ["b" => 42]]))->a->b;'
probe route_rewrite 'user|view|7' '
  $r = new Yaf_Router(); $r->addRoute("u", new Yaf_Route_Rewrite("/user/:id", ["controller" => "user", "action" => "view"]));
  $q = new Yaf_Request_Http("/user/7"); $r->route($q);
  echo $q->getControllerName() === "User" ? "user" : $q->getControllerName(), "|", $q->getActionName(), "|", $q->getParam("id");'
probe route_static 'Foo|bar|k' '
  $r = new Yaf_Router(); $q = new Yaf_Request_Http("/foo/bar/baz/k"); $r->route($q);
  echo $q->getControllerName(), "|", $q->getActionName(), "|", $q->getParam("baz");'
probe request_uri '/a/b' 'echo (new Yaf_Request_Http("/a/b?x=1", "/"))->getRequestUri() === "/a/b?x=1" ? "/a/b" : "bad";'
probe app_directory '/tmp' 'echo (new Yaf_Application(["application" => ["directory" => "/tmp"]]))->getAppDirectory();'

# --- upstream phpt suite -------------------------------------------------------------------------
log="$(mktemp)"
TEST_PHP_EXECUTABLE="$PHP" TEST_PHP_ARGS="-n -d extension=$EXT" NO_INTERACTION=1 REPORT_EXIT_STATUS=0 \
  php "$RUNNER" -n -q -j"$MAYHEM_JOBS" --no-color tests/*.phpt > "$log" 2>&1
sed -n '/^Number of tests/,/^=====/p' "$log"
num() { sed -n "s/^$1 *: *\([0-9][0-9]*\).*/\1/p" "$log" | head -n1; }
p="$(num 'Tests passed')"; f="$(num 'Tests failed')"; s="$(num 'Tests skipped')"
p=${p:-0}; f=${f:-0}; s=${s:-0}
if [ "$((p+f+s))" -eq 0 ]; then echo "phpt runner reported no tests" >&2; tail -n 30 "$log" >&2; failed=$((failed+1)); fi
grep -E '^FAIL ' "$log" | head -n 20
passed=$((passed+p)); failed=$((failed+f)); skipped=$((skipped+s))
rm -f "$log"

emit_ctrf phpt "$passed" "$failed" "$skipped"
