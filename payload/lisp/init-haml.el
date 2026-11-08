;;; init-haml.el --- Haml template support -*- lexical-binding: t -*-
;;; Commentary:
;; Haml 模板编辑支持；打开相应文件时由 haml-mode 的自动加载规则接管。
;;; Code:

(require-package 'haml-mode)

;; Haml 模式中 C-o 保持 open-line：在当前位置插入换行，光标不随之下移。
(with-eval-after-load 'haml-mode
  (define-key haml-mode-map (kbd "C-o") 'open-line))

(provide 'init-haml)
;;; init-haml.el ends here
