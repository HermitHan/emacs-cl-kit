;;; init-dash.el --- Integrate with the Mac app "Dash" -*- lexical-binding: t -*-
;;; Commentary:
;; 仅在 macOS 配置 Dash 文档浏览器集成。
;; C-c D 查询光标处的符号；需要本机 Dash 应用及相应离线文档集。

;;; Code:

;; Support for the http://kapeli.com/dash documentation browser

(when *is-a-mac*
  (require-package 'dash-at-point)
  (global-set-key (kbd "C-c D") 'dash-at-point))

(provide 'init-dash)
;;; init-dash.el ends here
