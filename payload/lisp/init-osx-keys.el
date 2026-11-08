;;; init-osx-keys.el --- Configure keys specific to MacOS -*- lexical-binding: t -*-
;;; Commentary:
;; macOS 修饰键和触控板习惯；终端按键还受 iTerm2 的发送设置影响。

;;; Code:

;; 图形 Emacs 中 Command 映射 Meta，Option 保留系统输入功能。
;; 滚轮每次一行，Shift 加快；禁用水平滚动事件以避免误触横向滚动。
(when *is-a-mac*
  (setq mac-command-modifier 'meta)
  (setq mac-option-modifier 'none)
  ;; Make mouse wheel / trackpad scrolling less jerky
  (setq mouse-wheel-scroll-amount '(1
                                    ((shift) . 5)
                                    ((control))))
  (dolist (multiple '("" "double-" "triple-"))
    (dolist (direction '("right" "left"))
      (global-set-key (read-kbd-macro (concat "<" multiple "wheel-" direction ">")) 'ignore)))
  ;; 只在对应 Cocoa 功能存在时登记：M-` 切 frame，M-h 隐藏 Emacs。
  ;; nXML 去掉冲突的局部 M-h；后面的特殊字符键对应当前系统报告的 Cmd-Option-H。
  (when (fboundp 'ns-next-frame)
    (global-set-key (kbd "M-`") 'ns-next-frame))
  (when (fboundp 'ns-do-hide-emacs)
    (global-set-key (kbd "M-h") 'ns-do-hide-emacs)
    (with-eval-after-load 'nxml-mode
      (define-key nxml-mode-map (kbd "M-h") nil)))
  (when (fboundp 'ns-do-hide-others)
    (global-set-key (kbd "M-˙") 'ns-do-hide-others)
    (global-set-key (kbd "M-ˍ") 'ns-do-hide-others)) ;; what describe-key reports for cmd-option-h
  )


(provide 'init-osx-keys)
;;; init-osx-keys.el ends here
