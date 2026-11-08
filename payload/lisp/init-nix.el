;;; init-nix.el --- Support for the Nix package manager -*- lexical-binding: t -*-
;;; Commentary:
;; 保留 Nix 文件编辑及项目环境辅助包：nixpkgs-fmt、nix-sandbox、nix-buffer。
;; 此处只保证包可用，没有自动进入沙箱或启用保存格式化。
;;; Code:

(when (maybe-require-package 'nix-mode)
  (maybe-require-package 'nixpkgs-fmt)
  (maybe-require-package 'nix-sandbox)
  (maybe-require-package 'nix-buffer)

  ;; nixos-options 的补全桥接仍是待办：这里安装包，但尚未把它接入现有 CAPF 补全。
  (when (maybe-require-package 'nixos-options)
    ;; TODO: write a CAPF backend based on company-nixos-options
    ))


(provide 'init-nix)
;;; init-nix.el ends here
