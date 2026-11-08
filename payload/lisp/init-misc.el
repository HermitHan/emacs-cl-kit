;;; init-misc.el --- Miscellaneous config -*- lexical-binding: t -*-
;;; Commentary:
;; 暂未独立成文件的小功能；保留现有确认方式、脚本保存动作和正则工具。

;;; Code:


;; Misc config - yet to be placed in separate files

;; MacPorts 的 Portfile 用 Tcl 模式；确认问题沿用单字母 y/n 的现有习惯。
(add-auto-mode 'tcl-mode "\\(?:\\`\\|/\\)Portfile\\'")
(fset 'yes-or-no-p 'y-or-n-p)

;; 代码注释等位置的网址和邮箱可点击，邮箱链接使用统一 link 外观。
(add-hook 'prog-mode-hook 'goto-address-prog-mode)
(setq goto-address-mail-face 'link)

;; 保存带 #! 的脚本时，内置函数可添加执行权限。
;; 新建文件若仍在 fundamental-mode，则尝试按解释器声明重新识别模式。
(add-hook 'after-save-hook 'executable-make-buffer-file-executable-if-script-p)
(add-hook 'after-save-hook 'sanityinc/set-mode-for-new-scripts)

(defun sanityinc/set-mode-for-new-scripts ()
  "Invoke `normal-mode' if this file is a script and in `fundamental-mode'."
  (and
   (eq major-mode 'fundamental-mode)
   (>= (buffer-size) 2)
   (save-restriction
     (widen)
     (string= "#!" (buffer-substring (point-min) (+ 2 (point-min)))))
   (normal-mode)))


;; 浏览内置 Info 手册时增加语法颜色；不改变手册文件。
(when (maybe-require-package 'info-colors)
  (with-eval-after-load 'info
    (add-hook 'Info-selection-hook 'info-colors-fontify-node)))


;; Handle the prompt pattern for the 1password command-line interface
;; 扩展交互式进程的密码提示识别，以兼容此处记录的 1Password CLI 提示格式。
(with-eval-after-load 'comint
  (setq comint-password-prompt-regexp
        (concat
         comint-password-prompt-regexp
         "\\|^Please enter your password for user .*?:\\s *\\'")))



;; M-x regex-tool 使用 Perl 后端；M-x re-builder 是另一套内置正则试验界面。
(when (maybe-require-package 'regex-tool)
  (setq-default regex-tool-backend 'perl))

;; re-builder 中 C-c C-k 退出，沿用常见交互编辑窗口的退出方式。
(with-eval-after-load 're-builder
  ;; Support a slightly more idiomatic quit binding in re-builder
  (define-key reb-mode-map (kbd "C-c C-k") 'reb-quit))

;; 进程声明 Procfile 使用通用配置文件模式，便于阅读。
(add-auto-mode 'conf-mode "\\(?:\\`\\|/\\)Procfile\\'")


(provide 'init-misc)
;;; init-misc.el ends here
