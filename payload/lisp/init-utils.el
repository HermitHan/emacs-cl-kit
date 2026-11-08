;;; init-utils.el --- Elisp helper functions and commands -*- lexical-binding: t -*-
;;; Commentary:
;; 供各模块复用的小型 Emacs Lisp 工具，以及少量手动文件操作命令。
;; 已去除无人调用的 after-load 别名；延迟配置统一直接使用 with-eval-after-load。

;;; Code:


;; Handier way to add modes to auto-mode-alist
;; 把文件名正则映射到主模式；传入多个 PATTERNS 时逐条登记到 auto-mode-alist。
(defun add-auto-mode (mode &rest patterns)
  "Add entries to `auto-mode-alist' to use `MODE' for all given file `PATTERNS'."
  (dolist (pattern patterns)
    (add-to-list 'auto-mode-alist (cons pattern mode))))

;; Like diminish, but for major modes
;; 只修改当前 buffer 模式行里的名称，不改变实际 major-mode 或它的行为。
(defun sanityinc/set-major-mode-name (name)
  "Override the major mode NAME in this buffer."
  (setq-local mode-name name))

;; 给指定模式的 hook 登记名称简写；主模式启用时才应用。
(defun sanityinc/major-mode-lighter (mode name)
  (add-hook (derived-mode-hook-name mode)
            (apply-partially 'sanityinc/set-major-mode-name name)))


;; String utilities missing from core emacs

;; 收集字符串中每个正则匹配的全文/指定分组，供 git-svn 帮助解析等调用。
;; 使用 push 累积，因此返回顺序与扫描顺序相反；本轮保留调用者依赖的原行为。
(defun sanityinc/string-all-matches (regex str &optional group)
  "Find all matches for `REGEX' within `STR', returning the full match string or group `GROUP'."
  (let ((result nil)
        (pos 0)
        (group (or group 0)))
    (while (string-match regex str pos)
      (push (match-string group str) result)
      (setq pos (match-end group)))
    result))



;; Delete the current file

;; M-x delete-this-file 确认后删除当前磁盘文件并关闭 buffer；这是实际文件操作。
(defun delete-this-file ()
  "Delete the current file, and kill the buffer."
  (interactive)
  (unless (buffer-file-name)
    (error "No file is currently being edited"))
  (when (yes-or-no-p (format "Really delete '%s'?"
                             (file-name-nondirectory buffer-file-name)))
    (delete-file (buffer-file-name))
    (kill-this-buffer)))



;; Rename the current file

;; M-x rename-this-file-and-buffer 同时改磁盘路径及 buffer 关联。
;; 目标文件已存在时，rename-file 的整数参数会要求确认是否覆盖。
(defun rename-this-file-and-buffer (new-name)
  "Renames both current buffer and file it's visiting to NEW-NAME."
  (interactive "sNew name: ")
  (let ((name (buffer-name))
        (filename (buffer-file-name)))
    (unless filename
      (error "Buffer '%s' is not visiting a file!" name))
    (progn
      (when (file-exists-p filename)
        (rename-file filename new-name 1))
      (set-visited-file-name new-name)
      (rename-buffer new-name))))


;; Browse current HTML file

;; M-x browse-current-file 在浏览器打开当前本地文件；TRAMP 远程路径明确拒绝。
(defun browse-current-file ()
  "Open the current file as a URL using `browse-url'."
  (interactive)
  (let ((file-name (buffer-file-name)))
    (if (and (fboundp 'tramp-tramp-file-p)
             (tramp-tramp-file-p file-name))
        (error "Cannot open tramp file")
      (browse-url (concat "file://" file-name)))))


(provide 'init-utils)
;;; init-utils.el ends here
