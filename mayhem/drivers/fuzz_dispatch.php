<?php
$sel = ord($fz[0] ?? "\0");
$p = explode("\n", substr($fz, 1), 5);
$uri = $p[0] ?? ''; $a = $p[1] ?? ''; $b = $p[2] ?? ''; $c = $p[3] ?? ''; $q = $p[4] ?? '';
try {
    parse_str($q, $get);
    $_GET = $get;
    $conf = ['application' => ['directory' => $fz_dir . '/app', 'ext' => 'php', 'view' => ['ext' => 'phtml'],
        'dispatcher' => ['catchException' => (bool)($sel & 1)]]];
    if ($sel & 2) { $conf['application']['dispatcher']['defaultController'] = $a; }
    if ($sel & 4) { $conf['application']['dispatcher']['defaultAction'] = $b; }
    if ($sel & 8) { $conf['application']['dispatcher']['defaultModule'] = $c; }
    if ($sel & 16) { $conf['application']['modules'] = 'Index,' . $a; }
    if ($sel & 32) { $conf['application']['baseUri'] = $b; }
    if ($sel & 64) { $conf['application']['library'] = $fz_dir . '/app/library'; }
    $app = new Yaf_Application($conf);
    $d = $app->getDispatcher();
    $d->returnResponse(true);
    $d->autoRender((bool)($sel & 128));
    $d->throwException(!($sel & 1));
    if ($sel & 4) { $d->setDefaultController($a); }
    $loader = Yaf_Loader::getInstance();
    $loader->autoload($a);
    $loader->isLocalName($b);
    $loader->registerLocalNamespace($c);
    $resp = $d->dispatch(new Yaf_Request_Http($uri));
    if (is_object($resp)) { $resp->getBody(); }
} catch (Throwable $e) {
}
