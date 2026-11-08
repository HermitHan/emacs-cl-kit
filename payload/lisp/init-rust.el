;;; init-rust.el --- Support for the Rust language -*- lexical-binding: t -*-
;;; Commentary:
;; Rust 源码编辑与 Flycheck Rust 检查器登记。
;; 现有诊断界面使用 Flymake/Flycheck 桥接，因此在 rust-mode-hook 中注册检查器，
;; 不依赖 flycheck-mode-hook；实际检查仍需要对应 Rust/Cargo 工具链。
;;; Code:

(when (maybe-require-package 'rust-mode)
  (when (maybe-require-package 'flycheck-rust)
    ;; Flymake 的 Flycheck 桥接不会触发 flycheck-mode-hook。
    (add-hook 'rust-mode-hook #'flycheck-rust-setup)))

(provide 'init-rust)
;;; init-rust.el ends here
