;;; init-frame-hooks.el --- Provide specific hooks for GUI/TTY frame creation -*- lexical-binding: t -*-
;;; Commentary:
;; 区分终端 frame 与图形 frame，给鼠标、显示等配置提供各自初始化入口。
;; frame 是一个顶层 Emacs 窗口；其中的多个分屏称为 window。

;;; Code:

;; 这两个变量是本配置自定义钩子，不是 Emacs 内置钩子；按 frame 类型选择其中一个。
(defvar after-make-console-frame-hooks '()
  "Hooks to run after creating a new TTY frame")
(defvar after-make-window-system-frame-hooks '()
  "Hooks to run after creating a new window-system frame")

;; 临时选中新建 frame 后执行对应钩子，完成后恢复原来选中的 frame。
(defun run-after-make-frame-hooks (frame)
  "Run configured hooks in response to the newly-created FRAME.
Selectively runs either `after-make-console-frame-hooks' or
`after-make-window-system-frame-hooks'"
  (with-selected-frame frame
    (run-hooks (if window-system
                   'after-make-window-system-frame-hooks
                 'after-make-console-frame-hooks))))

;; 以后创建的 frame 走这里；初始 frame 已经存在，因此还需在启动完成后补运行一次。
(add-hook 'after-make-frame-functions 'run-after-make-frame-hooks)

(defconst sanityinc/initial-frame (selected-frame)
  "The frame (if any) active during Emacs initialization.")

(add-hook 'after-init-hook
          (lambda () (when sanityinc/initial-frame
                  (run-after-make-frame-hooks sanityinc/initial-frame))))


(provide 'init-frame-hooks)
;;; init-frame-hooks.el ends here
