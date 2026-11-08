;;; init-corfu.el --- Interactive completion in buffers -*- lexical-binding: t -*-
;;; Commentary:
;; 配置正文 buffer 的补全弹窗；候选仍由当前模式的 completion-at-point 提供。
;; 对 CL 来说候选可以来自 SLIME，Corfu 负责显示，不接管 Lisp 连接。

;;; Code:

;; WAITING: haskell-mode sets tags-table-list globally, breaks tags-completion-at-point-function
;; TODO Default sort order should place [a-z] before punctuation

;; TAB 优先缩进，满足补全条件时再补全；原有个人按键转换仍在入口配置生效。
(setq tab-always-indent 'complete)
;; 确保 Orderless 可用；Vertico 加载时启用空格分段匹配，并保留 basic 作为后备。
;; 清空分类特例，让统一匹配规则生效；候选很少时允许循环补全。
(when (maybe-require-package 'orderless)
  (with-eval-after-load 'vertico
    (require 'orderless)
    (setq completion-styles '(orderless basic))))
(setq completion-category-defaults nil
      completion-category-overrides nil)
(setq completion-cycle-threshold 4)

;; 启动完成后启用全局 Corfu；默认自动弹出候选。
;; Eshell 单独关闭自动弹窗，但仍可手动补全；popupinfo 显示候选文档。
(when (maybe-require-package 'corfu)
  (setq-default corfu-auto t)
  (with-eval-after-load 'eshell
    (add-hook 'eshell-mode-hook (lambda () (setq-local corfu-auto nil))))
  (setq-default corfu-quit-no-match 'separator)
  (add-hook 'after-init-hook 'global-corfu-mode)

  (with-eval-after-load 'corfu
    (when (require 'corfu-popupinfo nil t)
      (corfu-popupinfo-mode 1)))

  ;; TODO: https://github.com/jdtsmith/kind-icon
  )


(provide 'init-corfu)
;;; init-corfu.el ends here
