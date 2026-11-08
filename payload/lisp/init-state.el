;;; init-state.el --- 集中存放历史与会话数据 -*- lexical-binding: t -*-
;;; Commentary:
;; 作用：把运行时生成的个人状态收纳在 ~/.emacs.d/var/，便于区分配置与数据。
;; 加载：init.el 在包初始化之前 require 本模块，让各包第一次读取时就使用新位置。
;; 用法：C-h v 查看下列变量的实际路径；var/ 中的内容由相应功能自动维护。
;; 这里仅设置保存位置，不启用/关闭功能，也不自动搬迁或清空历史。
;; custom.el、gptel-preferences.md、包目录和 .cache/ 中的授权仍使用原位置。

;;; Code:

(defconst han/state-directory
  (file-name-as-directory (expand-file-name "var" user-emacs-directory))
  "当前配置的运行时数据目录，不改变配置根目录 `user-emacs-directory'。")

(defun han/state-file (name)
  "返回状态目录内 NAME 的完整路径。
NAME 是本配置内部使用的相对文件名，如 history 或 eshell/history。
本函数只构造路径，不读写文件；所需目录在本模块加载时统一创建。"
  (expand-file-name name han/state-directory))

;; 有些包会自己建目录，有些直接写文件；提前准备空目录，避免首次保存失败。
(dolist (directory '("" "transient" "eshell" "auto-save-list" "games"))
  (make-directory (han/state-file directory) t))

;; 输入与会话：只集中存放，不合并三种机制各自保存的内容。
;; desktop-path 控制启动时从哪里寻找桌面；保存间隔仍由 init-sessions 设置。
(setq-default
 savehist-file (han/state-file "history")
 session-save-file (han/state-file ".session")
 desktop-path (list han/state-directory)
 recentf-save-file (han/state-file "recentf")
 bookmark-default-file (han/state-file ".bookmarks.el")
 uptimes-database (han/state-file ".uptimes.el")
 org-clock-persist-file (han/state-file "org-clock-save.el"))

;; 项目列表与命令面板历史。Projectile 的项目文件缓存仍是项目根目录内的
;; .projectile-cache.eld；它不能改成一个所有项目共用的文件，因此这里不设置。
(setq-default
 projectile-known-projects-file (han/state-file "projectile-bookmarks.eld")
 transient-history-file (han/state-file "transient/history.el")
 transient-levels-file (han/state-file "transient/levels.el")
 transient-values-file (han/state-file "transient/values.el"))

;; Eshell 的历史、上次目录与别名都放进同一子目录。
;; 显式设置派生文件名，避免包的加载顺序使其中某个路径继续指向旧目录。
(setq-default
 eshell-directory-name (file-name-as-directory (han/state-file "eshell"))
 eshell-history-file-name (han/state-file "eshell/history")
 eshell-last-dir-ring-file-name (han/state-file "eshell/lastdir")
 eshell-aliases-file (han/state-file "eshell/alias"))

;; 自动保存的会话索引和内置游戏分数。
;; 设置索引位置不会开启自动保存；现有 auto-save-default/make-backup-files 保持不变。
;; 冷启动时 Emacs 会在 init.el 结束后按此前缀生成本次索引文件名。
(setq-default
 auto-save-list-file-prefix (han/state-file "auto-save-list/.saves-")
 gamegrid-user-score-file-directory
 (file-name-as-directory (han/state-file "games")))

(provide 'init-state)
;;; init-state.el ends here
