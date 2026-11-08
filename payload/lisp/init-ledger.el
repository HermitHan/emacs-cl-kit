;;; init-ledger.el --- Support for the ledger CLI accounting tool -*- lexical-binding: t -*-
;;; Commentary:
;; Ledger 记账文本的编辑、检查器和账本环境集成；实际查询/检查需要 ledger 程序。
;;; Code:

(when (maybe-require-package 'ledger-mode)
  ;; 两个相关库都加载后注册 Ledger 检查器，不会在配置加载时运行账本命令。
  (when (maybe-require-package 'flycheck-ledger)
    (with-eval-after-load 'flycheck
      (with-eval-after-load 'ledger-mode
        (require 'flycheck-ledger))))

  ;; 保留普通文本输入习惯：RET 只换行，C-o 插入换行但不移动光标。
  (with-eval-after-load 'ledger-mode
    (define-key ledger-mode-map (kbd "RET") 'newline)
    (define-key ledger-mode-map (kbd "C-o") 'open-line))

  ;; 不额外高亮当前交易，不强制 ISO 日期，也不在模式启动时检查 Ledger 版本。
  (setq ledger-highlight-xact-under-point nil
        ledger-use-iso-dates nil
        ledger-mode-should-check-version nil)

  ;; macOS 图形 Emacs 从 shell 继承 LEDGER_FILE；这一步仅在 Ledger 模式库加载后执行。
  (with-eval-after-load 'ledger-mode
    (when (memq window-system '(mac ns))
      (exec-path-from-shell-copy-env "LEDGER_FILE")))

  ;; 让注释/文本中的 URL 可被识别和访问。
  (add-hook 'ledger-mode-hook 'goto-address-prog-mode))

(provide 'init-ledger)
;;; init-ledger.el ends here
