;;; init-markdown.el --- Markdown support -*- lexical-binding: t -*-
;;; Commentary:
;; Markdown 文件编辑，另将 .md.html 识别为 Markdown。
;; Markdown 中行尾两个空格可表示显式换行，因此将该模式排除在自动空白清理之外。
;;; Code:

(when (maybe-require-package 'markdown-mode)
  (add-auto-mode 'markdown-mode "\\.md\\.html\\'")
  (with-eval-after-load 'whitespace-cleanup-mode
    (add-to-list 'whitespace-cleanup-mode-ignore-modes 'markdown-mode)))


(provide 'init-markdown)
;;; init-markdown.el ends here
