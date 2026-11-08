;;; init-sessions.el --- Save and restore editor sessions between restarts -*- lexical-binding: t -*-
;;; Commentary:
;; 保存跨次启动的信息：desktop 管会话，savehist 管输入历史，session 另存位置等数据。
;; 三者有部分职责重叠，仍按既有方式分别保存；路径统一由 init-state 设置。

;;; Code:

;; 会话文件位于 ~/.emacs.d/var/.emacs.desktop；自动保存间隔设为 600 秒。
;; 此处请求启用 desktop，实际运行状态仍可能被后续设置或手动命令改变。
(setq desktop-auto-save-timeout 600)
(desktop-save-mode 1)

;; 为整个 desktop 恢复过程计时，只输出日志，不更改恢复内容。
(defun sanityinc/desktop-time-restore (orig &rest args)
  (let ((start-time (current-time)))
    (prog1
        (apply orig args)
      (message "Desktop restored in %.2fms"
               (sanityinc/time-subtract-millis (current-time)
                                               start-time)))))
(advice-add 'desktop-read :around 'sanityinc/desktop-time-restore)

;; 单独记录每个 buffer 的恢复时间，便于定位启动时慢在哪个文件。
(defun sanityinc/desktop-time-buffer-create (orig ver filename &rest args)
  (let ((start-time (current-time)))
    (prog1
        (apply orig ver filename args)
      (message "Desktop: %.2fms to restore %s"
               (sanityinc/time-subtract-millis (current-time)
                                               start-time)
               (when filename
                 (abbreviate-file-name filename))))))
(advice-add 'desktop-create-buffer :around 'sanityinc/desktop-time-buffer-create)


;; Restore histories and registers after saving

;; 默认历史长度 1000；启动完成后开启 savehist，保存 minibuffer 的输入历史。
(setq-default history-length 1000)
(add-hook 'after-init-hook 'savehist-mode)

;; session 另存到 var/.session，使用 UTF-8，并忽略临时文件及部分 Git 内部文件。
;; 它还可保存文件位置和 kill-ring 等；具体项目受 session 自身选项/Custom 控制。
(require-package 'session)

(setq session-name-disable-regexp "\\(?:\\`/tmp\\|\\.git/[A-Z_]+\\'\\)")
(setq session-save-file-coding-system 'utf-8)

(add-hook 'after-init-hook 'session-initialize)

;; save a bunch of variables to the desktop file
;; for lists specify the len of the maximal saved data also
;; 另外把以下变量写入 desktop：编译/搜索/文件/Org 等历史，以及寄存器和 TAGS 信息。
;; (变量 . 数字) 限制该列表保留的长度；单独变量名表示按 desktop 的普通规则保存。
;; ivy-history 是旧补全历史兼容项，并不表示当前启用了 Ivy。
(setq desktop-globals-to-save
      '((comint-input-ring        . 50)
        (compile-history          . 30)
        desktop-missing-file-warning
        (dired-regexp-history     . 20)
        (extended-command-history . 30)
        (face-name-history        . 20)
        (file-name-history        . 100)
        (grep-find-history        . 30)
        (grep-history             . 30)
        (ivy-history              . 100)
        (magit-revision-history   . 50)
        (minibuffer-history       . 50)
        (org-clock-history        . 50)
        (org-refile-history       . 50)
        (org-tags-history         . 50)
        (query-replace-history    . 60)
        (read-expression-history  . 60)
        (regexp-history           . 60)
        (regexp-search-ring       . 20)
        register-alist
        (search-ring              . 20)
        (shell-command-history    . 50)
        tags-file-name
        tags-table-list))


(provide 'init-sessions)
;;; init-sessions.el ends here
