;;; init-php.el --- Support for working with PHP -*- lexical-binding: t -*-
;;; Commentary:
;; 保留 PHP 编辑模式和 Smarty 模板支持；只有 php-mode 可用时才确保 Smarty 包可用。
;; 这里没有额外个人快捷键，也不会启动 PHP 服务或执行当前文件。
;;; Code:

(when (maybe-require-package 'php-mode)
  (maybe-require-package 'smarty-mode))

(provide 'init-php)
;;; init-php.el ends here
