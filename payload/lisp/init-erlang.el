;;; init-erlang.el --- Support for the Erlang language -*- lexical-binding: t -*-
;;; Commentary:
;; 保留 Erlang 编辑支持；可选 erlang 包安装成功后加载其启动入口。
;; erlang-start 负责 Erlang 模式的识别/自动加载规则，实际运行 Erlang 仍需外部环境。
;;; Code:

(when (maybe-require-package 'erlang)
  (require 'erlang-start))


(provide 'init-erlang)
;;; init-erlang.el ends here
