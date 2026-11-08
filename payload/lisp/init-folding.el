;;; init-folding.el --- Support code and region folding -*- lexical-binding: t -*-
;;; Commentary:
;; 准备 Origami 代码折叠，按键只在 origami-mode 启用时生效。
;; C-c f 递归切换当前节点折叠，C-c F 切换所有节点；本文件没有全局启用该模式。

;;; Code:

(when (maybe-require-package 'origami)
  (with-eval-after-load 'origami
    (define-key origami-mode-map (kbd "C-c f") 'origami-recursively-toggle-node)
    (define-key origami-mode-map (kbd "C-c F") 'origami-toggle-all-nodes)))


(provide 'init-folding)
;;; init-folding.el ends here
