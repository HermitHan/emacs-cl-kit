;;; slime-smoke.el --- Real compile/eval in the newly installed SLIME -*- lexical-binding: t -*-
;; HOME=<temporary installed HOME> HAN_TEST_BACKENDS=sbcl,my-lispworks
;; emacs -Q --batch -l tests/slime-smoke.el
;; HAN_CONFIG_ONLY=1 checks backend registration without launching a child.
(load (expand-file-name "test-sandbox.el" (file-name-directory load-file-name)) nil t)
(portable-test-prepare)
(require 'lisp-mode)
(require 'package)
(setq package-user-dir (portable-test-elpa))
(package-initialize)
(add-to-list 'load-path (expand-file-name "lisp" user-emacs-directory))
(require 'init-utils)
(require 'init-common-lisp)
(portable-test-installed 'slime)
(slime-setup '(slime-fancy))
(portable-test-installed 'slime-repl)
(defvar portable-smoke--ready nil)
(setq slime-kill-without-query-p t
      slime-net-coding-system 'utf-8-unix
      slime-lisp-host "127.0.0.1")
(add-hook 'slime-connected-hook
          (lambda () (push (slime-current-connection) portable-smoke--ready)))

(defun portable-smoke--connect (key)
  ;; Launch using the package's real named-registry entry point.
  (let ((known (copy-sequence portable-smoke--ready)))
    (slime key)
    (with-timeout (135 (error "Timed out waiting for Swank: %s" key))
      (while (not (cl-set-difference portable-smoke--ready known))
        (dolist (proc (process-list))
          (when (and (eq (process-type proc) 'real)
                     (string-prefix-p "inferior-lisp" (process-name proc))
                     (not (process-live-p proc)))
            (error "Inferior Lisp exited early for %s" key)))
        (accept-process-output nil 0.1)))
    (car (cl-set-difference portable-smoke--ready known))))

(defun portable-smoke--compile (key conn)
  (let* ((slime-dispatching-connection conn)
         (form "(list (lisp-implementation-type) (funcall (compile nil '(lambda (n) (+ n 2))) 40))")
         (printed (with-timeout (25 (error "Timed out evaluating on %s" key))
                    (cadr (slime-eval `(swank:eval-and-grab-output ,form) "CL-USER"))))
         (value (car (read-from-string printed)))
         (expected (if (eq key 'sbcl) "SBCL" "LispWorks")))
    (unless (and (equal value (list expected 42)) (process-live-p conn))
      (error "Wrong implementation/result for %s: %S" key value))
    (message "PASS backend=%s implementation=%s compile/eval=%s pid=%s"
             key (car value) (cadr value) (slime-pid conn))))

(let ((start-processes (process-list))
      (keys (mapcar #'intern (split-string (or (getenv "HAN_TEST_BACKENDS") "sbcl") "," t)))
      connections)
  (unwind-protect
      (progn
        (dolist (key keys)
          (unless (assq key slime-lisp-implementations)
            (error "Backend missing: %s; registered=%S" key (mapcar #'car slime-lisp-implementations))))
        (message "Registered=%S default=%s" (mapcar #'car slime-lisp-implementations) slime-default-lisp)
        (unless (equal (getenv "HAN_CONFIG_ONLY") "1")
          (dolist (key keys) (push (cons key (portable-smoke--connect key)) connections))
          ;; Check all connections together, after opening the last one.
          (unless (= (length keys)
                     (length (delete-dups (mapcar (lambda (x) (slime-pid (cdr x))) connections))))
            (error "Expected distinct Common Lisp processes"))
          (dolist (entry (reverse connections)) (portable-smoke--compile (car entry) (cdr entry)))
          (message "PASS simultaneous connections=%d" (length keys))))
    (slime-cancel-connect-retry-timer)
    ;; This fresh batch process owns these processes. Never look up or signal external PIDs.
    (setq kill-emacs-hook nil)
    (dolist (p (cl-set-difference (process-list) start-processes))
      (when (process-live-p p)
        (set-process-query-on-exit-flag p nil)
        (set-process-sentinel p #'ignore)
        (delete-process p)))))
