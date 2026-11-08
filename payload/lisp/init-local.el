;;; init-local.el --- Personal additions -*- lexical-binding: t -*-

;; 个人扩展统一入口：主 init 在基础环境准备好后加载这里。
;; require 使用 feature 标记避免重复加载；gptel 内部再加载偏好与工作流模块。
;; 此文件不维护 CL/SLIME 键位，便于以后独立排查 AI 配置。
(require 'init-gptel)

(provide 'init-local)
;;; init-local.el ends here
