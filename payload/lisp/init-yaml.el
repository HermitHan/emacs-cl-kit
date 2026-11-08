;;; init-yaml.el --- Support Yaml files -*- lexical-binding: t -*-
;;; Commentary:
;; YAML 编辑支持，额外把 .yml.erb 文件关联到 yaml-mode。
;; 进入该模式时识别文本中的 URL；ERB 的混合语法规则另见 init-ruby.el。
;;; Code:

(when (maybe-require-package 'yaml-mode)
  (add-auto-mode 'yaml-mode "\\.yml\\.erb\\'")
  (add-hook 'yaml-mode-hook 'goto-address-prog-mode))


(provide 'init-yaml)
;;; init-yaml.el ends here
