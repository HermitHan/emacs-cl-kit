;;; init-python.el --- Python editing -*- lexical-binding: t -*-
;;; Commentary:
;; Python 源码、依赖文件和 Black 格式化命令。
;; 下方关于 nix/direnv 的英文是原配置作者的背景说明，不代表你的项目已经启用这些环境。
;;; Code:

;; I use nix + direnv instead of virtualenv/pyenv/pyvenv, and it is an
;; approach which extends to other languages too. I recorded a
;; screencast about this: https://www.youtube.com/watch?v=TbIHRHy7_JM


;; 将 SCons 构建文件识别为 Python；交互解释器默认使用 PATH 中的 python3。
(setq auto-mode-alist
      (append '(("SConstruct\\'" . python-mode)
                ("SConscript\\'" . python-mode))
              auto-mode-alist))

(setq python-shell-interpreter "python3")

;; requirements 依赖文件使用专门模式；Poetry 锁文件按 TOML 语法编辑。
(require-package 'pip-requirements)

(when (maybe-require-package 'toml-mode)
  (add-to-list 'auto-mode-alist '("poetry\\.lock\\'" . toml-mode)))

;; 生成 black-buffer / black-region / black-on-save-mode，外部 black 从标准输入读取源码。
;; 本段不自动开启保存格式化，也不安装 Python 包 black；可手动通过 M-x 调用。
(when (maybe-require-package 'reformatter)
  (reformatter-define black :program "black" :args '("-")))

(provide 'init-python)
;;; init-python.el ends here
