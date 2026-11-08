;;; init-gui-frames.el --- Behaviour specific to non-TTY frames -*- lexical-binding: t -*-
;;; Commentary:
;; 顶层窗口的显示偏好；部分设置也作用于终端，图形专属能力均按平台判断。

;;; Code:


;; Stop C-z from minimizing windows under OS X

;; macOS 图形窗口中让 C-z 不再意外最小化；终端及其他环境仍调用 suspend-frame。
(defun sanityinc/maybe-suspend-frame ()
  (interactive)
  (unless (and *is-a-mac* window-system)
    (suspend-frame)))

(global-set-key (kbd "C-z") 'sanityinc/maybe-suspend-frame)



;; Suppress GUI features

;; 用 minibuffer 而非系统对话框选文件/回答问题，并关闭启动欢迎页。
(setq use-file-dialog nil)
(setq use-dialog-box nil)
(setq inhibit-startup-screen t)



;; Window size and features

;; 允许按像素调整窗口/frame 尺寸；隐藏工具栏、滚动条、菜单栏并移除内部边框。
(setq-default
 window-resize-pixelwise t
 frame-resize-pixelwise t)

(when (fboundp 'tool-bar-mode)
  (tool-bar-mode -1))
(when (fboundp 'set-scroll-bar-mode)
  (set-scroll-bar-mode nil))

(menu-bar-mode -1)

(let ((no-border '(internal-border-width . 0)))
  (add-to-list 'default-frame-alist no-border)
  (add-to-list 'initial-frame-alist no-border))

;; 图形 frame 的透明度按步长调整并限制在允许范围；终端不支持此操作。
;; 兼容 alpha 参数的单值和双值表示，不修改字体和主题。
(defun sanityinc/adjust-opacity (frame incr)
  "Adjust the background opacity of FRAME by increment INCR."
  (unless (display-graphic-p frame)
    (error "Cannot adjust opacity of this frame"))
  (let* ((oldalpha (or (frame-parameter frame 'alpha) 100))
         ;; The 'alpha frame param became a pair at some point in
         ;; emacs 24.x, e.g. (100 100)
         (oldalpha (if (listp oldalpha) (car oldalpha) oldalpha))
         (newalpha (+ incr oldalpha)))
    (when (and (<= frame-alpha-lower-limit newalpha) (>= 100 newalpha))
      (modify-frame-parameters frame (list (cons 'alpha newalpha))))))

;; macOS 图形后端可用时登记全屏命令；具体按键受 macOS 修饰键映射影响。
(when (and *is-a-mac* (fboundp 'toggle-frame-fullscreen))
  ;; Command-Option-f to toggle fullscreen mode
  ;; Hint: Customize `ns-use-native-fullscreen'
  (global-set-key (kbd "M-ƒ") 'toggle-frame-fullscreen))

;; TODO: use seethru package instead?
;; C-M-8 降低透明度，C-M-9 提高透明度，C-M-7 恢复完全不透明。
(global-set-key (kbd "M-C-8") (lambda () (interactive) (sanityinc/adjust-opacity nil -2)))
(global-set-key (kbd "M-C-9") (lambda () (interactive) (sanityinc/adjust-opacity nil 2)))
(global-set-key (kbd "M-C-7") (lambda () (interactive) (modify-frame-parameters nil `((alpha . 100)))))


;; macOS 标题栏自动匹配主题明暗；只在扩展包可用时启用。
(when *is-a-mac*
  (when (maybe-require-package 'ns-auto-titlebar)
    (ns-auto-titlebar-mode)))


;; 标题显示当前文件的简写路径；非文件 buffer 使用其名称。
(setq frame-title-format
      '((:eval (if (buffer-file-name)
                   (abbreviate-file-name (buffer-file-name))
                 "%b"))))

;; Non-zero values for `line-spacing' can mess up ansi-term and co,
;; so we zero it explicitly in those cases.
;; 终端模拟 buffer 关闭额外行距，避免终端字符网格错位。
(add-hook 'term-mode-hook
          (lambda ()
            (setq line-spacing 0)))


;; Change global font size easily

;; 启动后启用默认字号缩放工具；使用其模式按键/命令统一调整显示字号。
(require-package 'default-text-scale)
(add-hook 'after-init-hook 'default-text-scale-mode)



;; 仅准备禁用鼠标的工具包；这里不自动启用 disable-mouse-mode。
(require-package 'disable-mouse)


(provide 'init-gui-frames)
;;; init-gui-frames.el ends here
