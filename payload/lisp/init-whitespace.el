;;; init-whitespace.el --- Special handling for whitespace -*- lexical-binding: t -*-
;;; Commentary:
;; 显示和清理空白的公共规则，不更改现有 CL 缩进算法。

;;; Code:

;; 默认不显示尾部空白，只在下面列出的编程、文本和配置模式中启用。
(setq-default show-trailing-whitespace nil)


;;; Whitespace

;; buffer-local 设置只影响当前文件；工具/REPL buffer 不会因此统一出现空白标记。
(defun sanityinc/show-trailing-whitespace ()
  "Enable display of trailing whitespace in this buffer."
  (setq-local show-trailing-whitespace t))

(dolist (hook '(prog-mode-hook text-mode-hook conf-mode-hook))
  (add-hook hook 'sanityinc/show-trailing-whitespace))


;; 启用保存时的空白清理策略：此包会考虑文件原有空白状态，避免无差别重写整份旧文件。
;; 具体清理范围仍由该包和 whitespace 的设置决定；本轮不调整保存 hook。
(require-package 'whitespace-cleanup-mode)
(add-hook 'after-init-hook 'global-whitespace-cleanup-mode)
(with-eval-after-load 'whitespace-cleanup-mode
  (diminish 'whitespace-cleanup-mode))

;; 把 just-one-space 的现有入口换成 cycle-spacing；重复调用可在空白状态之间切换。
(global-set-key [remap just-one-space] 'cycle-spacing)


(provide 'init-whitespace)
;;; init-whitespace.el ends here
