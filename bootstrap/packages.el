;;; packages.el --- Prepare or validate dependencies in an isolated Emacs -*- lexical-binding: t; -*-
(require 'package)
(require 'cl-lib)
(require 'subr-x)
(setq native-comp-jit-compilation nil
      package-quickstart nil
      package-directory-list nil
      package-user-dir (file-name-as-directory (getenv "HAN_PKGDIR"))
      user-emacs-directory (file-name-as-directory (expand-file-name ".emacs.d" (getenv "HOME")))
      package-archives nil)
(defvar han-pkg-reference
  (with-temp-buffer
    (insert-file-contents (expand-file-name "reference-packages.tsv" (getenv "HAN_PKGDEPS")))
    (let (items)
      (dolist (row (split-string (buffer-string) "\n" t))
        (unless (string-prefix-p "#" row)
          (push (intern (car (split-string row "\t"))) items)))
      (nreverse items))))
(defvar han-pkg-required (append han-pkg-reference '(which-key flymake eglot seq))
  "Includes libraries required by the config that are only built in on some versions.")
(defun han-pkg-offline-autoloads ()
  ;; Generate with the target Emacs; no source or bytecode from the origin machine is executed
  ;; outside the user's explicitly selected third-party package set.
  (dolist (directory (directory-files package-user-dir t directory-files-no-dot-files-regexp t))
    (when (file-directory-p directory)
      (let* ((desc-file (car (directory-files directory t "-pkg\\.el\\'")))
             (pkg-name (file-name-sans-extension (file-name-nondirectory desc-file)))
             (inhibit-message t))
        (package-generate-autoloads (string-remove-suffix "-pkg" pkg-name) directory)))))
(defun han-pkg-check ()
  (package-initialize)
  ;; Fail early for missing packages instead of silently launching a partially installed config.
  (let ((missing (cl-remove-if #'package-installed-p han-pkg-required)))
    (when missing (error "Missing packages from reference configuration: %S" missing)))
  (unless (and (package-installed-p 'compat '(30 1 0 0))
               (package-installed-p 'transient '(0 7 8)))
    (error "gptel requires compat >=30.1.0.0 and transient >=0.7.8 (bundled or builtin)"))
  (dolist (fn '(url-retrieve url-retrieve-synchronously package-refresh-contents
                make-network-process open-network-stream))
    (advice-add fn :override (lambda (&rest _) (error "Network disabled during verification"))))
  (let ((gptel (cadr (assq 'gptel package-alist))))
    (unless (and gptel (equal (package-version-join (package-desc-version gptel)) "0.9.9.6"))
      (error "Expected gptel 0.9.9.6 (OAuth / rewrite compatibility)")))
  (dolist (lib '(slime slime-repl gptel gptel-openai-oauth gptel-rewrite))
    (require lib))
  (unless (and (fboundp 'slime) (fboundp 'gptel-rewrite)
               (fboundp 'gptel-make-openai-oauth))
    (error "Expected SLIME/gptel interfaces were not loaded"))
  (message "Verified %d reference packages (including built-ins where applicable), SLIME and pinned gptel OAuth/rewrite."
           (length han-pkg-reference)))
(pcase (getenv "HAN_PKGACTION")
  ("offline" (han-pkg-offline-autoloads))
  ("check" nil)
  (_ (error "Unknown internal package action")))
(han-pkg-check)
