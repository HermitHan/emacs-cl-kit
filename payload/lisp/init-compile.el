;;; init-compile.el --- Helpers for M-x compile -*- lexical-binding: t -*-
;;; Commentary:
;; 管理 M-x compile / recompile 的结果窗口、通知与颜色。
;; 这里的 compile 是运行编译命令，不是 SLIME 的 Common Lisp 编译快捷键。

;;; Code:

;; 编译输出持续追加时跟随滚动；遇到错误的跳转仍由 compilation-mode 管理。
(setq-default compilation-scroll-output t)

;; 确保通知包已安装。require-package 不等于 require：是否加载由后续调用决定。
(require-package 'alert)

;; Customize `alert-default-style' to get messages after compilation

;; 只有编译结果 buffer 在当前可检查的窗口中不可见时才发通知。
;; 通知样式可通过 M-x customize-variable 设置 alert-default-style。
(defun sanityinc/alert-after-compilation-finish (buf result)
  "Use `alert' to report compilation RESULT if BUF is hidden."
  (when (buffer-live-p buf)
    (unless (catch 'is-visible
              (walk-windows (lambda (w)
                              (when (eq (window-buffer w) buf)
                                (throw 'is-visible t))))
              nil)
      (alert (concat "Compilation " result)
             :buffer buf
             :category 'compilation))))

(with-eval-after-load 'compile
  (add-hook 'compilation-finish-functions
            'sanityinc/alert-after-compilation-finish))

;; 记住最近编译 buffer；从源代码按 F6 也能回到那次编译环境执行 recompile。
;; 带前缀要求编辑命令时，仍交给原 recompile 处理。
(defvar sanityinc/last-compilation-buffer nil
  "The last buffer in which compilation took place.")

(with-eval-after-load 'compile
  (defun sanityinc/save-compilation-buffer (&rest _)
    "Save the compilation buffer to find it later."
    (setq sanityinc/last-compilation-buffer next-error-last-buffer))
  (advice-add 'compilation-start :after 'sanityinc/save-compilation-buffer)

  (defun sanityinc/find-prev-compilation (orig &optional edit-command)
    "Find the previous compilation buffer, if present, and recompile there."
    (if (and (null edit-command)
             (not (derived-mode-p 'compilation-mode))
             sanityinc/last-compilation-buffer
             (buffer-live-p (get-buffer sanityinc/last-compilation-buffer)))
        (with-current-buffer sanityinc/last-compilation-buffer
          (funcall orig edit-command))
      (funcall orig edit-command)))
  (advice-add 'recompile :around 'sanityinc/find-prev-compilation))

(global-set-key [f6] 'recompile)


;; 对普通 shell-command-on-region 的默认输出启用只读浏览模式。
;; 指定输出目标或选择替换区域时不干预，避免影响命令本来的编辑作用。
(defun sanityinc/shell-command-in-view-mode (start end command &optional output-buffer replace &rest other-args)
  "Put \"*Shell Command Output*\" buffers into view-mode."
  (unless (or output-buffer replace)
    (with-current-buffer "*Shell Command Output*"
      (view-mode 1))))
(advice-add 'shell-command-on-region :after 'sanityinc/shell-command-in-view-mode)


;; 编译模块真正加载后才登记过滤器，将 ANSI 转义颜色转换为 Emacs 文本颜色。
(with-eval-after-load 'compile
  (require 'ansi-color)
  (defun sanityinc/colourise-compilation-buffer ()
    (when (eq major-mode 'compilation-mode)
      (ansi-color-apply-on-region compilation-filter-start (point-max))))
  (add-hook 'compilation-filter-hook 'sanityinc/colourise-compilation-buffer))


(provide 'init-compile)
;;; init-compile.el ends here
