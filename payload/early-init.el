;;; early-init.el --- Emacs 27+ pre-initialisation config

;;; Commentary:

;; Emacs 27 起在主 init.el 之前读取本文件，适合放包初始化等必须提前设置的选项。
;; 此处关闭默认的包自动激活，随后由 lisp/init-elpa.el 显式激活一次，
;; 这样可以先设置 elpa-版本号目录和软件源；不是禁用 ELPA 包，也不是卸载包。
;; 日常语言/快捷键设置放在 init.el 或 lisp/，通常无需修改本文件。

;;; Code:

(setq package-enable-at-startup nil)

;; So we can detect this having been loaded
(provide 'early-init)

;;; early-init.el ends here
