;;; init-textile.el --- Edit Textile markup -*- lexical-binding: t -*-
;;; Commentary:
;; Textile 轻量标记语言的编辑模式；.textile 文件自动启用。
;; 本模块只做模式安装与文件关联，不自动导出或发布内容。
;;; Code:

(require-package 'textile-mode)

(setq auto-mode-alist
      (cons '("\\.textile\\'" . textile-mode) auto-mode-alist))


(provide 'init-textile)
;;; init-textile.el ends here
