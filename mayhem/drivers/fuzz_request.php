<?php
$sel = ord($fz[0] ?? "\0");
$p = explode("\n", substr($fz, 1), 6);
$uri = $p[0] ?? ''; $base = $p[1] ?? ''; $lang = $p[2] ?? '';
$self = $p[3] ?? ''; $script = $p[4] ?? ''; $extra = $p[5] ?? '';
$methods = ['GET', 'POST', 'PUT', 'HEAD', 'OPTIONS', 'DELETE', 'PATCH', 'CLI'];
$_SERVER['REQUEST_METHOD'] = $methods[$sel & 7];
$_SERVER['REQUEST_URI'] = $uri;
$_SERVER['HTTP_ACCEPT_LANGUAGE'] = $lang;
$_SERVER['PHP_SELF'] = $self;
$_SERVER['SCRIPT_NAME'] = $script;
$_SERVER['SCRIPT_FILENAME'] = $script;
$_SERVER['ORIG_SCRIPT_NAME'] = $extra;
try {
    if ($sel & 8) {
        $r = new Yaf_Request_Http();
    } else {
        $r = new Yaf_Request_Http($uri, ($sel & 16) ? $base : null);
    }
    $r->getLanguage();
    $r->getBaseUri();
    $r->getRequestUri();
    $r->getMethod();
    $r->getModuleName();
    $r->getControllerName();
    $r->getActionName();
    if ($sel & 32) { $r->setBaseUri($base); }
    if ($sel & 64) { $r->setRequestUri($uri); }
    $r->getBaseUri();
    $r->getRequestUri();
    $r->setParam($lang, $extra);
    $r->getParam($lang);
    $r->getParams();
    $r->setModuleName($self);
    $r->setControllerName($script);
    $r->setActionName($extra);
    $r->getServer($lang);
    $r->getQuery($lang);
    $r->isXmlHttpRequest();
    $r->getLanguage();
    $s = new Yaf_Request_Simple($methods[$sel & 7], $self, $script, $extra, [$lang => $uri]);
    $s->getParams();
    $s->getModuleName();
    $s->getControllerName();
    $s->getActionName();
    $s->getMethod();
} catch (Throwable $e) {
}
