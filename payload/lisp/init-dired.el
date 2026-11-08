;;; init-dired.el --- Dired customisations -*- lexical-binding: t -*-
;;; Commentary:
;; 配置 Emacs 的目录管理器 Dired；C-x d 打开目录，RET 进入文件。

;;; Code:

;; 两个 Dired 窗口并排时，把另一窗口目录作为复制/移动的默认目标。
(setq-default dired-dwim-target t)

;; Prefer g-prefixed coreutils version of standard utilities when available
;; 如已安装 GNU coreutils 的 gls，优先用它列目录；找不到则保留原默认程序。
(let ((gls (executable-find "gls")))
  (when gls (setq insert-directory-program gls)))

;; 目录首次打开后启用颜色增强并加载 dired-x，不在此处提前打开目录。
(when (maybe-require-package 'diredfl)
  (with-eval-after-load 'dired
    (diredfl-global-mode)
    (require 'dired-x)))

;; Hook up dired-x global bindings without loading it up-front
;; C-x C-j 跳到当前文件所在目录；C-x 4 C-j 在另一窗口显示。
(define-key ctl-x-map "\C-j" 'dired-jump)
(define-key ctl-x-4-map "\C-j" 'dired-jump-other-window)

;; 删除非空目录时只在顶层确认；鼠标中键打开文件。
;; C-c C-q 进入 Wdired，可像编辑文本一样批量改文件名，再按该模式提示提交。
(with-eval-after-load 'dired
  (setq dired-recursive-deletes 'top)
  (define-key dired-mode-map [mouse-2] 'dired-find-file)
  (define-key dired-mode-map (kbd "C-c C-q") 'wdired-change-to-wdired-mode))

;; 打开目录时启用版本状态标记，便于观察 Git 等版本控制下的改动。
(when (maybe-require-package 'diff-hl)
  (with-eval-after-load 'dired
    (add-hook 'dired-mode-hook 'diff-hl-dired-mode)))

(provide 'init-dired)
;;; init-dired.el ends here
