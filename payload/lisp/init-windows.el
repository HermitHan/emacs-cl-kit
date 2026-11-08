;;; init-windows.el --- Working with windows within frames -*- lexical-binding: t -*-
;;; Commentary:

;; This is not about the "Windows" OS, but rather Emacs's "windows"
;; concept: these are the panels within an Emacs frame which contain
;; buffers.

;; 管理一个 frame 内的分屏 window，不是 Windows 操作系统配置。
;; window 显示 buffer；关闭分屏通常不等于关闭 buffer，更不等于删除文件。

;;; Code:

;; Navigate window layouts with "C-c <left>" and "C-c <right>"

;; Winner 记住窗口布局，C-c 左/右可撤销/重做布局变化。
(add-hook 'after-init-hook 'winner-mode)


;; Make "C-x o" prompt for a target window when there are more than 2
;; C-x o 用字母选择目标窗口；候选标签不超时，按标签即可切换。
(require-package 'switch-window)
(setq-default switch-window-shortcut-style 'alphabet)
(setq-default switch-window-timeout nil)
(global-set-key (kbd "C-x o") 'switch-window)



;; When splitting window, show (other-buffer) in the new window

;; 包装分屏命令：新窗显示 other-buffer，并默认把光标移过去。
;; 带 C-u 前缀时仍分屏，但保留当前选中的窗口。
(defun split-window-func-with-other-buffer (split-function)
  (lambda (&optional arg)
    "Split this window and switch to the new window unless ARG is provided."
    (interactive "P")
    (funcall split-function)
    (let ((target-window (next-window)))
      (set-window-buffer target-window (other-buffer))
      (unless arg
        (select-window target-window)))))

;; C-x 2 上下分屏，C-x 3 左右分屏；保持原有键位和行为。
(global-set-key (kbd "C-x 2") (split-window-func-with-other-buffer 'split-window-vertically))
(global-set-key (kbd "C-x 3") (split-window-func-with-other-buffer 'split-window-horizontally))

;; C-x 1 留下当前分屏；如果已经只有一个且 Winner 开启，则恢复上一布局。
(defun sanityinc/toggle-delete-other-windows ()
  "Delete other windows in frame if any, or restore previous window config."
  (interactive)
  (if (and winner-mode
           (equal (selected-window) (next-window)))
      (winner-undo)
    (delete-other-windows)))

(global-set-key (kbd "C-x 1") 'sanityinc/toggle-delete-other-windows)


;; Rearrange split windows

;; 重新安排为左右分屏，保留当前及下一窗口的 buffer；C-x | 调用。
;; 下面 vertically 对应上下分屏（C-x _）；按实际 split API 理解方向。
(defun split-window-horizontally-instead ()
  "Kill any other windows and re-split such that the current window is on the top half of the frame."
  (interactive)
  (let ((other-buffer (and (next-window) (window-buffer (next-window)))))
    (delete-other-windows)
    (split-window-horizontally)
    (when other-buffer
      (set-window-buffer (next-window) other-buffer))))

(defun split-window-vertically-instead ()
  "Kill any other windows and re-split such that the current window is on the left half of the frame."
  (interactive)
  (let ((other-buffer (and (next-window) (window-buffer (next-window)))))
    (delete-other-windows)
    (split-window-vertically)
    (when other-buffer
      (set-window-buffer (next-window) other-buffer))))

(global-set-key (kbd "C-x |") 'split-window-horizontally-instead)
(global-set-key (kbd "C-x _") 'split-window-vertically-instead)


;; F7 显示最近的另一个 buffer；连续按两次时，在同一 frame 恢复之前的布局。
(defun sanityinc/split-window ()
  "切换到另一个窗口中的最近 buffer，再按一次 F7 可恢复原窗口布局。"
  (interactive)
  (let ((saved (frame-parameter nil 'han-f7-layout)))
    (cond
     ((and (eq last-command 'sanityinc/split-window)
           (window-configuration-p saved))
      (set-window-configuration saved)
      (set-frame-parameter nil 'han-f7-layout nil))
     (t
      (set-frame-parameter nil 'han-f7-layout (current-window-configuration))
      (switch-to-buffer-other-window (other-buffer))))))

(global-set-key (kbd "<f7>") 'sanityinc/split-window)




;; C-c 下 切换当前窗口是否专用于这个 buffer；专用窗口通常不会被其他显示命令复用。
(defun sanityinc/toggle-current-window-dedication ()
  "Toggle whether the current window is dedicated to its current buffer."
  (interactive)
  (let* ((window (selected-window))
         (was-dedicated (window-dedicated-p window)))
    (set-window-dedicated-p window (not was-dedicated))
    (message "Window %sdedicated to %s"
             (if was-dedicated "no longer " "")
             (buffer-name))))

(global-set-key (kbd "C-c <down>") 'sanityinc/toggle-current-window-dedication)




;; 除 nt/w32 图形后端外（包括普通终端）：Control+方向切窗，Control+Shift+方向交换内容。
;; 各模式可能覆盖键位，查看当前作用用 C-h k；本轮不改变这些全局设置。
(unless (memq window-system '(nt w32))
  (require-package 'windswap)
  (add-hook 'after-init-hook (apply-partially 'windmove-default-keybindings 'control))
  (add-hook 'after-init-hook (apply-partially 'windswap-default-keybindings 'shift 'control)))


(provide 'init-windows)
;;; init-windows.el ends here
