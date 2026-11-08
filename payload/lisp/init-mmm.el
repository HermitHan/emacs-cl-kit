;;; init-mmm.el --- Multiple Major Modes support -*- lexical-binding: t -*-
;;; Commentary:
;; 为同一文件内嵌多种语言提供 MMM 基础设施，例如 HTML 内的 CSS。
;; 只在已经注册子模式规则的 buffer 中自动启用；具体规则由语言模块添加。

;;; Code:

;; 先确保包可用，再加载自动识别入口；装包与加载在这里是明确的两个步骤。
(require-package 'mmm-mode)
(require 'mmm-auto)
(setq mmm-global-mode 'buffers-with-submode-classes)
;; 子区域使用级别 2 的背景/边界装饰，帮助识别嵌入语言的范围。
(setq mmm-submode-decoration-level 2)


(provide 'init-mmm)
;;; init-mmm.el ends here
