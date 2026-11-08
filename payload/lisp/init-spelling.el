;;; init-spelling.el --- Spell check settings -*- lexical-binding: t -*-
;;; Commentary:
;; 仅在找到 ispell-program-name 指定的外部拼写程序时启用编程注释拼写检查。
;; flyspell-prog-mode 主要检查注释/字符串，不把全部代码标识符当作自然语言。

;;; Code:

(require 'ispell)

(when (executable-find ispell-program-name)
  ;; Add spell-checking in comments for all programming language modes
  (add-hook 'prog-mode-hook 'flyspell-prog-mode)

  ;; 释放 Flyspell 的 C-;，让全局 Avy 快速定位仍可用；同时检查 nXML 文本区域。
  (with-eval-after-load 'flyspell
    (define-key flyspell-mode-map (kbd "C-;") nil)
    (add-to-list 'flyspell-prog-text-faces 'nxml-text-face)))

(provide 'init-spelling)
;;; init-spelling.el ends here
