;;; init-themes.el --- Defaults for themes -*- lexical-binding: t -*-
;;; Commentary:
;; 主题加载、明暗切换和非活动窗口变暗。
;; Custom 文件可覆盖默认主题；本轮保留当前颜色和加载顺序。

;;; Code:

;; 准备 Solarized/Tomorrow 两套主题，装包本身不立即切换配色。
(require-package 'color-theme-sanityinc-solarized)
(require-package 'color-theme-sanityinc-tomorrow)

;; Don't prompt to confirm theme safety. This avoids problems with
;; first-time startup on Emacs > 26.3.
;; 沿用当前信任所有主题、不再逐个询问的设置；这里不改变用户选择。
(setq custom-safe-themes t)

;; If you don't customize it, this is the theme you get.
;; 未被 Custom 覆盖时默认使用 Tomorrow Bright 深色主题。
(setq-default custom-enabled-themes '(sanityinc-tomorrow-bright))

;; Ensure that themes will be applied even if they have not been customized
;; 先加载尚未定义的主题，再应用 custom-enabled-themes 列表；启动完成后运行一次。
(defun reapply-themes ()
  "Forcibly load the themes listed in `custom-enabled-themes'."
  (dolist (theme custom-enabled-themes)
    (unless (custom-theme-p theme)
      (load-theme theme)))
  (custom-set-variables `(custom-enabled-themes (quote ,custom-enabled-themes))))

(add-hook 'after-init-hook 'reapply-themes)



;; Toggle between light and dark

;; M-x light 切到浅色，M-x dark 切回深色；两者复用同一个应用主题函数。
(defun light ()
  "Activate a light color theme."
  (interactive)
  (setq custom-enabled-themes '(sanityinc-tomorrow-day))
  (reapply-themes))

(defun dark ()
  "Activate a dark color theme."
  (interactive)
  (setq custom-enabled-themes '(sanityinc-tomorrow-bright))
  (reapply-themes))


;; 非活动窗口变暗 15%，便于找到当前输入窗口；主题背景变化时重新计算。
;; 终端 frame 明确排除，避免有限颜色造成对比度变差。
(when (maybe-require-package 'dimmer)
  (setq-default dimmer-fraction 0.15)
  (add-hook 'after-init-hook 'dimmer-mode)
  (with-eval-after-load 'dimmer
    ;; TODO: file upstream as a PR
    (advice-add 'frame-set-background-mode :after (lambda (&rest args) (dimmer-process-all))))
  (with-eval-after-load 'dimmer
    ;; Don't dim in terminal windows. Even with 256 colours it can
    ;; lead to poor contrast.  Better would be to vary dimmer-fraction
    ;; according to frame type.
    (defun sanityinc/display-non-graphic-p ()
      (not (display-graphic-p)))
    (add-to-list 'dimmer-exclusion-predicates 'sanityinc/display-non-graphic-p)))


(provide 'init-themes)
;;; init-themes.el ends here
