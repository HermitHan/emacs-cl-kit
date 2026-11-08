;;; init-rails.el --- Ruby on Rails support -*- lexical-binding: t -*-
;;; Commentary:
;; Rails 项目辅助：Projectile 模式开关时，令 projectile-rails-global-mode 跟随同一状态。
;; 保留现有项目识别集成；本段不创建 Rails 项目，也不启动应用服务器。
;;; Code:

(when (maybe-require-package 'projectile-rails)
  (add-hook 'projectile-mode-hook
            (lambda () (projectile-rails-global-mode projectile-mode))))


(provide 'init-rails)
;;; init-rails.el ends here
