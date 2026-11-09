<?php
$sel = ord($fz[0] ?? "\0");
$ini = substr($fz, 1);
$file = $fz_dir . '/c.ini';
file_put_contents($file, $ini);
try {
    $section = null;
    $parsed = @parse_ini_string($ini, true, INI_SCANNER_RAW);
    if (is_array($parsed) && $parsed && ($sel & 1)) {
        foreach ($parsed as $name => $body) {
            if (!is_array($body)) { continue; }
            $section = (string)$name;
            if (!($sel & 2)) { break; }
        }
    }
    $c = new Yaf_Config_Ini($file, $section);
    $arr = $c->toArray();
    $c->readonly();
    count($c);
    foreach ($c as $k => $v) {
        if (is_object($v)) { $v->toArray(); }
    }
    $c->get();
    foreach ($arr as $k => $unused) {
        $c->get((string)$k);
        isset($c->$k);
        $c->$k;
    }
    $s = new Yaf_Config_Simple($arr, ($sel & 4) != 0);
    $s->toArray();
    foreach ($s as $k => $v) { }
    if ($sel & 8) { @$s->set('x', $ini); }
} catch (Throwable $e) {
}
@unlink($file);
