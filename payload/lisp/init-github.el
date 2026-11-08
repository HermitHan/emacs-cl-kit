;;; init-github.el --- Github integration -*- lexical-binding: t -*-
;;; Commentary:
;; 准备 GitHub 辅助功能；登录、读取远端和提交操作由所调用的具体命令决定。

;;; Code:

;; 复用 Git 基础配置；require 遇到已加载模块会直接返回，不重复加载。
(require 'init-git)

;; 准备 Gist 工具及 GitHub 问题引用识别；prog-mode 中启用的是引用链接模式。
(maybe-require-package 'yagist)
(require-package 'bug-reference-github)
(add-hook 'prog-mode-hook 'bug-reference-prog-mode)

;; 安装检查：仓库克隆、Forge 和 PR 审阅工具。这里没有自动 clone、登录或同步。
(maybe-require-package 'github-clone)
(maybe-require-package 'forge)
(maybe-require-package 'github-review)

(provide 'init-github)
;;; init-github.el ends here
