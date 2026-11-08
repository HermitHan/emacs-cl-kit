;;; init.el --- Load the full configuration -*- lexical-binding: t -*-
;;; Commentary:

;; 配置入口与阅读地图：Emacs 启动时从上到下执行本文件，再加载 lisp/ 中的模块。
;; 建议先看本文件的分组，再用 C-x C-f 打开感兴趣的 init-*.el；每个模块有中文说明。
;; require 只加载尚未提供的 feature；require-package 是本配置的“确保包已安装”函数，
;; 不等于立即启动该包的服务。with-eval-after-load 则把设置延迟到对应包加载后执行。
;; setq 设置变量；add-hook 注册某个时机执行的函数；define-key 设置指定键图。
;; 这些写法和 Common Lisp 不完全相同：本目录是 Emacs Lisp，CL 项目仍由 SLIME 管理。
;; 学习时可用 M-x describe-function / describe-variable 查函数和变量的完整说明，
;; 用 M-x describe-key 后按实际按键，检查当前模式中最终执行的命令。
;; C- 表示 Ctrl，M- 表示 Meta（终端通常是 Option 或先按 Esc），SPC 表示空格。
;; 不要为试一个小改动重复求值整个 init.el：hook、主题和会话初始化有各自的执行时机。
;; 通常只求值选中的设置，或者保存后重启；涉及 SLIME/gptel 的改动应先保留备份。

;;; Code:

;; 调试开关：遇到错误时显示调用栈；平时保持注释，避免普通错误弹出调试窗口。
;;(setq debug-on-error t)

;;; 个人按键翻译：这是输入事件层的替换，优先于普通 global-set-key。
;; 下列设置保留个人肌肉记忆；阅读后面的模块键位时，也要考虑这层翻译。
;; 若想确认“物理按键”效果，使用 describe-key；仅看一个 mode-map 可能不够。

;;将中括号与圆括号替换, 方便编写程序
(define-key key-translation-map (kbd "(") (kbd "["))
(define-key key-translation-map (kbd ")") (kbd "]"))
(define-key key-translation-map (kbd "（") (kbd "【"))
(define-key key-translation-map (kbd "）") (kbd "】"))
(define-key key-translation-map (kbd "[") (kbd "("))
(define-key key-translation-map (kbd "]") (kbd ")"))
(define-key key-translation-map (kbd "【") (kbd "("))
(define-key key-translation-map (kbd "】") (kbd ")"))
(define-key key-translation-map (kbd "\“") (kbd "\""))
(define-key key-translation-map (kbd "\”") (kbd "\""))
(define-key key-translation-map (kbd "\‘") (kbd "\'"))
(define-key key-translation-map (kbd "\’") (kbd "\'"))
(define-key key-translation-map (kbd "《") (kbd "<"))
(define-key key-translation-map (kbd "》") (kbd ">"))
;; 物理 TAB 翻译为 M-/，交给已有补全命令；M-TAB、M-\ 和中文 M-、产生原 TAB。
;; 翻译结果不会再次递归翻译，因此原 TAB 仍可用于缩进。终端能否区分 M-TAB
;; 取决于发送的按键序列；这里同时保留多个原有入口。
;; Org 特例：进入 Org 后为该 buffer 建立翻译表，保留 TAB 的标题/列表折叠用途。
(define-key key-translation-map (kbd "M-\\") (kbd "TAB"))
(define-key key-translation-map (kbd "M-、") (kbd "TAB"))
(define-key key-translation-map (kbd "M-TAB") (kbd "TAB"))
(define-key key-translation-map (kbd "TAB") (kbd "M-/"))
(add-hook 'org-mode-hook
          (lambda ()
            (let ((keymap (make-sparse-keymap)))
              (set-keymap-parent keymap key-translation-map)
              (setq-local key-translation-map keymap)
              (define-key key-translation-map (kbd "TAB") nil)  ; 禁用全局 TAB 翻译
              (local-set-key (kbd "TAB") 'org-cycle))))  ; 恢复 org-cycle
;; M-o 翻译为 C-x o（切换窗口）；M-~、M-～、M-+ 翻译为 C-x t o（切换标签页）。
(define-key key-translation-map (kbd "M-o") (kbd "C-x o"))
(define-key key-translation-map (kbd "M-~") (kbd "C-x t o"))
(define-key key-translation-map (kbd "M-～") (kbd "C-x t o"))
(define-key key-translation-map (kbd "M-+") (kbd "C-x t o"))
;; 物理 C-w 产生 M-w（复制选区）；物理 M-w 产生 C-w（剪切选区）。
(define-key key-translation-map (kbd "C-w") (kbd "M-w"))
(define-key key-translation-map (kbd "M-w") (kbd "C-w"))
;;将 M-- 映射为撤销
(define-key key-translation-map (kbd "M--") (kbd "C-x u"))
;; SLIME REPL 的个人输入习惯：RET 只换行，M-RET 才提交表达式。
;; 等 slime-repl 加载、键图存在后再设定；不会启动 Lisp 进程，也不改变源码求值键。
;; 源码中的 C-c C-r 仍用于求值选区；C-c r 是稍后 gptel 模块的 AI 改写入口。
(eval-after-load 'slime-repl
  '(progn
     ;; 设置回车键为插入换行，而不是执行代码
     (define-key slime-repl-mode-map (kbd "RET") 'newline)
     ;; 将 Meta-Return 绑定为执行表达式
     (define-key slime-repl-mode-map (kbd "M-RET") 'slime-repl-return)))

;; 上游配置的最低版本提示；保留兼容分支。个人 gptel 另有更高版本依赖，
;; 因此通过此检查不代表旧版 Emacs 能运行所有新增功能。当前使用 Emacs 30.1。
(let ((minver "26.1"))
  (when (version< emacs-version minver)
    (error "Your Emacs is too old -- this config requires v%s or higher" minver)))
(when (version< emacs-version "27.1")
  (message "Your Emacs is old, and some functionality in this config will be disabled. Please upgrade if possible."))

;; 将自有模块目录加入搜索路径；第三方包仍由 package.el 管理。
(add-to-list 'load-path (expand-file-name "lisp" user-emacs-directory))
(require 'init-state) ;; 在包初始化前统一指定历史、会话等运行时数据的保存位置。
(require 'init-benchmarking) ;; 记录启动和模块加载耗时，便于诊断。

(defconst *spell-check-support-enabled* nil) ;; 拼写检查总开关；目前关闭，开启还需外部词典程序。
(defconst *is-a-mac* (eq system-type 'darwin))

;; 启动阶段提高垃圾回收阈值，减少频繁回收；启动结束恢复到 20 MiB。

(let ((normal-gc-cons-threshold (* 20 1024 1024))
      (init-gc-cons-threshold (* 128 1024 1024)))
  (setq gc-cons-threshold init-gc-cons-threshold)
  (add-hook 'emacs-startup-hook
            (lambda () (setq gc-cons-threshold normal-gc-cons-threshold))))

;; 基础设施：先确定 Customize 写入文件，再加载辅助函数、手工包和 ELPA。
;; custom.el 是图形化 Customize 保存的变量，稍后才加载；不要在这里提前重排顺序。

(setq custom-file (locate-user-emacs-file "custom.el"))
(require 'init-utils)
(require 'init-site-lisp) ;; 手工维护的包搜索路径；按原顺序放在 ELPA 前。
;; init-elpa 内部调用 package-initialize，激活当前 Emacs 版本对应的已安装包。
(require 'init-elpa)      ;; 软件源、按需安装和已选包登记。
(require 'init-exec-path) ;; 与 shell 同步外部命令搜索路径。

;; 可选的提前覆盖文件；require 的最后一个 t 表示文件不存在也不报错。
(require 'init-preload-local nil t)

;; 常用基础包：弱化 minor-mode 状态栏、创建临时 buffer、按需记录操作命令。
;; command-log-mode 只在主动启用后记录按键，安装本身不会打开记录窗口。
(require-package 'diminish)
(maybe-require-package 'scratch)
(require-package 'command-log-mode)

;; 界面与导航：新窗口/终端、主题、macOS 按键、文件目录、搜索与 buffer 列表。
(require 'init-frame-hooks)
(require 'init-xterm)
(require 'init-themes)
(require 'init-osx-keys)
(require 'init-gui-frames)
(require 'init-dired)
(require 'init-isearch)
(require 'init-grep)
(require 'init-uniquify)
(require 'init-ibuffer)
;; 代码诊断与语言服务：Flymake 展示检查结果，Eglot 按模式和命令连接语言服务器。
(require 'init-flymake)
(require 'init-eglot)

;; 编辑会话：最近文件、minibuffer 候选、文本补全、窗口布局与历史恢复。
(require 'init-recentf)
(require 'init-minibuffer)
(require 'init-hippie-expand)
(require 'init-corfu)
(require 'init-windows)
(require 'init-sessions)
(require 'init-mmm)

;; 通用编辑：撤销、选区、缩进、长行保护，以及空白字符的显示和清理。
(require 'init-editing-utils)
(require 'init-whitespace)

;; 版本控制：Emacs VC、Darcs、Magit 与 GitHub 辅助命令，均保留现有入口。
(require 'init-vc)
(require 'init-darcs)
(require 'init-git)
(require 'init-github)

;; 项目操作：按项目查文件、切换 buffer 和执行已有项目命令。
(require 'init-projectile)

;; 编译和各语言模块：配置扩展名、hooks 和工具入口；不代表启动所有语言服务。
(require 'init-compile)
(require 'init-crontab)
(require 'init-textile)
(require 'init-markdown)
(require 'init-csv)
(require 'init-erlang)
(require 'init-javascript)
(require 'init-php)
(require 'init-org)
(require 'init-nxml)
(require 'init-html)
(require 'init-css)
(require 'init-haml)
(require 'init-http)
(require 'init-python)
(require 'init-haskell)
(require 'init-elm)
(require 'init-purescript)
(require 'init-ruby)
(require 'init-rails)
(require 'init-sql)
(require 'init-ocaml)
(require 'init-j)
(require 'init-nim)
(require 'init-rust)
(require 'init-toml)
(require 'init-yaml)
(require 'init-docker)
(require 'init-terraform)
(require 'init-nix)
(maybe-require-package 'nginx-mode)

;; Lisp 核心：结构编辑→公共 Lisp 编辑→SLIME→CL 实现设置，保持原加载顺序。
(require 'init-paredit)
(require 'init-lisp)
(require 'init-slime)
(require 'init-clojure)
(require 'init-clojure-cider)
(require 'init-common-lisp)

;; 可选拼写检查受上面的总开关控制；关闭时不加载模块。
(when *spell-check-support-enabled*
  (require 'init-spelling))

;; 其他个人体验设置、折叠和 Dash 文档查询。
(require 'init-misc)

(require 'init-folding)
(require 'init-dash)

;;(require 'init-twitter)
;; (require 'init-mu)
(require 'init-ledger)
;; 以下包无需本地专用模块：保留 sudo 编辑、gnuplot、Lua、HTML 导出等入口。

(require-package 'sudo-edit)
(require-package 'gnuplot)
(require-package 'lua-mode)
(require-package 'htmlize)
(when *is-a-mac*
  (require-package 'osx-location))
(maybe-require-package 'dotenv-mode)
(maybe-require-package 'shfmt)

;; 记录运行时长，保留最近 200 条；不等于每次都重新加载所有模块。
(when (maybe-require-package 'uptimes)
  (setq-default uptimes-keep-count 200)
  (add-hook 'after-init-hook (lambda () (require 'uptimes))))

;; 光标停在符号上时显示参数/说明，由当前语言的后端提供内容。
(when (fboundp 'global-eldoc-mode)
  (add-hook 'after-init-hook 'global-eldoc-mode))

;; 按项目读取 direnv 环境；是否启用具体环境还由 direnv 自己的授权决定。
(require 'init-direnv)

;; 启动本地 Emacs server，允许 emacsclient 复用本会话；已有 server 时不重复启动。
(add-hook 'after-init-hook
          (lambda ()
            (require 'server)
            (unless (server-running-p)
              (server-start))))

;; 加载 Customize 保存的变量；它们可能覆盖前面的默认值，所以必须保留原位置。
(when (file-exists-p custom-file)
  (load custom-file))

;; 最后统一字符编码和区域设置，兼顾图形 Emacs 的初始化时机。
(require 'init-locales)

;; 个人扩展最后加载：目前 init-local 负责接入 gptel，避免散落修改公共语言模块。
;; 聊天/改写偏好在 gptel-preferences.md 中编辑并保存，下次请求会重新读取。
(require 'init-local nil t)

(provide 'init)

;; Local Variables:
;; coding: utf-8
;; no-byte-compile: t
;; End:
;;; init.el ends here
