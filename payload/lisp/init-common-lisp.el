;;; init-common-lisp.el --- Common Lisp support -*- lexical-binding: t -*-
;;; Commentary:
;; Common Lisp 的实现选择与源码识别集中在这里；连接、补全、REPL 由 SLIME 管理。
;; M-x slime 启动默认实现；M-x han/slime-start 按名称选择本次要启动的实现。
;; 本模块只配置支持，不会仅因启动 Emacs 就执行你的 Common Lisp 项目。

;;; Code:

(require 'subr-x)

;; 只登记 Emacs 能直接运行的程序。交互 shell 的 alias、rlwrap、GUI Personal
;; 应用和项目构建用的 -build 都不是 SLIME 启动交互式 Lisp 的命令。
;; LispWorks 若不在 PATH，可在启动 Emacs 前把 LISPWORKS 设为控制台映像的完整路径。
(defun han/slime-available-backends ()
  "返回本机可用的 SLIME 实现表，每项含名称、启动命令和字符编码。
只检查文件是否可执行，不启动 Lisp。条目顺序也是首选实现缺失时的回退顺序。"
  (let ((lw (getenv "LISPWORKS")))
    (delq nil
          (mapcar
           (lambda (entry)
             (let ((program (nth 1 entry)))
               (when (executable-find program)
                 (list (car entry) (list program) :coding-system (nth 2 entry)))))
           `((sbcl "sbcl" utf-8-unix)
             (my-lispworks "my-lispworks" utf-8-unix)
             (lispworks ,(if (and lw (> (length lw) 0)) lw "lispworks") utf-8-unix)
             (han-lispworks "han-lispworks" utf-8-unix)
             (cmucl "lisp" iso-latin-1-unix)
             (ccl "ccl" utf-8-unix))))))

;; 安装器只保存一个实现名称，不把任何机器的路径、配置代码或凭据写到此文件。
(defun han/slime-installed-preference ()
  "读取安装器为本机保存的实现名；没有记录就返回 nil。只按普通文本读取。"
  (let ((file (expand-file-name "var/slime-default-lisp" user-emacs-directory)))
    (when (and (file-regular-p file) (file-readable-p file))
      (with-temp-buffer
        (insert-file-contents-literally file nil 0 80)
        (string-trim (buffer-string))))))

(defun han/slime-known-default (name)
  "如果 NAME 是本机已登记的实现名，返回对应的符号，否则返回 nil。"
  (and name (car (assq (intern-soft name) slime-lisp-implementations))))

;; 优先采用此次启动的环境变量，再考虑安装时保存的选择、SBCL、列表第一项。
;; 找不到的实现会跳过。修改默认后端不会改变任何已经建立的 SLIME 连接。
(setq slime-lisp-implementations (han/slime-available-backends)
      slime-default-lisp
      (or (han/slime-known-default (getenv "SLIME_DEFAULT_LISP"))
          (han/slime-known-default (han/slime-installed-preference))
          (han/slime-known-default "sbcl")
          (caar slime-lisp-implementations)))

(defun han/slime-start ()
  "从本机已登记的实现中选一个，交给 SLIME 启动；不修改日常默认值。"
  (interactive)
  (require 'slime)
  (unless slime-lisp-implementations
    (user-error "未发现可用的 Lisp；请检查 Emacs 的 exec-path 或 LispWorks 控制台路径"))
  ;; SLIME 的负前缀表示按实现名选择；不用占据已经映射为撤销的 M--。
  (let ((current-prefix-arg '-))
    (call-interactively #'slime)))

;; .cl 文件按 Common Lisp 编辑。进入 lisp-mode 时按需加载 SLIME，启用编译键及 CL 缩进。
;; 直接使用 SLIME 自带的 hook；手动选择 Lisp 模式的无文件 buffer 也会沿用这一设置。
(add-auto-mode 'lisp-mode "\\.cl\\'")
(autoload 'slime-lisp-mode-hook "slime")
(add-hook 'lisp-mode-hook #'slime-lisp-mode-hook)

;; 保留用户设置的本地 HyperSpec 镜像。SLIME 自带旧 HTTP 默认值时才换成官方 HTTPS。
(with-eval-after-load 'hyperspec
  (when (or (null common-lisp-hyperspec-root)
            (equal common-lisp-hyperspec-root "http://www.lispworks.com/reference/HyperSpec/"))
    (setq common-lisp-hyperspec-root "https://www.lispworks.com/documentation/HyperSpec/")))

;; C-c l 查光标处的标准符号，例如 MAPCAR；空白处调用会显示符号补全。
;; 查询使用 SLIME 自带的索引，无需 REPL 连接；本地镜像也可用于离线查阅。
(defun lispdoc ()
  "用 SLIME 的 Common Lisp HyperSpec 索引查阅标准符号。"
  (interactive)
  (require 'slime)
  (call-interactively #'slime-hyperspec-lookup))

(define-key lisp-mode-map (kbd "C-c l") 'lispdoc)


(provide 'init-common-lisp)
;;; init-common-lisp.el ends here
