;;; init-xterm.el --- Integrate with terminals such as xterm -*- lexical-binding: t -*-
;;; Commentary:
;; 针对 iTerm2/xterm 等终端 frame 的鼠标初始化；图形 frame 不运行此专用钩子。
;; 原有滚轮和按键绑定保留，只把旧滚轮启用接口换成现代明确启用方式。

;;; Code:

;; 依赖本配置的 frame 分类钩子，使首次及以后创建的终端 frame 都有机会初始化。
(require 'init-frame-hooks)

;; 保留旧终端事件 mouse-4/mouse-5 的逐行滚动入口；具体终端可能报告 wheel 事件。
(global-set-key [mouse-4] (lambda () (interactive) (scroll-down 1)))
(global-set-key [mouse-5] (lambda () (interactive) (scroll-up 1)))

;; 声明按需加载滚轮支持；这里只登记函数入口，不立即开启鼠标模式。
(autoload 'mouse-wheel-mode "mwheel")

;; 终端中启用鼠标事件与滚轮，显式传 1，重复运行也保持启用。
;; 终端通常可按住 Shift 绕过应用鼠标处理来选择/粘贴，具体取决于终端设置。
(defun sanityinc/console-frame-setup ()
  (xterm-mouse-mode 1) ; Mouse in a terminal (Use shift to paste with middle button)
  (mouse-wheel-mode 1))



(add-hook 'after-make-console-frame-hooks 'sanityinc/console-frame-setup)

(provide 'init-xterm)
;;; init-xterm.el ends here
