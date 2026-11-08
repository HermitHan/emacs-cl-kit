;;; init-elm.el --- Support for the Elm language -*- lexical-binding: t -*-
;;; Commentary:
;; Elm 源码编辑及测试入口；格式化需要 PATH 中存在 elm-format。
;; 包可用时注册设置，打开相关文件才进入对应编辑模式。
;;; Code:

(when (maybe-require-package 'elm-mode)
  ;; elm-mode 加载时检查格式化程序；存在才默认启用保存时格式化。
  ;; diminish 只隐藏缩进次模式的状态栏名称，不禁用缩进。
  (with-eval-after-load 'elm-mode
    (diminish 'elm-indent-mode)
    (when (executable-find "elm-format")
      (setq-default elm-format-on-save t)))
  ;; 保留 Elm 测试命令包；此处不运行测试。
  (maybe-require-package 'elm-test-runner))

(provide 'init-elm)
;;; init-elm.el ends here
