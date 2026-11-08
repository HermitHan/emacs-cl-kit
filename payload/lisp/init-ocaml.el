;;; init-ocaml.el --- Support the OCaml language -*- lexical-binding: t -*-
;;; Commentary:
;; OCaml/Tuareg 编辑、REPL 往返、Eglot 服务登记和 Dune/缩进工具。
;; 外部 OCaml、ocamllsp、Dune、ocp-indent 需按项目安装，此文件不启动它们。
;;; Code:

;; Eglot 加载后登记 Tuareg 对应的语言标识与 ocamllsp；是否连接由现有 Eglot 工作流决定。
(with-eval-after-load 'eglot
  (put 'tuareg-mode 'eglot-language-id "ocaml")
  (add-to-list 'eglot-server-programs '((tuareg-mode) . ("ocamllsp")) t))

;; 源码中 C-c C-z 启动/显示 OCaml REPL，并把来源 buffer 记录在该 REPL 的局部变量里。
;; REPL 中同样按 C-c C-z 返回记录的源码 buffer；沿用现有键位。
(when (maybe-require-package 'tuareg)
  (with-eval-after-load 'tuareg
    (defvar-local tuareg-previous-tuareg-buffer nil
      "Buffer from which we jumped to the REPL.")

    (defun sanityinc/tuareg-repl-switch ()
      (interactive)
      (let ((last-tuareg-buf (when (derived-mode-p 'tuareg-mode)
                               (current-buffer))))
        (tuareg-run-ocaml)
        (pop-to-buffer tuareg-interactive-buffer-name)
        (when last-tuareg-buf
          (setq-local tuareg-previous-tuareg-buffer last-tuareg-buf))))

    (defun sanityinc/tuareg-repl-switch-back ()
      (interactive)
      (when tuareg-previous-tuareg-buffer
        (pop-to-buffer tuareg-previous-tuareg-buffer)))

    (define-key tuareg-mode-map (kbd "C-c C-z") 'sanityinc/tuareg-repl-switch)
    (define-key tuareg-interactive-mode-map (kbd "C-c C-z") 'sanityinc/tuareg-repl-switch-back)))

;; 保留 Dune 构建文件模式和格式化命令包，不会自动运行构建。
(when (maybe-require-package 'dune)
  (maybe-require-package 'dune-format))

;; reformatter 生成 ocp-indent-buffer / ocp-indent-region / ocp-indent-on-save-mode。
;; 可用 M-x 手动格式化或自行启用保存模式；ocp-indent-args 存放额外命令行参数。
;; Add my own lightweight ocp-indent reformatter, instead of the clunky upstream package
(when (maybe-require-package 'reformatter)
  (defcustom ocp-indent-args nil
    "Arguments for \"ocp-indent\" invocation.")

  (reformatter-define ocp-indent
    :program "ocp-indent"
    :args ocp-indent-args
    :lighter " OCP"))


(provide 'init-ocaml)
;;; init-ocaml.el ends here
