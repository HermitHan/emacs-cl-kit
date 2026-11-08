;;; init-html.el --- Editing HTML -*- lexical-binding: t -*-
;;; Commentary:
;; HTML/SGML 标签的结构化编辑；ERB 模板设置另见 init-ruby.el。
;; tagedit 为标签提供类似 Paredit 的配对和结构操作，不改变 Lisp 的 Paredit 配置。

;; ERB is configured separately in init-ruby

;;; Code:

(require-package 'tagedit)
;; SGML 库加载后安装 tagedit 的结构编辑键位，并在进入该模式时启用。
;; 释放它占用的 M-? 和 M-s，让这些键继续由其他现有键盘表处理。
(with-eval-after-load 'sgml-mode
  (tagedit-add-paredit-like-keybindings)
  (define-key tagedit-mode-map (kbd "M-?") nil)
  (define-key tagedit-mode-map (kbd "M-s") nil)
  (add-hook 'sgml-mode-hook (lambda () (tagedit-mode 1))))

;; 补充 .jsp 和 .tmpl 文件的 HTML 模式识别。
(add-auto-mode 'html-mode "\\.\\(jsp\\|tmpl\\)\\'")


(provide 'init-html)
;;; init-html.el ends here
