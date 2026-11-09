#!/usr/bin/env bash
#
# mayhem/build.sh - build the sanitized yaf extension plus one fuzz binary per surface, and
# the unsanitized extension + php binary that mayhem/test.sh runs the upstream phpt suite with.
#
# yaf is a PHP extension, so every harness embeds PHP (Debian libphp8.4-embed + php8.4-dev, installed in
# the Dockerfile). The extension is built out of tree in mayhem/build/ (gitignored) from a copy of the
# tracked sources, so the checkout stays free of phpize/configure output.
set -euo pipefail

[ -n "${SOURCE_DATE_EPOCH:-}" ] || unset SOURCE_DATE_EPOCH

: "${SANITIZER_FLAGS=-fsanitize=address,undefined -fno-sanitize-recover=all -fno-omit-frame-pointer}"
: "${DEBUG_FLAGS:=-g -gdwarf-3}"
: "${CC:=clang}" ; : "${CXX:=clang++}" ; : "${LIB_FUZZING_ENGINE:=-fsanitize=fuzzer}"
: "${MAYHEM_JOBS:=$(nproc)}"
: "${COVERAGE_FLAGS=}"
export SANITIZER_FLAGS DEBUG_FLAGS CC CXX LIB_FUZZING_ENGINE MAYHEM_JOBS COVERAGE_FLAGS

cd "$SRC"
BUILD="$SRC/mayhem/build"
mkdir -p "$BUILD"

# Copy of the tracked tree minus mayhem/, so phpize/configure/make never write into the checkout.
copy_tree() {
  rm -rf "$1"; mkdir -p "$1"
  git ls-files -z | grep -zv '^mayhem/' | tar --null -T - -cf - | tar -xf - -C "$1"
}

# build_ext <dir> <CFLAGS> <LDFLAGS>
build_ext() {
  copy_tree "$1"
  ( cd "$1"
    phpize >/dev/null
    ./configure --enable-yaf --with-php-config="$(command -v php-config)" \
        CC="$CC" CFLAGS="$2" LDFLAGS="$3" >/dev/null
    make -j"$MAYHEM_JOBS" >/dev/null )
}

# 1) Sanitized + SanCov-instrumented extension. The project objects carry $SANITIZER_FLAGS and DWARF 3;
#    explicit SanCov flags (not fuzzer-no-link, whose stack-depth TLS symbol a dlopen()ed .so cannot resolve).
# alignment: yaf_slip_equal() (php_yaf.h) casts char* to uint32_t* on every route match; pointer-overflow:
# Yaf_Request base_uri[len-1] on an empty string (yaf_request.c). Both fire on benign/empty input and would
# make every target crash at once; everything else in UBSan and all of ASan stay halting.
build_ext "$BUILD/fuzz" "-O1 $SANITIZER_FLAGS -fno-sanitize=alignment,pointer-overflow $DEBUG_FLAGS -fsanitize-coverage=inline-8bit-counters,indirect-calls,trace-cmp,pc-table" "$SANITIZER_FLAGS"
cp "$BUILD/fuzz/modules/yaf.so" "$SRC/yaf-fuzz.so"

# 2) Harnesses: one embedding driver per surface, each linked as a libFuzzer binary and a standalone reproducer.
$CC $SANITIZER_FLAGS $DEBUG_FLAGS -c "$STANDALONE_FUZZ_MAIN" -o "$BUILD/standalone_main.o"
$CXX $SANITIZER_FLAGS $DEBUG_FLAGS -c "$SRC/mayhem/lsan_off.cc" -o "$BUILD/lsan_off.o"
PHP_INCLUDES="$(php-config --includes)"
for t in fuzz_config_ini fuzz_router fuzz_request fuzz_view fuzz_dispatch; do
  defs=(-DDRIVER="\"$SRC/mayhem/drivers/$t.php\"" -DYAF_SO="\"$SRC/yaf-fuzz.so\"")
  $CC -O1 $SANITIZER_FLAGS $DEBUG_FLAGS $LIB_FUZZING_ENGINE "${defs[@]}" $PHP_INCLUDES \
      "$SRC/mayhem/yaf_fuzz.c" "$BUILD/lsan_off.o" -rdynamic -lphp -o "$SRC/$t"
  $CC -O1 $SANITIZER_FLAGS $DEBUG_FLAGS "${defs[@]}" $PHP_INCLUDES \
      "$SRC/mayhem/yaf_fuzz.c" "$BUILD/standalone_main.o" "$BUILD/lsan_off.o" -rdynamic -lphp -o "$SRC/$t-standalone"
done

# 3) Test suite build: the unsanitized extension (project's normal flags) and a private copy of the php
#    binary. The copy lives under /mayhem so it counts as the program under test for the sabotage check,
#    while the runner (run-tests.php) executes under the system php.
build_ext "$BUILD/test" "$COVERAGE_FLAGS" "$COVERAGE_FLAGS"
cp -L "$(command -v php)" "$BUILD/test/php"
cp "$(ls /usr/lib/php/*/build/run-tests.php | head -n1)" "$BUILD/test/run-tests.php"   # it writes beside itself
