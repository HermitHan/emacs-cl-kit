;;; init-git.el --- Git SCM support -*- lexical-binding: t -*-
;;; Commentary:

;; See also init-github.el.

;; 配置 Git/Magit 界面、文件历史和少量 git-svn 辅助命令。
;; require-package 只确保包存在；Git 操作在调用具体命令时发生。

;;; Code:

;; TODO: link commits from vc-log to magit-show-commit
;; TODO: smerge-mode
;; 准备逐行溯源、Git 配置文件模式和历史浏览；C-x v t 切换文件历史时间线。
(require-package 'git-blamed)
(require-package 'git-modes)
(when (maybe-require-package 'git-timemachine)
  (global-set-key (kbd "C-x v t") 'git-timemachine-toggle))

;; 提供 M-x git-link，把当前代码位置转换为托管平台链接。
(require-package 'git-link)

;; C-x g 或 M-F12 打开 Magit 状态；C-x M-g 打开总菜单。
;; 差异块细化到词级；C-u M-F12 的项目选择取决于 magit-repository-directories。
(when (maybe-require-package 'magit)
  (setq-default magit-diff-refine-hunk t)

  ;; Hint: customize `magit-repository-directories' so that you can use C-u M-F12 to
  ;; quickly open magit on any one of your projects.
  (global-set-key [(meta f12)] 'magit-status)
  (global-set-key (kbd "C-x g") 'magit-status)
  (global-set-key (kbd "C-x M-g") 'magit-dispatch)

  ;; C-x v l：Git 文件使用 Magit 历史；其他后端保留内置 VC 历史。
  ;; 带前缀时调用 Magit 的交互日志菜单。
  (defun sanityinc/magit-or-vc-log-file (&optional prompt)
    (interactive "P")
    (if (and (buffer-file-name)
             (eq 'Git (vc-backend (buffer-file-name))))
        (if prompt
            (call-interactively #'magit-log)
          (magit-log-buffer-file t))
      (vc-print-log)))

  (with-eval-after-load 'vc
    (define-key vc-prefix-map (kbd "l") 'sanityinc/magit-or-vc-log-file)))


;; Magit 内 C-M-上移到上级 section；局部绑定只影响 Magit 界面。
(with-eval-after-load 'magit
  (define-key magit-status-mode-map (kbd "C-M-<up>") 'magit-section-up))

;; 准备 TODO 列表扩展，但这里不主动启用它的模式。
(maybe-require-package 'magit-todos)

;; Magit 状态界面临时铺满当前 frame，退出时恢复之前分屏。
(require-package 'fullframe)
(with-eval-after-load 'magit
  (fullframe magit-status magit-mode-quit-window))

;; 编写提交信息时让网址可点击；不自动提交或推送。
(with-eval-after-load 'git-commit
  (add-hook 'git-commit-setup-hook #'goto-address-mode))


;; macOS 中去掉 Magit 局部 M-h，让全局隐藏应用快捷键仍可使用。
(when *is-a-mac*
  (with-eval-after-load 'magit
    (add-hook 'magit-mode-hook (lambda () (local-unset-key [(meta h)])))))



;; Convenient binding for vc-git-grep
;; C-x v f 在 Git 跟踪的文件中搜索，使用内置 vc-git-grep。
(with-eval-after-load 'vc
  (define-key vc-prefix-map (kbd "f") 'vc-git-grep))



;;; git-svn support

;; (when (maybe-require-package 'magit-svn)
;;   (require-package 'magit-svn)
;;   (autoload 'magit-svn-enabled "magit-svn")
;;   (defun sanityinc/maybe-enable-magit-svn-mode ()
;;     (when (magit-svn-enabled)
;;       (magit-svn-mode)))
;;   (add-hook 'magit-status-mode-hook #'sanityinc/maybe-enable-magit-svn-mode))

;; 识别 git-svn 输出中的文件路径，使编译输出窗口可以跳转到相关文件。
;; 上面的 magit-svn 集成仍是注释状态；下面保留手动 git svn 命令入口。
(with-eval-after-load 'compile
  (dolist (defn (list '(git-svn-updated "^\t[A-Z]\t\\(.*\\)$" 1 nil nil 0 1)
                      '(git-svn-needs-update "^\\(.*\\): needs update$" 1 nil nil 2 1)))
    (add-to-list 'compilation-error-regexp-alist-alist defn)
    (add-to-list 'compilation-error-regexp-alist (car defn))))

;; 首次请求命令候选时运行 git svn help，并缓存解析结果；不是启动时访问仓库。
(defvar git-svn--available-commands nil "Cached list of git svn subcommands")
(defun git-svn--available-commands ()
  (or git-svn--available-commands
      (setq git-svn--available-commands
            (sanityinc/string-all-matches
             "^  \\([a-z\\-]+\\) +"
             (shell-command-to-string "git svn help") 1))))

(autoload 'vc-git-root "vc-git")

;; M-x git-svn 选择目录及子命令，在对应 Git 根目录的编译窗口执行。
(defun git-svn (dir command)
  "Run a git svn subcommand in DIR."
  (interactive (list (read-directory-name "Directory: ")
                     (completing-read "git-svn command: " (git-svn--available-commands) nil t nil nil (git-svn--available-commands))))
  (let* ((default-directory (vc-git-root dir))
         (compilation-buffer-name-function (lambda (major-mode-name) "*git-svn*")))
    (compile (concat "git svn " command))))


(provide 'init-git)
;;; init-git.el ends here
