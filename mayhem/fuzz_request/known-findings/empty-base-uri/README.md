# Yaf_Request_Http::__construct("", "") reads base_uri[-1] (yaf_request.c:508)

`new Yaf_Request_Http("", "")` evaluates `ZSTR_VAL(base_uri)[ZSTR_LEN(base_uri) - 1]` with a zero-length base uri: a read one byte before the string data (inside the zend_string header).
Reported by UBSan's pointer-overflow check, which build.sh relaxes (together with `alignment`, for the uint32_t casts in yaf_slip_equal, php_yaf.h) because both fire on an empty input and would make every target crash at once.
Fix: guard with `ZSTR_LEN(base_uri) &&` before indexing.
