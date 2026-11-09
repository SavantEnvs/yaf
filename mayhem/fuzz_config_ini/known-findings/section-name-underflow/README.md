# Yaf_Config_Ini section header made only of spaces/colons underflows a length (configs/yaf_config_ini.c:310)

Found by fuzz_config_ini (the most frequent crash there: a header such as `[: :]`). The driver does not filter it out, so it is re-found each run.

Reproduce under the ASan build (`yaf-fuzz.so`, `USE_ZEND_ALLOC=0`), with `c.ini` from this directory:

    php -d extension=yaf-fuzz.so -r 'new Yaf_Config_Ini("c.ini");'

Cause: `yaf_config_ini_strip_section_name(&p, &l, 3)` strips leading then trailing ' ' / ':' with `while (p[l - 1] == ' ' || p[l - 1] == ':') l--`. When the name is only those characters the head strip already left `l == 0`, the tail loop reads `p[-1]` and wraps `l` to SIZE_MAX, then `zend_memrchr(p, ':', l)` is called with a negative size (ASan negative-size-param).
Impact: out-of-bounds read of heap data before the section name.
Fix: stop the tail loop when `l == 0` (`while (l && (p[l - 1] == ' ' || p[l - 1] == ':'))`), and bound the head loop by `l` as well.
