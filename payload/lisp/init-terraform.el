;;; init-terraform.el --- Work with Terraform configurations -*- lexical-binding: t -*-
;;; Commentary:
;; Terraform 文件编辑和格式化；命令需要 PATH 中存在 terraform。
;; 格式化通过标准输入执行 terraform fmt -，不会执行 plan/apply 或修改云资源。
;;; Code:

;;; Terraform

(when (maybe-require-package 'terraform-mode)
  ;; TODO: find/write a replacement for company-terraform
  ;; 模式库加载后用 reformatter 提供 terraform-format-buffer / region / on-save-mode。
  ;; 这里只定义命令，不自动启用保存格式化；company-terraform 的替代补全仍未实现。
  (with-eval-after-load 'terraform-mode
    ;; I find formatters based on "reformatter" to be more reliable
    ;; so I redefine `terraform-format-on-save-mode' here.
    (when (maybe-require-package 'reformatter)
      (reformatter-define terraform-format
        :program "terraform" :args '("fmt" "-")))))

(provide 'init-terraform)
;;; init-terraform.el ends here
