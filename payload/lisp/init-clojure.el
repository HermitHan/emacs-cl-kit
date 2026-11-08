;;; init-clojure.el --- Clojure support -*- lexical-binding: t -*-
;;; Commentary:
;; Clojure 源码与构建工具支持；交互式开发配置见 init-clojure-cider.el。
;; 这是 JVM/Clojure 工作流，不替代 Common Lisp 的 SLIME。
;;; Code:

;; See also init-clojure-cider.el

;; 模式包可用时再确保 ClojureScript 构建和 Leiningen 辅助包可用；这里不执行构建。
(when (maybe-require-package 'clojure-mode)
  (require-package 'cljsbuild-mode)
  (require-package 'elein)

  ;; 真正加载 clojure-mode 后登记共享 Lisp 编辑设置及驼峰单词移动。
  ;; 共享函数 sanityinc/lisp-setup 在 init-lisp.el 中定义，避免在本文件重复实现。
  (with-eval-after-load 'clojure-mode
    (add-hook 'clojure-mode-hook 'sanityinc/lisp-setup)
    (add-hook 'clojure-mode-hook 'subword-mode)))


(provide 'init-clojure)
;;; init-clojure.el ends here
