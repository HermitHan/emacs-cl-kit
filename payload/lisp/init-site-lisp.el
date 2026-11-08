;;; init-site-lisp.el --- Support elisp manually installed in the site-lisp dir -*- lexical-binding: t -*-
;;; Commentary:
;; 支持放在 site-lisp 中的手工管理 Lisp 库；与 ELPA 管理的包目录分开。

;;; Code:

;;; Set load path

(require 'cl-lib)

;; 将直接下一级的非隐藏子目录放入 load-path，不递归扫描整个目录树。
(defun sanityinc/add-subdirs-to-load-path (parent-dir)
  "Add every non-hidden subdir of PARENT-DIR to `load-path'."
  (let ((default-directory parent-dir))
    (setq load-path
          (append
           (cl-remove-if-not
            #'file-directory-p
            (directory-files (expand-file-name parent-dir) t "^[^\\.]"))
           load-path))))

;; Add both site-lisp and its immediate subdirs to `load-path'
;; 加入 site-lisp 本身及其直接子目录；这里只提供查找路径，不逐个加载文件。
(let ((site-lisp-dir (expand-file-name "site-lisp/" user-emacs-directory)))
  (push site-lisp-dir load-path)
  (sanityinc/add-subdirs-to-load-path site-lisp-dir))

;;; Utilities for grabbing upstream libs

;; 下面是旧的手动下载辅助函数，定义本身不会联网；当前配置没有调用它们。
;; 本轮保留接口，避免把个人临时用法误判为无用代码。
(defun site-lisp-dir-for (name)
  (expand-file-name (format "site-lisp/%s" name) user-emacs-directory))

(defun site-lisp-library-el-path (name)
  (expand-file-name (format "%s.el" name) (site-lisp-dir-for name)))

;; 显式调用时才从给定 URL 下载到对应子目录；url-copy-file 的覆盖选项沿用原值。
(defun download-site-lisp-module (name url)
  (let ((dir (site-lisp-dir-for name)))
    (message "Downloading %s from %s" name url)
    (unless (file-directory-p dir)
      (make-directory dir t))
    (add-to-list 'load-path dir)
    (let ((el-file (site-lisp-library-el-path name)))
      (url-copy-file url el-file t nil)
      el-file)))

;; 仅找不到对应 site-lisp 库时下载并字节编译；不负责版本比较或更新检查。
(defun ensure-lib-from-url (name url)
  (unless (site-lisp-library-loadable-p name)
    (byte-compile-file (download-site-lisp-module name url))))

;; 检查 locate-library 找到的库是否位于指定手工目录，避免与 ELPA 同名库混淆。
(defun site-lisp-library-loadable-p (name)
  "Return whether or not the library `name' can be loaded from a
source file under ~/.emacs.d/site-lisp/name/"
  (let ((f (locate-library (symbol-name name))))
    (and f (string-prefix-p (file-name-as-directory (site-lisp-dir-for name)) f))))


(provide 'init-site-lisp)
;;; init-site-lisp.el ends here
