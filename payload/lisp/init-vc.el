;;; init-vc.el --- Version control support -*- lexical-binding: t -*-
;;; Commentary:

;; Most version control packages are configured separately: see
;; init-git.el, for example.

;; 提供跨版本控制后端的改动标记；Git 的完整界面配置在 init-git。

;;; Code:

;; 启动后启用 Diff-HL，Magit 刷新完成后同步标记。
;; 图形窗口左侧 fringe 鼠标左键可跳到对应差异块；终端显示能力取决于后端。
(when (maybe-require-package 'diff-hl)
  (add-hook 'magit-post-refresh-hook 'diff-hl-magit-post-refresh)
  (add-hook 'after-init-hook 'global-diff-hl-mode)

  (with-eval-after-load 'diff-hl
    (define-key diff-hl-mode-map
      (kbd "<left-fringe> <mouse-1>")
      'diff-hl-diff-goto-hunk)))

(provide 'init-vc)
;;; init-vc.el ends here
