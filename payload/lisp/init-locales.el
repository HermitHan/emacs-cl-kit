;;; init-locales.el --- Configure default locale -*- lexical-binding: t -*-
;;; Commentary:
;; 统一使用 UTF-8，与终端、中文文件、系统剪贴板和 CL 进程通信保持一致。

;;; Code:

;; 解析 LANG 等环境变量末尾的编码名称；缺少编码后缀时返回 nil。
(defun sanityinc/locale-var-encoding (v)
  "Return the encoding portion of the locale string V, or nil if missing."
  (when v
    (save-match-data
      (let ((case-fold-search t))
        (when (string-match "\\.\\([^.]*\\)\\'" v)
          (intern (downcase (match-string 1 v))))))))

;; 发现明确的非 UTF-8 环境编码时只给提示，不擅自改写 shell 环境变量。
(dolist (varname '("LC_ALL" "LANG" "LC_CTYPE"))
  (let ((encoding (sanityinc/locale-var-encoding (getenv varname))))
    (unless (memq encoding '(nil utf8 utf-8))
      (message "Warning: non-UTF8 encoding in environment variable %s may cause interop problems with this Emacs configuration." varname))))

;; 优先 Unicode/UTF-8；非 Windows 平台同时设置选择区/剪贴板的传输编码。
(when (fboundp 'set-charset-priority)
  (set-charset-priority 'unicode))
(prefer-coding-system 'utf-8)
(setq locale-coding-system 'utf-8)
(unless (eq system-type 'windows-nt)
  (set-selection-coding-system 'utf-8))

(provide 'init-locales)
;;; init-locales.el ends here
