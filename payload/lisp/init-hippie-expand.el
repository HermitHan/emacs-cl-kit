;;; init-hippie-expand.el --- Settings for hippie-expand -*- lexical-binding: t -*-
;;; Commentary:
;; M-/ 按下面顺序尝试补全：文件名、当前 buffer 的词、其他 buffer 的词、kill-ring。
;; 连续调用可尝试后续候选；这与 Corfu 的 completion-at-point 候选来源不同。
;; 入口文件可能有个人按键转换，C-h k 可查看物理按键实际调用。

;;; Code:

(global-set-key (kbd "M-/") 'hippie-expand)

(setq hippie-expand-try-functions-list
      '(try-complete-file-name-partially
        try-complete-file-name
        try-expand-dabbrev
        try-expand-dabbrev-all-buffers
        try-expand-dabbrev-from-kill))

(provide 'init-hippie-expand)
;;; init-hippie-expand.el ends here
