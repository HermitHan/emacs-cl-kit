;;; init-j.el --- Basic support for programming in J -*- lexical-binding: t -*-
;;; Commentary:
;; J 语言源码与交互控制台支持；J 的 jconsole 与 Java 的同名工具不是同一个程序。
;; 若安装位置不在 PATH，可将 j-console-cmd 设置为 J 解释器的完整路径。
;;; Code:

(require-package 'j-mode)

(setq-default j-console-cmd "jconsole")

;; 启动会话之前检查程序路径，在 macOS 上排除 /usr/bin/jconsole 的 Java 工具。
;; 此检查只在启动 J 控制台时触发，不在加载配置时启动解释器。
(defun sanityinc/j-console-check-command (&rest _args)
  "启动前确认 J 解释器存在，避免误启动 macOS 的 Java jconsole。"
  (let ((program (executable-find j-console-cmd)))
    (unless (and program
                 (not (and (eq system-type 'darwin)
                           (equal (file-truename program)
                                  (file-truename "/usr/bin/jconsole")))))
      (user-error "请将 j-console-cmd 设置为 J 语言解释器的路径；当前值 %S 不可用"
                  j-console-cmd))))

(with-eval-after-load 'j-console
  (advice-add 'j-console-create-session :before #'sanityinc/j-console-check-command))
;; J 控制台关闭自动配对输入，保留原有交互输入习惯；其他语言的配对设置不受影响。
(add-hook 'inferior-j-mode-hook (lambda () (electric-pair-mode -1)))


(provide 'init-j)
;;; init-j.el ends here
