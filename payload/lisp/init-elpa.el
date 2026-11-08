;;; init-elpa.el --- Settings and helpers for package.el -*- lexical-binding: t -*-
;;; Commentary:
;; 统一管理扩展包来源、安装检查和已选包登记。
;; require-package 表示确保安装；require 才表示加载 Lisp 库，两者用途不同。

;;; Code:

;; 加载内置包管理和 cl-lib 辅助函数，供后面的版本比较、集合与表格操作使用。
(require 'package)
(require 'cl-lib)


;;; Install into separate package dirs for each Emacs version, to prevent bytecode incompatibility
;; 按 Emacs 主次版本隔离 ELPA 目录，避免混用字节码。
;; 升级 Emacs 会使用另一目录；此设置不会删除旧版本包。
(setq package-user-dir
      (expand-file-name (format "elpa-%s.%s" emacs-major-version emacs-minor-version)
                        user-emacs-directory))



;;; Standard package repositories

;; 软件源统一在包初始化之前设置；沿用清华镜像并使用 HTTPS。
(setq package-archives
      '(("gnu" . "https://mirrors.tuna.tsinghua.edu.cn/elpa/gnu/")
        ("melpa" . "https://mirrors.tuna.tsinghua.edu.cn/elpa/melpa/")))



;; Work-around for https://debbugs.gnu.org/cgi/bugreport.cgi?bug=34341
;; 仅对旧版 Emacs/GnuTLS 组合调整 TLS 参数；当前 Emacs 30 不进入这条分支。
(when (and (version< emacs-version "26.3") (boundp 'libgnutls-version) (>= libgnutls-version 30604))
  (setq gnutls-algorithm-priority "NORMAL:-VERS-TLS1.3"))


;;; On-demand installation of packages

;; 已安装且版本满足要求时直接返回；缺包时才尝试安装，必要时刷新软件源目录。
;; NO-REFRESH 用于阻止重复刷新，以便缺包能明确报错；本轮保留原网络策略。
(defun require-package (package &optional min-version no-refresh)
  "Install given PACKAGE, optionally requiring MIN-VERSION.
If NO-REFRESH is non-nil, the available package lists will not be
re-downloaded in order to locate PACKAGE."
  (when (stringp min-version)
    (setq min-version (version-to-list min-version)))
  (or (package-installed-p package min-version)
      (let* ((known (cdr (assoc package package-archive-contents)))
             (best (car (sort known (lambda (a b)
                                      (version-list-<= (package-desc-version b)
                                                       (package-desc-version a)))))))
        (if (and best (version-list-<= min-version (package-desc-version best)))
            (package-install best)
          (if no-refresh
              (error "No version of %s >= %S is available" package min-version)
            (package-refresh-contents)
            (require-package package min-version t)))
        (package-installed-p package min-version))))

;; 可选包包装器：失败时输出消息并返回 nil，让相关功能块跳过。
;; 名称里的 require 沿用旧配置命名，实际仍是安装检查，不自动 require 库。
(defun maybe-require-package (package &optional min-version no-refresh)
  "Try to install PACKAGE, and return non-nil if successful.
In the event of failure, return nil and print a warning message.
Optionally require MIN-VERSION.  If NO-REFRESH is non-nil, the
available package lists will not be re-downloaded in order to
locate PACKAGE."
  (condition-case err
      (require-package package min-version no-refresh)
    (error
     (message "Couldn't install optional package `%s': %S" package err)
     nil)))


;;; Fire up package.el

;; 由本文件明确初始化 package.el，避免依赖默认启动加载时机。
(setq package-enable-at-startup nil)
(package-initialize)


;; package.el updates the saved version of package-selected-packages correctly only
;; after custom-file has been loaded, which is a bug. We work around this by adding
;; the required packages to package-selected-packages after startup is complete.

;; 记录配置声明需要的包，启动完成后与用户自己的 selected 列表取并集。
;; 这能防止 package-autoremove 把仍由配置使用的包误当成可移除依赖。
(defvar sanityinc/required-packages nil)

(defun sanityinc/note-selected-package (oldfun package &rest args)
  "If OLDFUN reports PACKAGE was successfully installed, note that fact.
The package name is noted by adding it to
`sanityinc/required-packages'.  This function is used as an
advice for `require-package', to which ARGS are passed."
  (let ((available (apply oldfun package args)))
    (prog1
        available
      (when available
        (add-to-list 'sanityinc/required-packages package)))))

;; 只在安装检查成功时登记包名；不删除用户手工选择的包。
(advice-add 'require-package :around 'sanityinc/note-selected-package)

;; 等 custom-file 加载后再保存已选包；并集成员没有增加时不重复写 custom.el。
;; 比较的是集合成员，不因为顺序不同或重复项而触发无意义保存。
(when (fboundp 'package--save-selected-packages)
  (require-package 'seq)
  (add-hook 'after-init-hook
            (lambda ()
              (unless (cl-subsetp sanityinc/required-packages package-selected-packages :test #'eq)
                (package--save-selected-packages
                 (seq-uniq (append sanityinc/required-packages package-selected-packages)))))))


;; M-x list-packages 临时占满当前 frame，退出后由 fullframe 恢复原窗口布局。
(require-package 'fullframe)
(fullframe list-packages quit-window)


;; 仅安装 GNU ELPA 密钥更新包时局部关闭签名检查；离开 let 后恢复原值。
(let ((package-check-signature nil))
  (require-package 'gnu-elpa-keyring-update))


;; 调整包列表的 Version/Archive 列宽，避免版本和源名称被截断。
;; 表格缓冲区加载时运行，不改变包版本和安装状态。
(defun sanityinc/set-tabulated-list-column-width (col-name width)
  "Set any column with name COL-NAME to the given WIDTH."
  (when (> width (length col-name))
    (cl-loop for column across tabulated-list-format
             when (string= col-name (car column))
             do (setf (elt column 1) width))))

(defun sanityinc/maybe-widen-package-menu-columns ()
  "Widen some columns of the package menu table to avoid truncation."
  (when (boundp 'tabulated-list-format)
    (sanityinc/set-tabulated-list-column-width "Version" 13)
    (let ((longest-archive-name (apply 'max (mapcar 'length (mapcar 'car package-archives)))))
      (sanityinc/set-tabulated-list-column-width "Archive" longest-archive-name))))

(add-hook 'package-menu-mode-hook 'sanityinc/maybe-widen-package-menu-columns)


(provide 'init-elpa)
;;; init-elpa.el ends here
