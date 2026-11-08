;;; init-uniquify.el --- Configure uniquification of buffer names -*- lexical-binding: t -*-
;;; Commentary:
;; 同名文件 buffer 用目录信息区分，例如不同目录的 init.el。
;; reverse 从文件名向上补充目录，用“ • ”分隔；关闭同名 buffer 后重新简化名称。
;; 以 * 开头的工具 buffer 不参与改名，gptel/REPL 等工具名称沿用自己的规则。

;;; Code:

;; Nicer naming of buffers for files with identical names
(require 'uniquify)

(setq uniquify-buffer-name-style 'reverse)
(setq uniquify-separator " • ")
(setq uniquify-after-kill-buffer-p t)
(setq uniquify-ignore-buffers-re "^\\*")


(provide 'init-uniquify);;; init-uniquify.el ends here
