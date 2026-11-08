;;; init-projectile.el --- Use Projectile for navigation within projects -*- lexical-binding: t -*-
;;; Commentary:
;; 用 Projectile 识别项目根目录并提供项目内文件、搜索等命令。

;;; Code:

;; 启动后启用模式，C-c p 打开项目命令组；模式行缩写为 Proj。
(when (maybe-require-package 'projectile)
  (add-hook 'after-init-hook 'projectile-mode)

  ;; Shorter modeline
  (setq-default projectile-mode-line-prefix " Proj")

  ;; 外部 rg 可用时用它枚举通用项目文件，保留隐藏文件并使用 NUL 分隔路径。
  (when (executable-find "rg")
    (setq-default projectile-generic-command "rg --files --hidden -0"))

  (with-eval-after-load 'projectile
    (define-key projectile-mode-map (kbd "C-c p") 'projectile-command-map))

  ;; 只准备按项目整理 Ibuffer 的扩展；实际 Ibuffer 默认分组在 init-ibuffer 中配置。
  (maybe-require-package 'ibuffer-projectile))


(provide 'init-projectile)
;;; init-projectile.el ends here
