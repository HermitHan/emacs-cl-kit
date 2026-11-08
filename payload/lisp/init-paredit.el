;;; init-paredit.el --- Configure paredit structured editing -*- lexical-binding: t -*-
;;; Commentary:
;; Paredit 是 Lisp 结构编辑工具：成对插入/删除括号，按表达式移动和重组代码。
;; 开启范围由 init-lisp.el 的公共 hook 决定；这里负责按键冲突和 minibuffer 支持。
;; 可用 C-h m 查看当前模式说明，C-h k 查询当前实际快捷键，而非猜测网上的默认键表。

;;; Code:

(require-package 'paredit)

;; 普通 Paredit buffer 中 RET 换行并缩进；避免抢占 IELM/CIDER 和 minibuffer
;; 各自的提交行为。CL REPL 的个人提交键仍为 M-RET（见 init.el）。
(defun sanityinc/maybe-map-paredit-newline ()
  (unless (or (memq major-mode '(inferior-emacs-lisp-mode cider-repl-mode))
              (minibufferp))
    (local-set-key (kbd "RET") 'paredit-newline)))

(add-hook 'paredit-mode-hook 'sanityinc/maybe-map-paredit-newline)

;; 模式栏简写为 Par；仅让出指定的冲突按键，其余结构编辑快捷键继续保留。
;; 移除局部绑定后，Emacs 会继续查找其他有效键表，而不是禁用该按键。
(with-eval-after-load 'paredit
  (diminish 'paredit-mode " Par")
  ;; Suppress certain paredit keybindings to avoid clashes, including
  ;; my global binding of M-?
  (dolist (binding '("C-<left>" "C-<right>" "C-M-<left>" "C-M-<right>" "M-s" "M-?"))
    (define-key paredit-mode-map (read-kbd-macro binding) nil)))



;; Use paredit in the minibuffer
;; TODO: break out into separate package
;; http://emacsredux.com/blog/2013/04/18/evaluate-emacs-lisp-in-the-minibuffer/
;; 仅在求值 Emacs Lisp 等指定命令的 minibuffer 中启用 Paredit，
;; 普通查找文件/搜索/输入文字不会因此被强制变成 Lisp 结构编辑。
(add-hook 'minibuffer-setup-hook 'sanityinc/conditionally-enable-paredit-mode)

(defvar paredit-minibuffer-commands '(eval-expression
                                      pp-eval-expression
                                      eval-expression-with-eldoc
                                      ibuffer-do-eval
                                      ibuffer-do-view-and-eval)
  "Interactive commands for which paredit should be enabled in the minibuffer.")

(defun sanityinc/conditionally-enable-paredit-mode ()
  "Enable paredit during lisp-related minibuffer commands."
  (if (memq this-command paredit-minibuffer-commands)
      (enable-paredit-mode)))


(provide 'init-paredit)
;;; init-paredit.el ends here
