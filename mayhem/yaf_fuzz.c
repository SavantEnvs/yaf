/*
 * Embeds PHP (the Debian libphp embed SAPI) with the sanitized, SanCov-instrumented yaf extension
 * loaded from yaf-fuzz.so, and runs one PHP driver script (drivers/<target>.php, built in via
 * .incbin) per fuzz input. The driver gets the input bytes in $fz and the scratch directory in
 * $fz_dir. Every input runs in a fresh PHP request, so no state carries over between inputs.
 */
#define _GNU_SOURCE
#include <ftw.h>
#include <limits.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>

#include "php.h"
#include "php_main.h"
#include "zend_exceptions.h"
#include "sapi/embed/php_embed.h"

#ifndef DRIVER
#error "compile with -DDRIVER=\"/path/to/driver.php\""
#endif
#ifndef YAF_SO
#error "compile with -DYAF_SO=\"/path/to/yaf-fuzz.so\""
#endif

__asm__(".section .rodata\n"
        ".global fz_driver\n"
        "fz_driver:\n"
        ".incbin \"" DRIVER "\"\n"
        ".byte 0\n"
        ".previous\n");
extern const char fz_driver[];

static char scratch[PATH_MAX];
static char ini_entries[PATH_MAX + 512];

static void write_file(const char *rel, const char *content) {
    char path[PATH_MAX];
    snprintf(path, sizeof(path), "%s/%s", scratch, rel);
    FILE *f = fopen(path, "w");
    if (!f) {
        perror(path);
        abort();
    }
    fputs(content, f);
    fclose(f);
}

static void make_dir(const char *rel) {
    char path[PATH_MAX];
    snprintf(path, sizeof(path), "%s/%s", scratch, rel);
    if (mkdir(path, 0755) != 0) {
        perror(path);
        abort();
    }
}

static int rm_entry(const char *path, const struct stat *sb, int flag, struct FTW *ftw) {
    (void)sb; (void)flag; (void)ftw;
    return remove(path);
}

static void cleanup(void) {
    nftw(scratch, rm_entry, 16, FTW_DEPTH | FTW_PHYS);
}

/* A minimal Yaf application tree the dispatch/view drivers point at. Read-only after setup. */
static void stage_app(void) {
    const char *tmp = getenv("TMPDIR");
    if (!tmp || !*tmp) tmp = "/tmp";
    snprintf(scratch, sizeof(scratch), "%s/yaf-fuzz-XXXXXX", tmp);
    if (!mkdtemp(scratch)) {
        perror("mkdtemp");
        abort();
    }
    atexit(cleanup);
    make_dir("app");
    make_dir("app/controllers");
    make_dir("app/actions");
    make_dir("app/views");
    make_dir("app/views/index");
    make_dir("app/library");
    make_dir("app/models");
    write_file("app/controllers/Index.php",
        "<?php\n"
        "class IndexController extends Yaf_Controller_Abstract {\n"
        "  public $actions = array('ext' => 'actions/Ext.php');\n"
        "  public function indexAction() { $this->getView()->assign('v', 'index'); }\n"
        "  public function helloAction() { $this->getView()->assign('v', $this->getRequest()->getParam('name', 'x')); }\n"
        "  public function jsonAction() { Yaf_Dispatcher::getInstance()->disableView(); echo json_encode($this->getRequest()->getParams()); return false; }\n"
        "  public function fwdAction() { $this->forward('index', 'hello', array('name' => 'f')); return false; }\n"
        "  public function throwAction() { throw new Exception('boom'); }\n"
        "  protected function protectedAction() { return false; }\n"
        "  private function privateAction() { return false; }\n"
        "}\n");
    write_file("app/controllers/Error.php",
        "<?php\n"
        "class ErrorController extends Yaf_Controller_Abstract {\n"
        "  public function errorAction($exception) { echo get_class($exception); return false; }\n"
        "}\n");
    write_file("app/controllers/Init.php",
        "<?php\n"
        "class InitController extends Yaf_Controller_Abstract {\n"
        "  public function init() { $this->forward('index', 'index'); }\n"
        "  public function indexAction() { return false; }\n"
        "}\n");
    write_file("app/actions/Ext.php",
        "<?php\n"
        "class ExtAction extends Yaf_Action_Abstract {\n"
        "  public function execute() { echo 'ext'; return false; }\n"
        "}\n");
    write_file("app/views/index/index.phtml", "<?php echo $v; ?>\n");
    write_file("app/views/index/hello.phtml", "hello <?php echo $v; ?>\n");
    write_file("app/library/Lib.php", "<?php\nclass Lib {}\n");
    write_file("app/models/Model.php", "<?php\nclass ModelModel {}\n");
}

static size_t discard_output(const char *str, size_t len) {
    (void)str;
    return len;
}

int LLVMFuzzerInitialize(int *argc, char ***argv) {
    (void)argc; (void)argv;
    /* Make PHP allocate with malloc so ASan sees heap overflows in the extension. */
    setenv("USE_ZEND_ALLOC", "0", 1);
    stage_app();
    snprintf(ini_entries, sizeof(ini_entries),
             "extension=" YAF_SO "\n"
             "display_errors=0\n"
             "log_errors=0\n"
             "html_errors=0\n"
             "error_reporting=0\n"
             "memory_limit=-1\n"
             "max_execution_time=0\n"
             "disable_functions=system,exec,passthru,shell_exec,proc_open,popen,pcntl_exec,mail\n"
             "open_basedir=%s\n",
             scratch);
    /* php_embed_init() overwrites sapi ini_entries, so the settings travel in a php.ini of our own. */
    char ini_path[PATH_MAX + 16];
    snprintf(ini_path, sizeof(ini_path), "%s/php.ini", scratch);
    FILE *ini = fopen(ini_path, "w");
    if (!ini || fputs(ini_entries, ini) == EOF || fclose(ini) != 0) {
        fprintf(stderr, "cannot write %s\n", ini_path);
        abort();
    }
    php_embed_module.php_ini_path_override = ini_path;
    php_embed_module.ub_write = discard_output;
    if (php_embed_init(0, NULL) == FAILURE) {
        fprintf(stderr, "php_embed_init failed\n");
        abort();
    }
    if (!zend_hash_str_exists(&module_registry, "yaf", 3)) {
        fprintf(stderr, "yaf extension did not load: %s\n", YAF_SO);
        abort();
    }
    return 0;
}

int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size) {
    /* Fresh request per input: yaf's per-request state and PHP userland state are rebuilt. */
    php_request_shutdown(NULL);
    if (php_request_startup() == FAILURE) {
        fprintf(stderr, "php_request_startup failed\n");
        abort();
    }
    SG(headers_sent) = 1;
    SG(request_info).no_headers = 1;

    zend_first_try {
        zval fz, dir;
        ZVAL_STRINGL(&fz, (const char *)data, size);
        zend_hash_str_update(&EG(symbol_table), "fz", sizeof("fz") - 1, &fz);
        ZVAL_STRING(&dir, scratch);
        zend_hash_str_update(&EG(symbol_table), "fz_dir", sizeof("fz_dir") - 1, &dir);
        /* skip the leading "<?php\n" of the driver file */
        zend_eval_string(fz_driver + 6, NULL, "yaf_fuzz_driver");
        if (EG(exception)) {
            zend_clear_exception();
        }
    } zend_end_try();
    return 0;
}
