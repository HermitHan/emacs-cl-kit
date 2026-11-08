;;; test-sandbox.el --- Preconditions for offline installation tests -*- lexical-binding: t -*-
(require 'cl-lib)
(require 'subr-x)

(defun portable-test-prepare ()
  "Accept only batch Emacs with an installed configuration below a temporary HOME."
  (let* ((home (file-name-as-directory (file-truename (expand-file-name "~"))))
         (target (file-name-as-directory
                  (file-truename (or (getenv "HAN_TEST_TARGET")
                                     (expand-file-name ".emacs.d" home))))))
    (unless (and noninteractive
                 (or (file-in-directory-p home "/tmp/")
                     (file-in-directory-p home temporary-file-directory))
                 (file-in-directory-p target home)
                 (file-regular-p (expand-file-name "init.el" target)))
      (error "Use -Q --batch and a freshly installed target inside a private temporary HOME"))
    (when (file-exists-p (expand-file-name ".cache/gptel-openai/openai-oauth-token" target))
      (error "Refusing a test target containing gptel credentials"))
    (setq default-directory home
          user-emacs-directory target
          user-init-file (expand-file-name "init.el" target)
          temporary-file-directory (expand-file-name "tmp/" home)
          package-directory-list nil
          native-comp-jit-compilation nil
          create-lockfiles nil)
    (make-directory temporary-file-directory t)
    (setenv "TMPDIR" temporary-file-directory)
    (setenv "XDG_CACHE_HOME" (expand-file-name ".cache" home))
    (setenv "XDG_CONFIG_HOME" (expand-file-name ".config" home))
    (setenv "XDG_DATA_HOME" (expand-file-name ".local/share" home))
    ;; Child Lisp compilers should use the fixture's HOME as well.
    (setenv "ASDF_OUTPUT_TRANSLATIONS" nil)))

(defun portable-test-elpa ()
  (expand-file-name (format "elpa-%d.%d" emacs-major-version emacs-minor-version)
                    user-emacs-directory))

(defun portable-test-installed (feature)
  "Require FEATURE and confirm its library came from the test installation."
  (require feature)
  (let ((file (locate-library (symbol-name feature))))
    (unless (and file (file-in-directory-p (file-truename file) (portable-test-elpa)))
      (error "%s is missing from this installation (resolved: %s)" feature file))))

(provide 'portable-test-sandbox)
