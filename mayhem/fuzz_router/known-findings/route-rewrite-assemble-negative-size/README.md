# Yaf_Route_Rewrite::assemble negative-size memcpy (routes/yaf_route_rewrite.c:360)

Found by fuzz_router. fuzz_router no longer puts an empty-string key in the `assemble()` info array.

Reproduce under the ASan build (`yaf-fuzz.so`, `USE_ZEND_ALLOC=0`):

    php -d extension=yaf-fuzz.so -r '$r = new Yaf_Route_Rewrite("/a/*", ["controller" => "c"]); $r->assemble([":c" => "x", implode("", []) => "v"]);'

Cause: for a `*` wildcard pattern the code does `smart_str_appendl(&wildcard, ZSTR_VAL(key) + 1, ZSTR_LEN(key) - 1)` for every string key of the info array; an empty-string key makes `ZSTR_LEN(key) - 1` wrap to SIZE_MAX.
Impact: ASan negative-size-param in memcpy; heap corruption in a non-ASan build.
Fix: skip (or reject) empty keys.
