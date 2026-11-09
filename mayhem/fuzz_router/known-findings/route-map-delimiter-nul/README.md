# Yaf_Route_Map::route out-of-bounds read with a NUL in the delimiter (routes/yaf_route_map.c:185, then memchr in yaf_router.c:195)

Found by fuzz_router. fuzz_router no longer passes a Route_Map delimiter that contains a NUL.

Reproduce under the ASan build (`yaf-fuzz.so`, `USE_ZEND_ALLOC=0`):

    php -d extension=yaf-fuzz.so -r '$req = new Yaf_Request_Http(implode("", ["/", "q"])); $r = new Yaf_Route_Map(false, "q" . str_repeat("\0", 400)); $router = new Yaf_Router(); $router->addRoute("fz", $r); $router->route($req);'

Cause: the delimiter is located with `strstr(uri, ZSTR_VAL(map->delim))`, which compares up to the first NUL, but the match is then skipped with `ZSTR_LEN(map->delim)`, so `rest = query + ZSTR_LEN(map->delim)` lands past the end of the uri and `while (*rest == '/')` reads it (yaf_route_map.c:185). The same bad `rest` makes `query_len = len - (rest - uri)` wrap, and `yaf_router_parse_parameters()` `memchr()`s that many bytes (yaf_route_map.c:193 -> yaf_router.c:195).
Impact: heap out-of-bounds read.
Fix: reject a delimiter that contains a NUL when the route is built, or `memmem()` with `ZSTR_LEN(map->delim)`. Also check `query > uri` before reading `*(query - 1)`.
