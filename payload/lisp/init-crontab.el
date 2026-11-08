;;; init-crontab.el --- Working with crontabs -*- lexical-binding: t -*-
;;; Commentary:
;; 提供 crontab 文件的语法编辑支持；打开匹配文件时自动选取 crontab-mode。
;; 本模块不运行任务、不写入系统 crontab；安装任务仍需你另行操作。
;;; Code:

;; 确保编辑模式可用，匹配文件名末尾的 cron/.cron/crontab/.crontab。
(require-package 'crontab-mode)
(add-auto-mode 'crontab-mode "\\.?cron\\(tab\\)?\\'")

(provide 'init-crontab)
;;; init-crontab.el ends here
