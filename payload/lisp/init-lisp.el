;;; init-lisp.el --- Emacs lisp settings, and common config for other lisps -*- lexical-binding: t -*-
;;; Commentary:
;; 本文件有两个职责：提供 Emacs Lisp 专属工具，以及各类 Lisp 共用的编辑 hook。
;; Common Lisp 的实现选择见 init-common-lisp.el，连接/REPL 见 init-slime.el；
;; 不要把下面的 eval-*（求值 Emacs Lisp）当成 SLIME 的 Common Lisp 求值命令。
;; 学习时可用 C-h f 查看函数、C-h v 查看变量，C-h k 后按快捷键查看实际绑定。
;; with-eval-after-load 表示等目标库加载后再设置，add-hook 表示进入对应模式时执行。
;; require-package/maybe-require-package 是本配置的包安装助手，后者允许可选包失败。

;;; Code:


;; 退出 Emacs Lisp 调试器时关闭调试 buffer；不影响外部 SBCL 的调试器。
;; elisp-slime-nav 在 ELisp/IELM 中提供类似 SLIME 的定义与文档导航。
(setq-default debugger-bury-or-kill 'kill)

(require-package 'elisp-slime-nav)
(dolist (hook '(emacs-lisp-mode-hook ielm-mode-hook))
  (add-hook hook 'turn-on-elisp-slime-nav-mode))
(add-hook 'emacs-lisp-mode-hook (lambda () (setq mode-name "ELisp")))

;; *scratch* 初始提示只影响新会话中的欢迎文字。
(setq-default initial-scratch-message
              (concat ";; Happy hacking, " user-login-name " - Emacs ♥ you!\n\n"))


;; M-x sanityinc/headerise-elisp：给当前 .el 文件添加标准文件头/尾。
;; 这是手动模板助手，会插入文本；不会自动判断文件是否已有相同模板。
(defun sanityinc/headerise-elisp ()
  "Add minimal header and footer to an elisp buffer in order to placate flycheck."
  (interactive)
  (let ((fname (if (buffer-file-name)
                   (file-name-nondirectory (buffer-file-name))
                 (error "This buffer is not visiting a file"))))
    (save-excursion
      (goto-char (point-min))
      (insert ";;; " fname " --- Insert description here -*- lexical-binding: t -*-\n"
              ";;; Commentary:\n"
              ";;; Code:\n\n")
      (goto-char (point-max))
      (insert ";;; " fname " ends here\n"))))


;; Make C-x C-e run 'eval-region if the region is active

;; ELisp 中 C-x C-e：有活动选区就求值选区，否则求值光标前的表达式。
;; C-c C-e 在 minibuffer 输入表达式并漂亮打印结果；不要用于运行 Common Lisp。
;; ipretty 进一步格式化交互求值结果，方便阅读嵌套列表。
(defun sanityinc/eval-last-sexp-or-region (prefix)
  "Eval region from BEG to END if active, otherwise the last sexp."
  (interactive "P")
  (if (and (mark) (use-region-p))
      (eval-region (min (point) (mark)) (max (point) (mark)))
    (pp-eval-last-sexp prefix)))

(global-set-key [remap eval-expression] 'pp-eval-expression)

(with-eval-after-load 'lisp-mode
  (define-key emacs-lisp-mode-map (kbd "C-x C-e") 'sanityinc/eval-last-sexp-or-region)
  (define-key emacs-lisp-mode-map (kbd "C-c C-e") 'pp-eval-expression))

(when (maybe-require-package 'ipretty)
  (add-hook 'after-init-hook 'ipretty-mode))


;; 在漂亮打印的结果窗口启用 view-mode，按 q 即可关闭窗口。
;; advice-add 的 :after 表示在原函数成功返回后补充动作，不替换其计算。
(defun sanityinc/make-read-only (_expression out-buffer-name &rest _)
  "Enable `view-mode' in the output buffer - if any - so it can be closed with `\"q\"."
  (when (get-buffer out-buffer-name)
    (with-current-buffer out-buffer-name
      (view-mode 1))))
(advice-add 'pp-display-expression :after 'sanityinc/make-read-only)



;; ELisp 中 C-c C-l：加载当前文件；无文件的临时 buffer 则直接 eval-buffer。
;; 加载前允许保存其他修改过的 ELisp buffer，并临时把当前目录加入 load-path。
;; 这会执行配置代码；只在理解所选内容后手动调用。
(defun sanityinc/load-this-file ()
  "Load the current file or buffer.
The current directory is temporarily added to `load-path'.  When
there is no current file, eval the current buffer."
  (interactive)
  (let ((load-path (cons default-directory load-path))
        (file (buffer-file-name)))
    (if file
        (progn
          (save-some-buffers nil (apply-partially 'derived-mode-p 'emacs-lisp-mode))
          (load-file (buffer-file-name))
          (message "Loaded %s" file))
      (eval-buffer)
      (message "Evaluated %s" (current-buffer)))))

(with-eval-after-load 'lisp-mode
  (define-key emacs-lisp-mode-map (kbd "C-c C-l") 'sanityinc/load-this-file))



;; 打开 Emacs 自带的压缩 .el.gz 源码时默认只读，适合查实现而不误改系统文件。
(defun sanityinc/maybe-set-bundled-elisp-readonly ()
  "If this elisp appears to be part of Emacs, then disallow editing."
  (when (and (buffer-file-name)
             (string-match-p "\\.el\\.gz\\'" (buffer-file-name)))
    (setq buffer-read-only t)
    (view-mode 1)))

(add-hook 'emacs-lisp-mode-hook 'sanityinc/maybe-set-bundled-elisp-readonly)


;; Use C-c C-z to toggle between elisp files and an ielm session
;; I might generalise this to ruby etc., or even just adopt the repl-toggle package.

;; ELisp/IELM 的 C-c C-z 在源码和交互解释器之间往返，记录来自哪个 buffer。
;; defvar-local 的值属于各 buffer；本段不接管 SLIME 的 CL REPL。
(defvar-local sanityinc/repl-original-buffer nil
  "Buffer from which we jumped to this REPL.")

(defvar sanityinc/repl-switch-function 'switch-to-buffer-other-window)

(defun sanityinc/switch-to-ielm ()
  (interactive)
  (let ((orig-buffer (current-buffer)))
    (if (get-buffer "*ielm*")
        (funcall sanityinc/repl-switch-function "*ielm*")
      (ielm))
    (setq sanityinc/repl-original-buffer orig-buffer)))

(defun sanityinc/repl-switch-back ()
  "Switch back to the buffer from which we reached this REPL."
  (interactive)
  (if sanityinc/repl-original-buffer
      (funcall sanityinc/repl-switch-function sanityinc/repl-original-buffer)
    (error "No original buffer")))

(with-eval-after-load 'elisp-mode
  (define-key emacs-lisp-mode-map (kbd "C-c C-z") 'sanityinc/switch-to-ielm))
(with-eval-after-load 'ielm
  (define-key ielm-map (kbd "C-c C-z") 'sanityinc/repl-switch-back))


;; Hippie-expand

;; 给 ELisp 的 hippie-expand 增加 Lisp 符号补全候选。
;; 这只是候选来源设置，不另行占用 TAB，也不替换 SLIME 的补全后端。
(defun set-up-hippie-expand-for-elisp ()
  "Locally set `hippie-expand' completion functions for use with Emacs Lisp."
  (make-local-variable 'hippie-expand-try-functions-list)
  (add-to-list 'hippie-expand-try-functions-list 'try-complete-lisp-symbol t)
  (add-to-list 'hippie-expand-try-functions-list 'try-complete-lisp-symbol-partially t))



;; Automatic byte compilation

;; auto-compile 在保存/加载 ELisp 时维护已有编译产物，减少源码与 .elc 不一致。
;; delete-stray-dest=nil 保留既有处理策略；下面 load-prefer-newer 则保证源码较新时
;; 优先加载 .el。这两项分别控制编译维护与加载选择，并非同一设置重复两次。
(when (maybe-require-package 'auto-compile)
  (setq auto-compile-delete-stray-dest nil)
  (add-hook 'after-init-hook 'auto-compile-on-save-mode)
  (add-hook 'after-init-hook 'auto-compile-on-load-mode))


;; Load .el if newer than corresponding .elc

(setq load-prefer-newer t)



;; 保留可用的 *scratch* 草稿 buffer；属于 Emacs Lisp 交互环境，不是 CL image。
(require-package 'immortal-scratch)
(add-hook 'after-init-hook 'immortal-scratch-mode)


;;; Support byte-compilation in a sub-process, as
;;; required by highlight-cl

;; M-x sanityinc/byte-compile-file-batch：在独立 emacs -Q 子进程编译指定 .el。
;; 与当前会话隔离，可查看编译警告；这里不执行 SBCL 编译。
(defun sanityinc/byte-compile-file-batch (filename)
  "Byte-compile FILENAME in batch mode, ie. a clean sub-process."
  (interactive "fFile to byte-compile in batch mode: ")
  (let ((emacs (car command-line-args)))
    (compile
     (concat
      emacs " "
      (mapconcat
       'shell-quote-argument
       (list "-Q" "-batch" "-f" "batch-byte-compile" filename)
       " ")))))



;; Enable desired features for all lisp modes

;; 各 Lisp 模式共用：Paredit 维护括号结构，保存后 check-parens 检查括号平衡，
;; aggressive-indent 在可用时自动重排缩进。after-save 检查发生在保存之后，
;; 它能提醒语法结构问题，但不等价于阻止有问题的文件写入磁盘。
(defun sanityinc/enable-check-parens-on-save ()
  "Run `check-parens' when the current buffer is saved."
  (add-hook 'after-save-hook #'check-parens nil t))

(defvar sanityinc/lispy-modes-hook
  '(enable-paredit-mode
    sanityinc/enable-check-parens-on-save)
  "Hook run in all Lisp modes.")


(when (maybe-require-package 'aggressive-indent)
  (add-to-list 'sanityinc/lispy-modes-hook 'aggressive-indent-mode))

(defun sanityinc/lisp-setup ()
  "Enable features useful in any Lisp mode."
  (run-hooks 'sanityinc/lispy-modes-hook))

;; 公共 Lisp hook 与 ELisp 专属 hook 分开：CL 不应使用 ELisp 的符号补全规则。
(defun sanityinc/emacs-lisp-setup ()
  "Enable features useful when working with elisp."
  (set-up-hippie-expand-for-elisp))

(defconst sanityinc/elispy-modes
  '(emacs-lisp-mode ielm-mode)
  "Major modes relating to elisp.")

(defconst sanityinc/lispy-modes
  (append sanityinc/elispy-modes
          '(lisp-mode inferior-lisp-mode lisp-interaction-mode))
  "All lispy major modes.")

(require 'derived)

(dolist (hook (mapcar #'derived-mode-hook-name sanityinc/lispy-modes))
  (add-hook hook 'sanityinc/lisp-setup))

(dolist (hook (mapcar #'derived-mode-hook-name sanityinc/elispy-modes))
  (add-hook hook 'sanityinc/emacs-lisp-setup))

;; M-: 等 minibuffer 求值入口显示 Eldoc 参数提示；另登记两个 ELisp 文件名规则。
(when (boundp 'eval-expression-minibuffer-setup-hook)
  (add-hook 'eval-expression-minibuffer-setup-hook #'eldoc-mode))

(add-to-list 'auto-mode-alist '("\\.emacs-project\\'" . emacs-lisp-mode))
(add-to-list 'auto-mode-alist '("archive-contents\\'" . emacs-lisp-mode))



;; Delete .elc files when reverting the .el from VC or magit

;; When .el files are open, we can intercept when they are modified
;; by VC or magit in order to remove .elc files that are likely to
;; be out of sync.

;; This is handy while actively working on elisp files, though
;; obviously it doesn't ensure that unopened files will also have
;; their .elc counterparts removed - VC hooks would be necessary for
;; that.

;; 版本控制刷新防护仅针对「已打开的 .el buffer」：刷新期间临时绑定标志，
;; revert-buffer 完成后删除其旧 .elc，防止以后误用旧编译代码。
;; 普通手工刷新、Common Lisp 的 .lisp/.fasl 都不在此删除范围内。
;; 该机制不扫描未打开文件；仍需上面的 load-prefer-newer/auto-compile 配合。
(defvar sanityinc/vc-reverting nil
  "Whether or not VC or Magit is currently reverting buffers.")

(defun sanityinc/maybe-remove-elc (&rest _)
  "If reverting from VC, delete any .elc file that will now be out of sync."
  (when sanityinc/vc-reverting
    (when (and (eq 'emacs-lisp-mode major-mode)
               buffer-file-name
               (string= "el" (file-name-extension buffer-file-name)))
      (let ((elc (concat buffer-file-name "c")))
        (when (file-exists-p elc)
          (message "Removing out-of-sync elc file %s" (file-name-nondirectory elc))
          (delete-file elc))))))
(advice-add 'revert-buffer :after 'sanityinc/maybe-remove-elc)

(defun sanityinc/reverting (orig &rest args)
  (let ((sanityinc/vc-reverting t))
    (apply orig args)))
;; 当前 Magit 从 magit-auto-revert-buffers 进入刷新；旧入口已移除。
;; 先撤下旧挂钩，便于热加载从旧配置迁移；同名 advice-add 重复执行不会堆叠。
(advice-remove 'magit-revert-buffers 'sanityinc/reverting)
(advice-add 'magit-auto-revert-buffers :around 'sanityinc/reverting)
(advice-add 'vc-revert-buffer-internal :around 'sanityinc/reverting)



;; ELisp 中 C-c x：交互展开光标处宏，帮助学习宏展开结果。
;; Common Lisp 的宏展开由 SLIME 提供，不在这里绑定。
(require-package 'macrostep)

(with-eval-after-load 'lisp-mode
  (define-key emacs-lisp-mode-map (kbd "C-c x") 'macrostep-expand))



;; A quick way to jump to the definition of a function given its key binding
;; C-h K（大写 K）：输入某个快捷键，直接查看其命令定义，便于追踪配置。
(global-set-key (kbd "C-h K") 'find-function-on-key)



;; Extras for theme editing
;; 主题文件和帮助 buffer 中把颜色名/色值显示成颜色，便于编辑主题。
;; diminish 只简化 mode line 上的模式名称，不禁用实际功能。
(when (maybe-require-package 'rainbow-mode)
  (defun sanityinc/enable-rainbow-mode-if-theme ()
    (when (and (buffer-file-name) (string-match-p "\\(color-theme-\\|-theme\\.el\\)" (buffer-file-name)))
      (rainbow-mode)))
  (add-hook 'emacs-lisp-mode-hook 'sanityinc/enable-rainbow-mode-if-theme)
  (add-hook 'help-mode-hook 'rainbow-mode)
  (with-eval-after-load 'rainbow-mode
    (diminish 'rainbow-mode)))



;; 高亮 ELisp 中被 quote 的符号；package-lint-flymake 检查 ELisp 包的约定，
;; 这些都是 Emacs Lisp 专属辅助，不改变 CL 的检查器配置。
(when (maybe-require-package 'highlight-quoted)
  (add-hook 'emacs-lisp-mode-hook 'highlight-quoted-mode))


(when (maybe-require-package 'package-lint-flymake)
  (add-hook 'emacs-lisp-mode-hook #'package-lint-flymake-setup))



;; ERT
;; ERT 是 Emacs Lisp 的测试框架；测试结果窗口按 g 重新运行当前全部测试。
(with-eval-after-load 'ert
  (define-key ert-results-mode-map (kbd "g") 'ert-results-rerun-all-tests))


;; 可选工具：cl-libify 辅助把旧 cl 调用迁移到 cl-lib 命名，不在启动时自动改代码。
(maybe-require-package 'cl-libify)


;; 可选正则检查工具：这里仅确保 flycheck-relint 已安装，尚未自动注册检查器。
;; 它不会因为安装便接入当前 Flymake；本次保留这个手动配置的备选项。
(maybe-require-package 'flycheck-relint)



;; Cask 文件编辑支持，供维护 ELisp 项目的依赖描述时使用。
(maybe-require-package 'cask-mode)

(provide 'init-lisp)
;;; init-lisp.el ends here
