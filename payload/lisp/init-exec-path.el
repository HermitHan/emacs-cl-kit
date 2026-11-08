;;; init-exec-path.el --- Set up exec-path to help Emacs find programs  -*- lexical-binding: t -*-
;;; Commentary:
;; 让图形界面或 daemon 启动的 Emacs 获取 shell 中的 PATH 和必要环境变量。
;; 这有助于找到 SBCL、Git 等外部程序，不修改它们的安装位置。

;;; Code:

;; 确保环境导入工具可用；下面声明还需要导入的 SSH、语言编码和 Nix 变量。
(require-package 'exec-path-from-shell)

(with-eval-after-load 'exec-path-from-shell
  (dolist (var '("SSH_AUTH_SOCK" "SSH_AGENT_PID" "GPG_AGENT_INFO" "LANG" "LC_CTYPE" "NIX_SSL_CERT_FILE" "NIX_PATH"))
    (add-to-list 'exec-path-from-shell-variables var)))


;; 只在列出的图形后端或非 Windows 的 daemon 中导入；普通终端通常已继承 shell 环境。
;; 初始化会启动 shell 读取环境，因此 shell 配置应避免非交互启动时卡住。
(when (or (memq window-system '(mac ns x pgtk))
          (unless (memq system-type '(ms-dos windows-nt))
            (daemonp)))
  (exec-path-from-shell-initialize))

(provide 'init-exec-path)
;;; init-exec-path.el ends here
