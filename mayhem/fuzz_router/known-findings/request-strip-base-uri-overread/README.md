# yaf_request_strip_base_uri heap-buffer-overflow read (yaf_request.c:402)

Found by fuzz_router. Reached from every route's `route()` (Regex, Rewrite, Map, Static) when the request has a base URI.
fuzz_router no longer passes a base URI that contains a NUL, so it keeps exploring instead of re-finding this bug.

Reproduce under the ASan build (`yaf-fuzz.so`, `USE_ZEND_ALLOC=0`; the strings are built at run time so they are not interned):

    php -d extension=yaf-fuzz.so -r '$req = new Yaf_Request_Http(implode("", ["/", "a"]), "/a" . str_repeat("\0", 200)); (new Yaf_Router())->route($req);'

Cause: `strncasecmp(uri, base_uri, ZSTR_LEN(base_uri))` stops at an embedded NUL, so a base_uri containing a NUL byte "matches" a shorter uri; `p += ZSTR_LEN(base_uri)` then points past the end of uri and `*p` is read. The returned length `ZSTR_LEN(uri) - (p - uri)` wraps, so the callers (static route `memchr`, `yaf_router_parse_parameters`) over-read too.
Impact: out-of-bounds read of heap data from a request-supplied string.
Fix: require `ZSTR_LEN(uri) >= ZSTR_LEN(base_uri)` before comparing (and compare with a length-aware function).
