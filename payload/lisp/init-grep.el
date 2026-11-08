;;; init-grep.el --- Settings for grep and grep-like tools -*- lexical-binding: t -*-
;;; Commentary:
;; 配置外部全文搜索及可编辑的搜索结果；外部 rg/ag 必须已经安装。

;;; Code:

;; 高亮命中并跟随输出滚动；macOS 的 M-x locate 使用 Spotlight 的 mdfind。
(setq-default grep-highlight-matches t
              grep-scroll-output t)

(when *is-a-mac*
  (setq-default locate-command "mdfind"))

;; 在 grep 结果中按 C-c C-q 或 w 进入 Wgrep，编辑结果后按模式提示写回文件。
(require-package 'wgrep)
(with-eval-after-load 'grep
  (dolist (key (list (kbd "C-c C-q") (kbd "w")))
    (define-key grep-mode-map key 'wgrep-change-to-wgrep-mode)))

;; 有 ag 时把 M-? 绑定到项目搜索；后面的 rg 和 minibuffer 模块可能按加载顺序覆盖它。
;; 便携包并未捆绑可选的 ag/wgrep-ag 库。新机器即使碰巧装了 ag 程序，
;; 也不因此在离线启动时隐式下载；手动装好两库后仍会自动启用，rg 不受影响。
(when (and (executable-find "ag") (locate-library "ag") (locate-library "wgrep-ag"))
  (setq-default ag-highlight-search t)
  (global-set-key (kbd "M-?") 'ag-project))

;; rg 可用时优先绑定到 rg-project；C-h k M-? 查看最终生效的命令。
(when (and (executable-find "rg")
           (maybe-require-package 'rg))
  (global-set-key (kbd "M-?") 'rg-project))


(provide 'init-grep)
;;; init-grep.el ends here
