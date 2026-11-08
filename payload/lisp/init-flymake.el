;;; init-flymake.el --- Configure Flymake global behaviour -*- lexical-binding: t -*-
;;; Commentary:
;; 统一由 Flymake 展示诊断，必要时借用 Flycheck 的检查器。
;; 桥接不等于同时启用 flycheck-mode；这里保留每种语言既有后端。

;;; Code:

;; 确保 Flymake 至少满足此版本要求；系统内置版本满足时不必另装。
(maybe-require-package 'flymake "1.2.1")

;; Use flycheck checkers with flymake, to extend its coverage
;; 使用 Flycheck 检查器补足 Flymake 覆盖面。Emacs Lisp 已有原生后端，禁用对应重复检查器。
(when (maybe-require-package 'flymake-flycheck)
  ;; Disable flycheck checkers for which we have flymake equivalents
  (with-eval-after-load 'flycheck
    (setq-default flycheck-disabled-checkers
                  (delete-dups
                   (append (default-value 'flycheck-disabled-checkers)
                           '(emacs-lisp emacs-lisp-checkdoc emacs-lisp-package)))))

  ;; 只在启用 Flymake 时追加当前可用的桥接后端，并去重。
  ;; 追加而不是覆盖，保留 SLIME/Eglot/语言模式自己设置的诊断函数。
  (defun sanityinc/enable-flymake-flycheck ()
    (when flymake-mode
      (setq-local flymake-diagnostic-functions
                  (delete-dups
                   (append flymake-diagnostic-functions
                           (flymake-flycheck-all-chained-diagnostic-functions))))))

  (add-hook 'flymake-mode-hook 'sanityinc/enable-flymake-flycheck)
  ;; 在编程和文本主模式启用 Flymake；有没有诊断仍取决于可用检查器与外部工具。
  (add-hook 'prog-mode-hook 'flymake-mode)
  (add-hook 'text-mode-hook 'flymake-mode))

;; Flymake 启用时：C-c ! n / p 跳到下一/上一问题，C-c ! c 手动重新检查。
;; 可用 M-x consult-flymake 浏览当前 Flymake 诊断。
(with-eval-after-load 'flymake
  ;; Provide some flycheck-like bindings in flymake mode to ease transition
  (define-key flymake-mode-map (kbd "C-c ! n") 'flymake-goto-next-error)
  (define-key flymake-mode-map (kbd "C-c ! p") 'flymake-goto-prev-error)
  (define-key flymake-mode-map (kbd "C-c ! c") 'flymake-start))

;; 让 ElDoc 合并多个文档来源；Flymake 自己管理对应钩子，不在这里重复添加。
(unless (version< emacs-version "28.1")
  ;; Flymake manages its ElDoc hook when the mode is enabled or disabled.
  (setq eldoc-documentation-strategy 'eldoc-documentation-compose))

(provide 'init-flymake)
;;; init-flymake.el ends here
