;;; init-nim.el --- Nim programming support -*- lexical-binding: t -*-
;;; Commentary:
;; Nim 源码编辑与 Flycheck 检查器集成。
;; 只有 nim-mode 和 Flycheck 都加载后才注册 Nim 检查器；编译/检查仍依赖 Nim 工具链。
;;; Code:

(when (maybe-require-package 'nim-mode)
  (when (maybe-require-package 'flycheck-nim)
    (with-eval-after-load 'nim-mode
      (with-eval-after-load 'flycheck
        (require 'flycheck-nim)))))

(provide 'init-nim)

;;; init-nim.el ends here
