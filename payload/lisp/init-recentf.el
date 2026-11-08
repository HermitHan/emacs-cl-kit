;;; init-recentf.el --- Settings for tracking recent files -*- lexical-binding: t -*-
;;; Commentary:
;; 启动后记录最近打开的文件，最多保存 1000 条。
;; 排除 /tmp、这里匹配的 SSH 路径和当前包目录的自动加载文件；不会删除这些文件。
;; 可用 M-x consult-recent-file 或 M-x recentf-open-files 选择历史文件。

;;; Code:

(add-hook 'after-init-hook 'recentf-mode)
(setq-default
 recentf-max-saved-items 1000
 recentf-exclude `("/tmp/" "/ssh:" ,(concat package-user-dir "/.*-autoloads\\.el\\'")))


(provide 'init-recentf)
;;; init-recentf.el ends here
