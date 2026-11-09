# Yaf_Config_Ini section that inherits from a scalar key dereferences a non-array (configs/yaf_config_ini.c:51)

Found by fuzz_config_ini. The driver does not filter it out.

Reproduce under the ASan build (`yaf-fuzz.so`), with `c.ini` from this directory:

    php -d extension=yaf-fuzz.so -r 'new Yaf_Config_Ini("c.ini");'

`c.ini` has a top-level `a=1` and a section `[b:a]` that extends it.
Cause: in `yaf_config_ini_parser_cb` the parent found by `zend_symtable_str_find()` is passed to `yaf_deep_copy_section()` without checking `Z_TYPE_P(parent) == IS_ARRAY` (the `empty_section` branch has that check, the inheritance loop does not), and `yaf_deep_copy_section()` takes `Z_ARRVAL_P()` of a string/long: SEGV at yaf_config_ini.c:51.
Impact: crash (NULL-ish pointer dereference) on a config file whose section extends a scalar key.
Fix: add the `Z_TYPE_P(parent) == IS_ARRAY` check in the inheritance loop.
