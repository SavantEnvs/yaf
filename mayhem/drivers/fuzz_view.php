<?php
$sel = ord($fz[0] ?? "\0");
$p = explode("\n", substr($fz, 1), 4);
$name = $p[0] ?? ''; $value = $p[1] ?? ''; $name2 = $p[2] ?? ''; $tplname = $p[3] ?? '';
$templates = [
    '',
    '<?php echo $v; ?>',
    '<?= $v ?>x<?= $w ?>',
    '<?php if (',
    'plain text',
    '<?php foreach ((array)$v as $k => $i) { echo $k, $i; } ?>',
    '<?php echo $this->v; ?>',
    '<?php echo isset($v) ? strlen($v) : -1; ?>',
];
try {
    $view = new Yaf_View_Simple($fz_dir . '/app/views');
    $view->assign($name, $value);
    if ($sel & 8) { $view->assign([$name2 => $value, 'v' => $name]); }
    if ($sel & 16) { $view->$name2 = $value; }
    if ($sel & 32) { $view->get($name); }
    $view->eval($templates[$sel & 7], [$name2 => $value, 'w' => $name]);
    if ($sel & 64) { $view->render('index/' . $tplname . '.phtml', [$name2 => $value]); }
    if ($sel & 128) { $view->setScriptPath($tplname); $view->getScriptPath(); }
    $view->render('index/index.phtml', ['v' => $value]);
    $view->render('index/hello.phtml');
    $view->clear($name);
} catch (Throwable $e) {
}
