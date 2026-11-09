# Yaf_Config_Ini with a section name that is a scalar leaves a garbage config; count()/foreach crash

Reproduce with the unsanitized extension:

    php -d extension=yaf.so -r '$c = new Yaf_Config_Ini("c.ini", "\xb7\xb7"); var_dump(count($c)); foreach ($c as $k => $v) {}'

`c.ini` contains one top-level key (no `[section]`), and the second constructor argument names that key.
yaf accepts it, stores a non-array value as the config table, then `count()` returns a garbage number and iteration segfaults
(zend_user_it_rewind -> zend_hash_internal_pointer_reset_ex on a non-HashTable). fuzz_config_ini only selects section names whose RAW-parsed value is an array,
which makes this rare but not impossible: yaf parses in normal mode and can resolve the selected name to a scalar, so the driver does not fully avoid it and it is still found occasionally.
Fix: in the Yaf_Config_Ini constructor, throw (or fall back to the whole file) when the selected section is not an array.
