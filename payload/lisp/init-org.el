;;; init-org.el --- Org-mode config -*- lexical-binding: t -*-
;;; Commentary:
;; Org 集中管理大纲笔记、任务、日程、计时、代码块与文档导出。
;; 此文件继承了基于 GTD 的任务分类；下面英文背景说明来自原配置作者，
;; 不表示你的 inbox.org 或日程文件已经创建。实际文件由 org-default-notes-file
;; 和 org-agenda-files 决定；修改变量后可用 C-h v 查看文档和当前值。

;; Among settings for many aspects of `org-mode', this code includes
;; an opinionated setup for the Getting Things Done (GTD) system based
;; around the Org Agenda.  I have an "inbox.org" file with a header
;; including

;;     #+CATEGORY: Inbox
;;     #+FILETAGS: INBOX

;; and then set this file as `org-default-notes-file'.  Captured org
;; items will then go into this file with the file-level tag, and can
;; be refiled to other locations as necessary.

;; Those other locations are generally other org files, which should
;; be added to `org-agenda-files-list' (along with "inbox.org" org).
;; With that done, there's then an agenda view, accessible via the
;; `org-agenda' command, which gives a convenient overview.
;; `org-todo-keywords' is customised here to provide corresponding
;; TODO states, which should make sense to GTD adherents.

;;; Code:

;; 链接工具：macOS 可从其他应用抓取链接；org-cliplink 提供剪贴板 URL 的标题抓取。
;; maybe-require-package 只确保可选包可用；不会在这里自动抓取或发送链接。
(when *is-a-mac*
  (maybe-require-package 'grab-mac-link))

(maybe-require-package 'org-cliplink)

;; 全局入口：C-c l 存储当前位置的 Org 链接，C-c a 打开日程选择菜单。
(define-key global-map (kbd "C-c l") 'org-store-link)
(define-key global-map (kbd "C-c a") 'org-agenda)

;; C-c o 是计时前缀：j 跳到正在计时的任务，l 恢复上次任务，i 开始，o 结束。
;; 前缀键盘表把这些操作归为一组，不要求当前 buffer 必须是 Org。
(defvar sanityinc/org-global-prefix-map (make-sparse-keymap)
  "A keymap for handy global access to org helpers, particularly clocking.")

(define-key sanityinc/org-global-prefix-map (kbd "j") 'org-clock-goto)
(define-key sanityinc/org-global-prefix-map (kbd "l") 'org-clock-in-last)
(define-key sanityinc/org-global-prefix-map (kbd "i") 'org-clock-in)
(define-key sanityinc/org-global-prefix-map (kbd "o") 'org-clock-out)
(define-key global-map (kbd "C-c o") sanityinc/org-global-prefix-map)


;; 通用显示和编辑：完成任务时记日志；隐藏强调标记；编辑折叠内容时先展开。
;; 导出用 UTF-8，HTML 不附验证链接；标签在第 80 列对齐。
;; Various preferences
(setq org-log-done t
      org-edit-timestamp-down-means-later t
      org-hide-emphasis-markers t
      org-fold-catch-invisible-edits 'show
      org-export-coding-system 'utf-8
      org-fast-tag-selection-single-key 'expert
      org-html-validation-link nil
      org-export-kill-product-buffer-when-displayed t
      org-tags-column 80)


;; Org refile settings and sanityinc/verify-refile-target below adapt examples
;; from Bernt Hansen, “Org Mode – Organize Your Life In Plain Text!”.
;; Copyright (C) 2013–2026 Bernt Hansen. The examples are GPL-3.0-or-later.
;; https://doc.norang.ca/org-mode.html (section 2, License)
;; The configuration adapts the target depth, function name and documentation.
;; The GPL text is in ../COPYING.org-examples. The original configuration's
;; BSD notice remains in ../LICENSE.

;; 日程 buffer 中局部安装窗口变化 hook：调整窗口宽度后重新对齐标签。
;; 末尾的 t 表示 hook 只属于当前 buffer，不会影响所有窗口中的文本。
;; Re-align tags when window shape changes
(with-eval-after-load 'org-agenda
  (add-hook 'org-agenda-mode-hook
            (lambda () (add-hook 'window-configuration-change-hook 'org-agenda-align-tags nil t))))




;; 写作视图：M-x prose-mode 手动开关，结合宽度留白、软换行和较大的行距。
;; 开启时尝试启用拼写检查，关闭时撤销这里设置的局部显示项；不会自动修改段落内容。
(maybe-require-package 'writeroom-mode)

(define-minor-mode prose-mode
  "Set up a buffer for prose editing.
This enables or modifies a number of settings so that the
experience of editing prose is a little more like that of a
typical word processor."
  :init-value nil :lighter " Prose" :keymap nil
  (if prose-mode
      (progn
        (when (fboundp 'writeroom-mode)
          (writeroom-mode 1))
        (setq truncate-lines nil)
        (setq word-wrap t)
        (setq cursor-type 'bar)
        (when (eq major-mode 'org-mode)
          (kill-local-variable 'buffer-face-mode-face))
        (buffer-face-mode 1)
        ;;(delete-selection-mode 1)
        (setq-local blink-cursor-interval 0.6)
        (setq-local show-trailing-whitespace nil)
        (setq-local line-spacing 0.2)
        (setq-local electric-pair-mode nil)
        (ignore-errors (flyspell-mode 1))
        (visual-line-mode 1))
    (kill-local-variable 'truncate-lines)
    (kill-local-variable 'word-wrap)
    (kill-local-variable 'cursor-type)
    (kill-local-variable 'blink-cursor-interval)
    (kill-local-variable 'show-trailing-whitespace)
    (kill-local-variable 'line-spacing)
    (kill-local-variable 'electric-pair-mode)
    (buffer-face-mode -1)
    ;; (delete-selection-mode -1)
    (flyspell-mode -1)
    (visual-line-mode -1)
    (when (fboundp 'writeroom-mode)
      (writeroom-mode 0))))

;;(add-hook 'org-mode-hook 'buffer-face-mode)


;; 保留 Shift 加方向键选择文本；Org 的部分 Shift 操作仍由 Org 自身规则协调。
(setq org-support-shift-select t)

;; 快速收集：C-c c 后按 t 新建 NEXT 待办，按 n 新建带 NOTE 标签的笔记。
;; 模板中的 %? 是输入位置，%U 插入非激活时间戳，%a 插入调用位置的链接。
;; (file "") 使用 org-default-notes-file；:clock-resume t 让收集结束后恢复原任务计时。
;;; Capturing

(global-set-key (kbd "C-c c") 'org-capture)

(setq org-capture-templates
      `(("t" "todo" entry (file "")  ; "" => `org-default-notes-file'
         "* NEXT %?\n%U\n" :clock-resume t)
        ("n" "note" entry (file "")
         "* %? :NOTE:\n%U\n%a\n" :clock-resume t)
        ))



;; 任务归档位置的选择（refile）：把条目移动到当前文件或日程文件的标题下。
;; 这里搜索五级以内标题，不缓存目标；默认排除已完成任务作为目标，并在移动后保存 Org 文件。
;;; Refiling

(setq org-refile-use-cache nil)

;; Targets include this file and any file contributing to the agenda - up to 5 levels deep
(setq org-refile-targets '((nil :maxlevel . 5) (org-agenda-files :maxlevel . 5)))

(with-eval-after-load 'org-agenda
  (add-to-list 'org-agenda-after-show-hook 'org-show-entry))

(advice-add 'org-refile :after (lambda (&rest _) (org-save-all-org-buffers)))

;; Exclude DONE state tasks from refile targets
(defun sanityinc/verify-refile-target ()
  "Exclude todo keywords with a done state from refile targets."
  (not (member (nth 2 (org-heading-components)) org-done-keywords)))
(setq org-refile-target-verify-function 'sanityinc/verify-refile-target)

;; 需要移到已完成标题下时，可手动执行下面的 anywhere 命令，临时绕过目标过滤。
;; 第二个命令用于 Agenda；它们只临时绑定变量，不永久改变普通 refile 行为。
(defun sanityinc/org-refile-anywhere (&optional goto default-buffer rfloc msg)
  "A version of `org-refile' which allows refiling to any subtree."
  (interactive "P")
  (let ((org-refile-target-verify-function))
    (org-refile goto default-buffer rfloc msg)))

(defun sanityinc/org-agenda-refile-anywhere (&optional goto rfloc no-update)
  "A version of `org-agenda-refile' which allows refiling to any subtree."
  (interactive "P")
  (let ((org-refile-target-verify-function))
    (org-agenda-refile goto rfloc no-update)))

;; 补全时一次选择完整标题路径；允许创建新的父标题，但要求 Org 提示确认。
;; Targets start with the file name - allows creating level 1 tasks
;;(setq org-refile-use-outline-path (quote file))
(setq org-refile-use-outline-path t)
(setq org-outline-path-complete-in-steps nil)

;; Allow refile to create parent tasks with confirmation
(setq org-refile-allow-creating-parent-nodes 'confirm)


;; 任务状态机：竖线左边是未完成状态，右边是完成状态。
;; 括号中字母是选择状态时的快捷字符；! 记录时间，@ 要求备注，/ 后面控制离开该状态的日志。
;; 重复任务完成后返回 NEXT；NEXT 和 PROJECT 另设显示颜色。
;;; To-do settings

(setq org-todo-keywords
      (quote ((sequence "TODO(t)" "NEXT(n)" "|" "DONE(d!/!)")
              (sequence "PROJECT(p)" "|" "DONE(d!/!)" "CANCELLED(c@/!)")
              (sequence "WAITING(w@/!)" "DELEGATED(e!)" "HOLD(h)" "|" "CANCELLED(c@/!)")))
      org-todo-repeat-to-state "NEXT")

(setq org-todo-keyword-faces
      (quote (("NEXT" :inherit warning)
              ("PROJECT" :inherit font-lock-string-face))))



;; 日程视图：C-c a N 查看 NOTE 笔记，C-c a g 打开组合 GTD 视图。
;; GTD 视图依次包含当天日程、收件箱、停滞项目、下一步行动、项目、孤立待办、等待、委派和搁置任务。
;; INBOX 来自条目/文件标签；PROJECT/NEXT 等来自上面的状态定义，未配置日程文件就不会凭空出现任务。
;;; Agenda views

(setq-default org-agenda-clockreport-parameter-plist '(:link t :maxlevel 3))


;; 把不在 INBOX 内的 PROJECT 当作活跃项目；项目没有 NEXT 条目时列入停滞项目。
;; 后续各块通过 tags-todo 匹配状态/标签，再通过 skip 函数排除不属于该分类的条目。
(let ((active-project-match "-INBOX/PROJECT"))

  (setq org-stuck-projects
        `(,active-project-match ("NEXT")))

  (setq org-agenda-compact-blocks t
        org-agenda-sticky t
        org-agenda-start-on-weekday nil
        org-agenda-span 'day
        org-agenda-include-diary nil
        org-agenda-sorting-strategy
        '((agenda habit-down time-up user-defined-up effort-up category-keep)
          (todo category-up effort-up)
          (tags category-up effort-up)
          (search category-up))
        org-agenda-window-setup 'current-window
        org-agenda-custom-commands
        `(("N" "Notes" tags "NOTE"
           ((org-agenda-overriding-header "Notes")
            (org-tags-match-list-sublevels t)))
          ("g" "GTD"
           ((agenda "" nil)
            (tags "INBOX"
                  ((org-agenda-overriding-header "Inbox")
                   (org-tags-match-list-sublevels nil)))
            (stuck ""
                   ((org-agenda-overriding-header "Stuck Projects")
                    (org-agenda-tags-todo-honor-ignore-options t)
                    (org-tags-match-list-sublevels t)
                    (org-agenda-todo-ignore-scheduled 'future)))
            (tags-todo "-INBOX"
                       ((org-agenda-overriding-header "Next Actions")
                        (org-agenda-tags-todo-honor-ignore-options t)
                        (org-agenda-todo-ignore-scheduled 'future)
                        (org-agenda-skip-function
                         '(lambda ()
                            (or (org-agenda-skip-subtree-if 'todo '("HOLD" "WAITING"))
                                (org-agenda-skip-entry-if 'nottodo '("NEXT")))))
                        (org-tags-match-list-sublevels t)
                        (org-agenda-sorting-strategy
                         '(todo-state-down effort-up category-keep))))
            (tags-todo ,active-project-match
                       ((org-agenda-overriding-header "Projects")
                        (org-tags-match-list-sublevels t)
                        (org-agenda-sorting-strategy
                         '(category-keep))))
            (tags-todo "-INBOX/-NEXT"
                       ((org-agenda-overriding-header "Orphaned Tasks")
                        (org-agenda-tags-todo-honor-ignore-options t)
                        (org-agenda-todo-ignore-scheduled 'future)
                        (org-agenda-skip-function
                         '(lambda ()
                            (or (org-agenda-skip-subtree-if 'todo '("PROJECT" "HOLD" "WAITING" "DELEGATED"))
                                (org-agenda-skip-subtree-if 'nottodo '("TODO")))))
                        (org-tags-match-list-sublevels t)
                        (org-agenda-sorting-strategy
                         '(category-keep))))
            (tags-todo "/WAITING"
                       ((org-agenda-overriding-header "Waiting")
                        (org-agenda-tags-todo-honor-ignore-options t)
                        (org-agenda-todo-ignore-scheduled 'future)
                        (org-agenda-sorting-strategy
                         '(category-keep))))
            (tags-todo "/DELEGATED"
                       ((org-agenda-overriding-header "Delegated")
                        (org-agenda-tags-todo-honor-ignore-options t)
                        (org-agenda-todo-ignore-scheduled 'future)
                        (org-agenda-sorting-strategy
                         '(category-keep))))
            (tags-todo "-INBOX"
                       ((org-agenda-overriding-header "On Hold")
                        (org-agenda-skip-function
                         '(lambda ()
                            (or (org-agenda-skip-subtree-if 'todo '("WAITING"))
                                (org-agenda-skip-entry-if 'nottodo '("HOLD")))))
                        (org-tags-match-list-sublevels nil)
                        (org-agenda-sorting-strategy
                         '(category-keep))))
            ;; (tags-todo "-NEXT"
            ;;            ((org-agenda-overriding-header "All other TODOs")
            ;;             (org-match-list-sublevels t)))
            )))))


;; 日程中突出当前行，便于在任务列表里移动定位。
(add-hook 'org-agenda-mode-hook 'hl-line-mode)


;; 任务计时：持久化运行中的时钟和历史，重新打开 Emacs 后可恢复。
;; 计时及状态变化写入 LOGBOOK 抽屉，零分钟记录自动删除，避免标题下散落日志。
;;; Org clock

;; Save the running clock and all clock history when exiting Emacs, load it on startup
(with-eval-after-load 'org
  (org-clock-persistence-insinuate))
(setq org-clock-persist t)
(setq org-clock-in-resume t)

;; Save clock data and notes in the LOGBOOK drawer
(setq org-clock-into-drawer t)
;; Save state changes in the LOGBOOK drawer
(setq org-log-into-drawer t)
;; Removes clocked tasks with 0:00 duration
(setq org-clock-out-remove-zero-time-clocks t)

;; Show clock sums as hours and minutes, not "n days" etc.
;; 当前 Org 使用 org-duration-format；h:mm 将超过一天的时长继续累计为小时。
(setq org-duration-format 'h:mm)



;; 当前任务显示：开始计时后在 header line 显示任务，停止/取消计时后清空。
;; 该设置修改默认 header-line-format；鼠标左键打开计时菜单，中键跳到计时条目。
;;; Show the clocked-in task - if any - in the header line
(defun sanityinc/show-org-clock-in-header-line ()
  (setq-default header-line-format '((" " org-mode-line-string " "))))

(defun sanityinc/hide-org-clock-from-header-line ()
  (setq-default header-line-format nil))

(add-hook 'org-clock-in-hook 'sanityinc/show-org-clock-in-header-line)
(add-hook 'org-clock-out-hook 'sanityinc/hide-org-clock-from-header-line)
(add-hook 'org-clock-cancel-hook 'sanityinc/hide-org-clock-from-header-line)

(with-eval-after-load 'org-clock
  (define-key org-clock-mode-line-map [header-line mouse-2] 'org-clock-goto)
  (define-key org-clock-mode-line-map [header-line mouse-1] 'org-clock-menu))



;; 可选 macOS 状态栏联动：仅本机安装 org-clock-statusbar.app 时登记 hook。
;; 真正开始/停止计时时才通过 osascript 通知应用，不在加载配置时执行外部程序。
(when (and *is-a-mac* (file-directory-p "/Applications/org-clock-statusbar.app"))
  (add-hook 'org-clock-in-hook
            (lambda () (call-process "/usr/bin/osascript" nil 0 nil "-e"
                                (concat "tell application \"org-clock-statusbar\" to clock in \"" org-clock-current-task "\""))))
  (add-hook 'org-clock-out-hook
            (lambda () (call-process "/usr/bin/osascript" nil 0 nil "-e"
                                "tell application \"org-clock-statusbar\" to clock out"))))



;; TODO: warn about inconsistent items, e.g. TODO inside non-PROJECT
;; TODO: nested projects!



;; 完成内容的归档：放到原文件名加 _archive 的文件之 Archive 标题下。
;; 归档时不强行把条目改成 DONE，保留其原本状态。
;;; Archiving

(setq org-archive-mark-done nil)
(setq org-archive-location "%s_archive::* Archive")





;; 番茄钟：在 Agenda 按 P 调用 org-pomodoro；中途结束也保留已计入的时长。
(require-package 'org-pomodoro)
(setq org-pomodoro-keep-killed-pomodoro-time t)
(with-eval-after-load 'org-agenda
  (define-key org-agenda-mode-map (kbd "P") 'org-pomodoro))


;; 以下 iCal 段整段被注释，当前不会导入日历；保留为原配置的参考方案。
;; ;; Show iCal calendars in the org agenda
;; (when (and *is-a-mac* (require 'org-mac-iCal nil t))
;;   (setq org-agenda-include-diary t
;;         org-agenda-custom-commands
;;         '(("I" "Import diary from iCal" agenda ""
;;            ((org-agenda-mode-hook #'org-mac-iCal)))))

;;   (add-hook 'org-agenda-cleanup-fancy-diary-hook
;;             (lambda ()
;;               (goto-char (point-min))
;;               (save-excursion
;;                 (while (re-search-forward "^[a-z]" nil t)
;;                   (goto-char (match-beginning 0))
;;                   (insert "0:00-24:00 ")))
;;               (while (re-search-forward "^ [a-z]" nil t)
;;                 (goto-char (match-beginning 0))
;;                 (save-excursion
;;                   (re-search-backward "^[0-9]+:[0-9]+-[0-9]+:[0-9]+ " nil t))
;;                 (insert (match-string 0))))))


;; Org 局部键位：C-M-<up> 跳到上一层元素；macOS 中放开 M-h，并用 C-c g 抓取应用链接。
(with-eval-after-load 'org
  (define-key org-mode-map (kbd "C-M-<up>") 'org-up-element)
  (when *is-a-mac*
    (define-key org-mode-map (kbd "M-h") nil)
    (define-key org-mode-map (kbd "C-c g") 'grab-mac-link)))

;; Babel 代码块支持：只登记本机能够找到 ob-语言 库的条目，避免缺库阻断 Org 加载。
;; 值 t 表示启用，nil 表示不启用；这一步加载执行适配器，不运行任何代码块。
;; 实际执行通常使用代码块上的 C-c C-c，并受 Org 的执行确认设置控制。
;; 相应解释器/编译器需在本机可用；Common Lisp 还需已有 SLIME 会话。
(with-eval-after-load 'org
  (org-babel-do-load-languages
   'org-babel-load-languages
   (seq-filter
    (lambda (pair)
      (locate-library (concat "ob-" (symbol-name (car pair)))))
    '((R . t)
      ;; 合并原 init.el 中的代码块语言；保留原有语言支持。
      (lisp . t) ;; Common Lisp，执行时需要 SLIME 连接。
      (C . t)
      (java . t)
      (perl . t)
      (ditaa . t)
      (dot . t)
      (emacs-lisp . t)
      (gnuplot . t)
      (haskell . nil)
      (latex . t)
      (ledger . t)
      (ocaml . nil)
      (octave . t)
      (plantuml . t)
      (python . t)
      (ruby . t)
      (screen . nil)
      (shell . t)
      (sql . t)
      (sqlite . t)))))


;; LaTeX/PDF 导出：Org 导出器加载后选择 XeLaTeX，以适配含中文的文档。
;; 这里只定义导出流程；实际导出 PDF 时才调用本机 xelatex 三次，用于解析交叉引用等信息。
;; TeX 程序、字体和文档依赖包需要另行安装；本段不安装它们。
;; 导出设置与实际编译器保持一致；Org 会据此过滤 pdflatex 专用包。
(with-eval-after-load 'ox-latex
  ;; Org 9.7 的默认包名单使用 xetex，导出器实际识别 xelatex。
  ;; 保留原来的数学符号支持，也保留文档显式选择 pdflatex 的能力。
  (setq org-latex-default-packages-alist
        (mapcar
         (lambda (entry)
           (if (and (listp entry) (nth 3 entry))
               (let* ((copy (copy-tree entry))
                      (compilers (mapcar (lambda (compiler)
                                           (if (equal compiler "xetex") "xelatex" compiler))
                                         (nth 3 copy))))
                 (when (equal (nth 1 copy) "amssymb")
                   (add-to-list 'compilers "xelatex" t))
                 (setf (nth 3 copy) compilers)
                 copy)
             entry))
         org-latex-default-packages-alist))
  (setq org-latex-compiler "xelatex"
        org-latex-pdf-process
        '("xelatex -interaction nonstopmode -output-directory %o %f"
          "xelatex -interaction nonstopmode -output-directory %o %f"
          "xelatex -interaction nonstopmode -output-directory %o %f")))

(provide 'init-org)
;;; init-org.el ends here
