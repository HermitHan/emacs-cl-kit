;;; init-slime.el --- Slime support for Common Lisp -*- lexical-binding: t -*-
;;; Commentary:
;; SLIME 连接 Emacs 与外部 Common Lisp 实现（默认 SBCL 见 init-common-lisp.el）。
;; 它提供源码求值、编译、文档、补全、调试器及 REPL；gptel 不替代这些功能。
;; 常用：M-x slime 启动，源码 C-c C-z 去 REPL，C-c C-r 求值选区。
;; 注意 C-c r 是 AI 改写；第二个键是否带 Ctrl 决定了完全不同的动作。

;;; Code:

;; 确保 SLIME 可用，并让 contrib 扩展目录参与库查找；此处不启动 Lisp 进程。
(require-package 'slime)
(push (expand-file-name "contrib" (file-name-directory (locate-library "slime"))) load-path)


;;; Lisp buffers

(with-eval-after-load 'slime
  ;; 沿用当前版本协商策略 ignore：不因版本字符串不符立即拒绝连接。
  ;; 这并不证明任意 SLIME/Swank 版本兼容；升级后仍应实测连接和编译/求值。
  (setq slime-protocol-version 'ignore)
  ;; Emacs 与 Lisp 进程之间使用 UTF-8；slime-fancy 已包含 REPL 和 fuzzy 补全。
  ;; 不重复列出相同 contrib，避免分散维护默认环境。
  (setq slime-net-coding-system 'utf-8-unix)
  ;; slime-fancy already loads slime-repl and slime-fuzzy.
  (slime-setup '(slime-fancy)))


;;; REPL

;; REPL 同样使用公共 Lisp 编辑功能；复用 hook 不等于把 REPL 当作源码文件。
;; 个人键位在 init.el 维护：RET 用于换行，M-RET 才提交输入求值。
;; Paredit 的结构化换行仍只编辑输入，不要把普通 RET 当成执行命令。
(defun sanityinc/slime-repl-setup ()
  "Mode setup function for slime REPL."
  (sanityinc/lisp-setup))

;; REPL 的 DEL 交给 Paredit 维护括号，TAB 统一走缩进/补全命令。
;; with-eval-after-load 等 SLIME REPL 真正加载后才设置键表，不强制提前创建 REPL。
(with-eval-after-load 'slime-repl
  ;; Stop SLIME's REPL from grabbing DEL, which is annoying when backspacing over a '('
  (with-eval-after-load 'paredit
    (define-key slime-repl-mode-map (read-kbd-macro paredit-backward-delete-key) nil))

  ;; Bind TAB to `indent-for-tab-command', as in regular Slime buffers.
  (define-key slime-repl-mode-map (kbd "TAB") 'indent-for-tab-command)

  (add-hook 'slime-repl-mode-hook 'sanityinc/slime-repl-setup))


(provide 'init-slime)
;;; init-slime.el ends here
