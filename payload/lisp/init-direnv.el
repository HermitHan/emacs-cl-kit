;;; init-direnv.el --- Integrate with direnv -*- lexical-binding: t -*-
;;; Commentary:
;; 按 buffer 所在目录接入 direnv 环境变量。
;; 启用需要系统中已有 direnv；项目 .envrc 的授权仍由 direnv 自己管理。

;;; Code:

;; 先确保 envrc 包可用，启动后再检查外部程序并启用全局模式。
;; C-c e 是 envrc 的命令前缀，可查看该前缀菜单执行相关操作。
(when (maybe-require-package 'envrc)
  (defun sanityinc/maybe-enable-envrc-global-mode ()
    "Enable `envrc-global-mode' if `direnv' is installed."
    (when (executable-find "direnv")
      (envrc-global-mode)))

  (with-eval-after-load 'envrc
    (define-key envrc-mode-map (kbd "C-c e") 'envrc-command-map))
  (add-hook 'after-init-hook 'sanityinc/maybe-enable-envrc-global-mode))

(provide 'init-direnv)

;;; init-direnv.el ends here
