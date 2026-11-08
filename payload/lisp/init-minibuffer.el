;;; init-minibuffer.el --- Config for minibuffer completion       -*- lexical-binding: t; -*-
;;; Commentary:
;; 配置底部 minibuffer 的候选选择、搜索与动作菜单。
;; Vertico 管候选列表，Consult 提供命令，Embark 对当前候选执行操作。

;;; Code:


;; 启动完成后启用 Vertico；安装检查成功不等于立即打开候选界面。
(when (maybe-require-package 'vertico)
  (add-hook 'after-init-hook 'vertico-mode)

  ;; 候选列表中 C-c C-o 导出列表，C-c C-c 对当前候选选择动作。
  (when (maybe-require-package 'embark)
    (with-eval-after-load 'vertico
      (define-key vertico-map (kbd "C-c C-o") 'embark-export)
      (define-key vertico-map (kbd "C-c C-c") 'embark-act)))

  (when (maybe-require-package 'consult)
    ;; 这些搜索/历史命令默认不自动预览，按 M-P 才请求预览，减少浏览候选时的跳动。
    (defmacro sanityinc/no-consult-preview (&rest cmds)
      `(with-eval-after-load 'consult
         (consult-customize ,@cmds :preview-key "M-P")))

    (sanityinc/no-consult-preview
     consult-ripgrep
     consult-git-grep consult-grep
     consult-bookmark consult-recent-file consult-xref
     consult--source-recent-file consult--source-project-recent-file consult--source-bookmark)

    ;; Consult 查询项目根目录时委托 Projectile；传入参数表示是否允许提示，不是目录名。
    (when (maybe-require-package 'projectile)
      (setq-default consult-project-function
                    ;; Consult passes MAY-PROMPT, not a directory.
                    (lambda (_may-prompt) (projectile-project-root))))

    ;; rg 存在时配置 Affe 模糊全文搜索；M-? 以当前符号作为初始搜索词。
    ;; 它可能覆盖 init-grep 中的同一键，加载顺序决定最终入口，本轮保持顺序。
    (when (and (executable-find "rg") (maybe-require-package 'affe))
      (defun sanityinc/affe-grep-at-point (&optional dir initial)
        (interactive (list prefix-arg (when-let ((s (symbol-at-point)))
                                        (symbol-name s))))
        (affe-grep dir initial))
      (global-set-key (kbd "M-?") 'sanityinc/affe-grep-at-point)
      (sanityinc/no-consult-preview sanityinc/affe-grep-at-point)
      (with-eval-after-load 'affe (sanityinc/no-consult-preview affe-grep)))

    ;; 保留原切 buffer / 跳行快捷键，通过 remap 换成带候选列表的 Consult 版本。
    (global-set-key [remap switch-to-buffer] 'consult-buffer)
    (global-set-key [remap switch-to-buffer-other-window] 'consult-buffer-other-window)
    (global-set-key [remap switch-to-buffer-other-frame] 'consult-buffer-other-frame)
    (global-set-key [remap goto-line] 'consult-goto-line)



    ;; Embark 真正加载后接入 Consult，让收集结果列表支持预览。
    (when (maybe-require-package 'embark-consult)
      (with-eval-after-load 'embark
        (require 'embark-consult)
        (add-hook 'embark-collect-mode-hook 'embark-consult-preview-minor-mode)))

    ;; 保留可选的 Flycheck 结果浏览器；它读取 Flycheck 的诊断，不直接读取 Flymake。
    ;; 当前以 Flymake 为主时可用已有的 M-x consult-flymake；这里不改检查后端。
    (maybe-require-package 'consult-flycheck)))

;; 候选旁增加文件属性、命令说明等注释，方便理解候选；不改变候选本身。
(when (maybe-require-package 'marginalia)
  (add-hook 'after-init-hook 'marginalia-mode))


(provide 'init-minibuffer)
;;; init-minibuffer.el ends here
