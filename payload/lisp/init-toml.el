;;; init-toml.el --- Support TOML files -*- lexical-binding: t -*-
;;; Commentary:
;; TOML 配置文件编辑支持；具体文件识别由 toml-mode 的自动加载规则提供。
;; 进入该模式时启用 goto-address-prog-mode，使文本中的 URL 可被识别和访问。
;;; Code:

(when (maybe-require-package 'toml-mode)
  (add-hook 'toml-mode-hook 'goto-address-prog-mode))


(provide 'init-toml)
;;; init-toml.el ends here
