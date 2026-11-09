<?php
$sel = ord($fz[0] ?? "\0");
$p = explode("\n", substr($fz, 1), 5);
$uri = $p[0] ?? ''; $a = $p[1] ?? ''; $b = $p[2] ?? ''; $c = $p[3] ?? ''; $q = $p[4] ?? '';
$delim = explode("\0", $a)[0];
$types = ['rewrite', 'regex', 'simple', 'supervar', 'map', 'static', $a];
try {
    parse_str($q, $get);
    $_GET = $get;
    // The three bugs under fuzz_router/known-findings are avoided by what the driver passes: no NUL in the base URI
    // or the Route_Map delimiter, no empty key in the assemble() info array.
    $base = ($sel & 128) ? $b : null;
    if ($base !== null && strpos($base, "\0") !== false) { $base = null; }
    $req = new Yaf_Request_Http($uri, $base);
    $router = new Yaf_Router();
    switch ($sel & 7) {
    case 0:
        $route = new Yaf_Route_Rewrite($a, ['controller' => $b, 'action' => $c], ['id' => $c]);
        break;
    case 1:
        $route = new Yaf_Route_Regex($a, ['controller' => $b, 'action' => $c], [1 => $b, 2 => $c, 3 => $q], ['x' => $c], $b);
        break;
    case 2:
        $route = new Yaf_Route_Simple($a, $b, $c);
        break;
    case 3:
        $route = new Yaf_Route_Supervar($a);
        break;
    case 4:
        $route = new Yaf_Route_Map((bool)($sel & 8), $delim);
        break;
    default:
        $route = new Yaf_Route_Static();
        break;
    }
    $router->addRoute('fz', $route);
    $router->route($req);
    $router->getCurrentRoute();
    $req->getModuleName();
    $req->getControllerName();
    $req->getActionName();
    $req->getParams();
    $info = [':m' => $a, ':c' => $b, ':a' => $c, 'm' => $a, 'c' => $b, 'a' => $c, $q => $uri];
    unset($info['']);
    if ($sel & 16) { $route->assemble($info, [$a => $b]); }
    if ($sel & 32) { $route->assemble($info, null); }
    if (method_exists($route, 'match')) { $route->match($uri); }
    if ($sel & 64) {
        $cfg = ['r' => ['type' => $types[($sel >> 3) % 7], 'match' => $a, 'route' => ['controller' => $b, 'action' => $c],
                'map' => [1 => $b], 'verify' => ['x' => $c], 'varname' => $a, 'module' => $a,
                'controller' => $b, 'action' => $c, 'controller_prefer' => $c, 'delimiter' => $delim]];
        $r2 = new Yaf_Router();
        $r2->addConfig($cfg);
        $r2->route(new Yaf_Request_Http($uri));
        $r2->getRoutes();
    }
} catch (Throwable $e) {
}
