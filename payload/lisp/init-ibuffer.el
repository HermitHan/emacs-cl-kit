;;; init-ibuffer.el --- ibuffer settings -*- lexical-binding: t -*-
;;; Commentary:

;; TODO: enhance ibuffer-fontification-alist
;;   See http://www.reddit.com/r/emacs/comments/21fjpn/fontifying_buffer_list_for_emacs_243/

;; C-x C-b 打开增强 buffer 列表，可按版本库分组并批量管理 buffer。

;;; Code:

;; 进入列表时临时占满当前 frame，退出后恢复原窗口布局。
(require-package 'fullframe)
(with-eval-after-load 'ibuffer
 (fullframe ibuffer ibuffer-quit))

;; 按 VC 仓库根目录分组；每次进入列表时设置分组，并按文件名/进程名排序。
(require-package 'ibuffer-vc)

(defun ibuffer-set-up-preferred-filters ()
  (ibuffer-vc-set-filter-groups-by-vc-root)
  (unless (eq ibuffer-sorting-mode 'filename/process)
    (ibuffer-do-sort-by-filename/process)))

(add-hook 'ibuffer-hook 'ibuffer-set-up-preferred-filters)

;; 隐藏空分组，减少没有内容的标题。
(setq-default ibuffer-show-empty-filter-groups nil)


;; 定义可读的大小列；下面两种格式都显示文件相对路径与版本状态。
;; 在 Ibuffer 内按反引号切换格式，属于显示设置，不改变文件内容。
(with-eval-after-load 'ibuffer
  ;; Use human readable Size column instead of original one
  (define-ibuffer-column size-h
    (:name "Size" :inline t)
    (file-size-human-readable (buffer-size))))


;; Modify the default ibuffer-formats (toggle with `)
(setq ibuffer-formats
      '((mark modified read-only vc-status-mini " "
              (name 22 22 :left :elide)
              " "
              (size-h 9 -1 :right)
              " "
              (mode 12 12 :left :elide)
              " "
              vc-relative-file)
        (mark modified read-only vc-status-mini " "
              (name 22 22 :left :elide)
              " "
              (size-h 9 -1 :right)
              " "
              (mode 14 14 :left :elide)
              " "
              (vc-status 12 12 :left)
              " "
              vc-relative-file)))

;; 分组标题使用文档字符串的颜色；最后登记全局列表入口。
(setq ibuffer-filter-group-name-face 'font-lock-doc-face)

(global-set-key (kbd "C-x C-b") 'ibuffer)

(provide 'init-ibuffer)
;;; init-ibuffer.el ends here
