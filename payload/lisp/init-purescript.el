;;; init-purescript.el --- Support the Purescript language -*- lexical-binding: t -*-
;;; Commentary:
;; PureScript 编辑、导入整理、IDE/REPL 及 JavaScript 外部实现联动。
;; 这些语言专用规则继续保留；实际 IDE、检查和 REPL 需要 purs/psc-ide 等项目工具。
;;; Code:

;; 进入 PureScript 模式时启用缩进，并只在本 buffer 保存前排序 import。
(when (maybe-require-package 'purescript-mode)
  (add-hook 'purescript-mode-hook 'turn-on-purescript-indentation)

  (add-hook 'purescript-mode-hook
            (lambda ()
              (add-hook 'before-save-hook 'purescript-sort-imports nil t)))

  ;; 保留源码字符原样显示，不用 prettify-symbols 把字符组合显示为特殊符号。
  (add-hook 'purescript-mode-hook (apply-partially 'prettify-symbols-mode -1))

  ;; C-o 保留普通 open-line；此处不改变其他模式的 C-o。
  (with-eval-after-load 'purescript-mode
    (define-key purescript-mode-map (kbd "C-o") 'open-line))

  ;; 生成 purty 的手动和保存时格式化命令，需要外部 purty；没有在这里自动开启保存格式化。
  (when (maybe-require-package 'reformatter)
    (reformatter-define purty
      :program "purty" :lighter " purty"))

  ;; psc-ide-mode 提供项目查询；将本 buffer 的 Flycheck 自动检查时机限制为保存和启用模式。
  (when (maybe-require-package 'psc-ide)
    (add-hook 'purescript-mode-hook 'psc-ide-mode)
    (add-hook 'psc-ide-mode-hook
              (lambda ()
                (setq-local flycheck-check-syntax-automatically '(save mode-enabled))))

    ;; JavaScript 外部实现保存后，仅在同名 .purs 文件已经打开且启用 psc-ide 时联动。
    ;; 优先遵循 rebuild-on-save；否则在 Flycheck 已启用时触发其检查。
    (defun psc-ide-foreign-js-after-save-handler ()
      "Call `psc-ide-rebuild' in any neighbouring purescript file buffer, if `psc-ide-rebuild-on-save' is set.
This is a little magical because it only works if the
corresponding .purs file is open."
      (let ((js-path (buffer-file-name)))
        (when js-path
          (let* ((purs-path (concat (file-name-sans-extension js-path) ".purs"))
                 (purs-buf (get-file-buffer purs-path)))
            (when purs-buf
              (with-current-buffer purs-buf
                (when psc-ide-mode
                  (cond
                   (psc-ide-rebuild-on-save
                    (message "Triggering rebuild of %s" purs-path)
                    (psc-ide-rebuild))
                   (flycheck-mode
                    (message "Flychecking %s" purs-path)
                    (flycheck-buffer))))))))))

    ;; M-x psc-ide-foreign-js-mode 为当前 JS buffer 开关此保存联动；这里没有全局自动开启。
    (define-minor-mode psc-ide-foreign-js-mode
      "Rebuild corresponding purescript file."
      :init-value nil
      :lighter " PursJS"
      :global nil
      (if psc-ide-foreign-js-mode
          (add-hook 'after-save-hook 'psc-ide-foreign-js-after-save-handler nil t)
        (remove-hook 'after-save-hook 'psc-ide-foreign-js-after-save-handler t))))

  ;; 为 PureScript 源码安装 PSCi 交互功能；实际 REPL 会话仍由命令启动。
  (when (maybe-require-package 'psci)
    (add-hook 'purescript-mode-hook 'inferior-psci-mode))

  ;; 让项目 node_modules/.bin 里的工具优先可见；启动 PSCi 时临时选取找到的 purs 路径。
  (when (maybe-require-package 'add-node-modules-path)
    (with-eval-after-load 'purescript-mode
      (add-hook 'purescript-mode-hook 'add-node-modules-path))
    (with-eval-after-load 'psci
      (advice-add 'psci :around (lambda (oldfun &rest args)
                                  (let ((psci/purs-path (or (executable-find "purs")
                                                            psci/purs-path)))
                                    (apply oldfun args)))))))

(provide 'init-purescript)
;;; init-purescript.el ends here
