;;; init-darcs.el --- Support for the Darcs DVCS -*- lexical-binding: t -*-
;;; Commentary:
;; 将 Darcs 仓库接入 Emacs 内置 VC 界面；实际仓库操作需要 darcs 可执行程序。
;; 这里保留该版本控制模块，没有删除其他语言/项目可能使用的支持。
;;; Code:

;; 确保 VC 后端包可用；后续 autoload 在文件 hook 首次调用时才加载具体实现。
(require-package 'vc-darcs)


;; 登记 DARCS 后端并在打开文件时识别仓库。find-file-hook 是现行名称，
;; 旧 find-file-hooks 只是过时别名。原 darcsum 选项没有已安装的消费者，因此移除。
;; TODO: include this in the vc-darcs ELPA package
(add-to-list 'vc-handled-backends 'DARCS)
(autoload 'vc-darcs-find-file-hook "vc-darcs")
(add-hook 'find-file-hook 'vc-darcs-find-file-hook)


(provide 'init-darcs)
;;; init-darcs.el ends here
