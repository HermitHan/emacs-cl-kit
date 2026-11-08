;; 本目录内 Emacs Lisp 文件不自动字节编译，避免个人配置产生过时 .elc；不影响 CL 编译。
;; 可用 M-x describe-variable 查看对应变量；Emacs 可能在首次访问时询问是否信任目录变量。
;;; Directory Local Variables
;;; For more information see (info "(emacs) Directory Variables")

((emacs-lisp-mode
  (no-byte-compile . t)))
