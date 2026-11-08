;;; init-eglot.el --- LSP support via eglot          -*- lexical-binding: t; -*-

;;; Commentary:

;; 准备 Eglot（LSP 客户端）及 Consult 查询工具，不在这里为任何语言自动启动服务。
;; 某种语言是否调用 eglot-ensure 由其模块决定；Common Lisp 仍使用 SLIME。

;;; Code:

;; For Emacs >= 27
;; 把每次读取子进程输出的上限设为 1 MiB，减少较大 LSP 消息的分段读取。
(setq read-process-output-max (* 1024 1024))


;; 确保相关包可用；这里的安装检查不等于连接语言服务器。
(when (maybe-require-package 'eglot)
  (maybe-require-package 'consult-eglot))




(provide 'init-eglot)
;;; init-eglot.el ends here
