;;; init-haskell.el --- Support the Haskell language -*- lexical-binding: t -*-
;;; Commentary:
;; Haskell/Cabal 编辑、交互式会话、缩进及手动/保存时格式化工具。
;; 模式包与外部工具分开：hindent、ormolu、Hoogle/GHC 环境需按项目自行准备。
;;; Code:

;; 只有可选 Haskell 包可用时登记以下 hook；subword-mode 改善驼峰名称的单词移动。
(when (maybe-require-package 'haskell-mode)
  (add-hook 'haskell-mode-hook 'subword-mode)
  (add-hook 'haskell-cabal-mode-hook 'subword-mode)

  ;; 源码 buffer 中启用交互会话集成；这里不直接启动 GHCi。
  (add-hook 'haskell-mode-hook 'interactive-haskell-mode)

  (add-auto-mode 'haskell-mode "\\.ghci\\'")

  ;; 缩进：用现行次模式接口替代过时 helper；显式 1 保持“启用”语义。
  ;; 重跑 hook 也不会把已启用的缩进模式关掉。
  (add-hook 'haskell-mode-hook (lambda () (haskell-indentation-mode 1)))


  ;; 进入新模块时沿用 haskell-mode 的模块模板助手；具体是否插入由该助手判断。
  ;; Source code helpers

  (add-hook 'haskell-mode-hook 'haskell-auto-insert-module-template)

  ;; reformatter-define 生成 buffer/region 格式化命令及 on-save 次模式。
  ;; M-x hindent-mode 是 hindent-on-save-mode 的原有别名；本段没有自动启用保存格式化。
  (when (maybe-require-package 'reformatter)
    (reformatter-define hindent
      :program "hindent"
      :lighter " Hin")

    (defalias 'hindent-mode 'hindent-on-save-mode)

    (reformatter-define ormolu
      :program "ormolu"
      :lighter " Orm"))

  ;; Haskell 键位：C-c h 查询 Hoogle，C-o 保持 open-line（插入换行但不移动光标）。
  (with-eval-after-load 'haskell-mode
    (define-key haskell-mode-map (kbd "C-c h") 'hoogle)
    (define-key haskell-mode-map (kbd "C-o") 'open-line))


  ;; 以横线显示源码中的分页符；仅改变显示。
  (with-eval-after-load 'page-break-lines
    (add-to-list 'page-break-lines-modes 'haskell-mode)))



;; 另外保留 Dhall 配置语言的编辑支持，未设置额外快捷键。
(maybe-require-package 'dhall-mode)




(provide 'init-haskell)
;;; init-haskell.el ends here
