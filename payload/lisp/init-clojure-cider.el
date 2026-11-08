;;; init-clojure-cider.el --- Cider support for clojure -*- lexical-binding: t -*-
;;; Commentary:
;; CIDER 提供 Clojure 的 REPL、求值和错误查询；需要项目中的 Clojure/nREPL 环境。
;; 本文件登记集成规则，不会在加载时自动启动 JVM 或连接项目。
;;; Code:

;; 先加载 Clojure 编辑配置，确保会话和源码采用同一套基础设置。
(require 'init-clojure)

(when (maybe-require-package 'cider)
  ;; 保留不自动弹出错误 buffer 的习惯；错误仍可通过 CIDER 自身命令查看。
  (setq cider-show-error-buffer nil)

  ;; CIDER 库加载后为 REPL 登记 Paredit 结构编辑和 subword 单词移动。
  (with-eval-after-load 'cider
    (add-hook 'cider-repl-mode-hook 'subword-mode)
    (add-hook 'cider-repl-mode-hook 'paredit-mode))

  ;; Clojure、CIDER、Flycheck 三个库都可用后才注册检查器。
  ;; 这里保留 Flycheck 后端，其他模块可能通过 Flymake 桥接使用它。
  (require-package 'flycheck-clojure)
  (with-eval-after-load 'clojure-mode
    (with-eval-after-load 'cider
      (with-eval-after-load 'flycheck
        (flycheck-clojure-setup)))))


(provide 'init-clojure-cider)
;;; init-clojure-cider.el ends here
