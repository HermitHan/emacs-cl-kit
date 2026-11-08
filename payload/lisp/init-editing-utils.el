;;; init-editing-utils.el --- Day-to-day editing helpers -*- lexical-binding: t -*-
;;; Commentary:
;; 日常编辑基础行为、显示辅助和全局按键。
;; 全局键可能被主模式/次模式覆盖；C-h k 按键可查看当前 buffer 的实际命令。

;;; Code:

;; 提供 M-x unfill-region / unfill-paragraph，将自动折行的段落重新接成长行。
(require-package 'unfill)

;; 启动后启用括号配对和自动缩进；Lisp buffer 还会由 Paredit 提供结构编辑。
(when (fboundp 'electric-pair-mode)
  (add-hook 'after-init-hook 'electric-pair-mode))
(add-hook 'after-init-hook 'electric-indent-mode)

;; 准备 Unicode 字符浏览工具，安装成功并不表示立即打开字符列表。
(maybe-require-package 'list-unicode-display)


;;; Some basic preferences

;; 基础偏好：搜索默认忽略大小写，缩进使用空格，Ediff 在当前 frame 内左右分屏。
;; 当前沿用关闭锁文件、自动保存和备份副本的选择；本轮只解释，不调整保存策略。
;; 粘贴前保留系统剪贴板内容到 kill-ring；显示列号，长行允许视觉换行。
;; 书签文件 bookmark-default-file 的位置统一由 init-state 设置。
(setq-default
 blink-cursor-interval 0.4
 buffers-menu-max-size 30
 case-fold-search t
 column-number-mode t
 ediff-split-window-function 'split-window-horizontally
 ediff-window-setup-function 'ediff-setup-windows-plain
 indent-tabs-mode nil
 create-lockfiles nil
 auto-save-default nil
 make-backup-files nil
 mouse-yank-at-point t
 save-interprogram-paste-before-kill t
 scroll-preserve-screen-position 'always
 set-mark-command-repeat-pop t
 tooltip-delay 1.5
 truncate-lines nil
 truncate-partial-width-windows nil)

;; 选中区域后输入会替换区域；保留原有选区编辑习惯。
(add-hook 'after-init-hook 'delete-selection-mode)

;; 自动刷新磁盘上已变化且可安全刷新的 buffer，也覆盖 Dired 等非文件 buffer。
;; 关闭刷新提示并隐藏次模式文字，不改变刷新本身。
(add-hook 'after-init-hook 'global-auto-revert-mode)
(setq global-auto-revert-non-file-buffers t
      auto-revert-verbose nil)
(with-eval-after-load 'autorevert
  (diminish 'auto-revert-mode))

;; 显示活动选区，让区域操作的范围更清晰。
(add-hook 'after-init-hook 'transient-mark-mode)



;; Huge files

;; 长行保护：明确启用全局 So Long，在极长行文件里自动降低昂贵的显示功能。
;; 使用现代 global-so-long-mode，并显式传 1，重复调用也不会意外关闭。
(when (fboundp 'global-so-long-mode)
  (add-hook 'after-init-hook (lambda () (global-so-long-mode 1))))

;; VLF 用分块浏览处理大文件；M-x ffap-vlf 打开光标处的文件路径。
;; 这是手动入口，普通 find-file 的行为不变。
(require-package 'vlf)

(defun ffap-vlf ()
  "Find file at point with VLF."
  (interactive)
  (let ((file (ffap-file-at-point)))
    (unless (file-exists-p file)
      (error "File does not exist: %s" file))
    (vlf file)))


;;; A simple visible bell which works in all terminal types
;; 用模式行短暂变化提示错误/边界，适用于图形窗口和终端窗口。
(require-package 'mode-line-bell)
(add-hook 'after-init-hook 'mode-line-bell-mode)



;;; Newline behaviour

;; 普通 RET 换行并缩进；S-RET 先到当前行末再换行。
;; REPL 等模式自己的局部按键优先，仍以该模式绑定为准。
(global-set-key (kbd "RET") 'newline-and-indent)
(defun sanityinc/newline-at-end-of-line ()
  "Move to end of line, enter a newline, and reindent."
  (interactive)
  (move-end-of-line 1)
  (newline-and-indent))

(global-set-key (kbd "S-<return>") 'sanityinc/newline-at-end-of-line)



;; 隐藏 subword-mode 的模式行标识；这里只改显示，并不自动启用该模式。
(with-eval-after-load 'subword
  (diminish 'subword-mode))



;; 编程 buffer 显示行号，并预留至少三列，避免短文件频繁改变正文宽度。
(when (fboundp 'display-line-numbers-mode)
  (setq-default display-line-numbers-width 3)
  (add-hook 'prog-mode-hook 'display-line-numbers-mode))



;; 编程 buffer 显示 fill-column 参考线和左侧边界提示；不会自动切断代码行。
(when (boundp 'display-fill-column-indicator)
  (setq-default indicate-buffer-boundaries 'left)
  (setq-default display-fill-column-indicator-character ?\u254e)
  (add-hook 'prog-mode-hook 'display-fill-column-indicator-mode))



;; 按括号嵌套层级着色，帮助阅读 Lisp；不修改括号和缩进结构。
(when (require-package 'rainbow-delimiters)
  (add-hook 'prog-mode-hook 'rainbow-delimiters-mode))


;; 高亮符号出现位置：M-i 添加，M-I 清除，M-n/M-p 跳到下一/上一处。
;; 在编程、HTML、YAML 和配置文件模式启用；局部按键可能覆盖这些绑定。
(when (maybe-require-package 'symbol-overlay)
  (dolist (hook '(prog-mode-hook html-mode-hook yaml-mode-hook conf-mode-hook))
    (add-hook hook 'symbol-overlay-mode))
  (with-eval-after-load 'symbol-overlay
    (diminish 'symbol-overlay-mode)
    (define-key symbol-overlay-mode-map (kbd "M-i") 'symbol-overlay-put)
    (define-key symbol-overlay-mode-map (kbd "M-I") 'symbol-overlay-remove-all)
    (define-key symbol-overlay-mode-map (kbd "M-n") 'symbol-overlay-jump-next)
    (define-key symbol-overlay-mode-map (kbd "M-p") 'symbol-overlay-jump-prev)))


;;; Zap *up* to char is a handy pair for zap-to-char
;; M-Z 删除到指定字符之前，保留目标字符；与包含目标字符的 zap-to-char 对应。
(global-set-key (kbd "M-Z") 'zap-up-to-char)



;; M-Y 浏览复制/剪切历史，C-g 退出，M-n/M-p 在条目间移动。
;; 分页分隔符由 page-break-lines 显示为横线，不改变历史条目文本。
(require-package 'browse-kill-ring)
(setq browse-kill-ring-separator "\f")
(global-set-key (kbd "M-Y") 'browse-kill-ring)
(with-eval-after-load 'browse-kill-ring
  (define-key browse-kill-ring-mode-map (kbd "C-g") 'browse-kill-ring-quit)
  (define-key browse-kill-ring-mode-map (kbd "M-n") 'browse-kill-ring-forward)
  (define-key browse-kill-ring-mode-map (kbd "M-p") 'browse-kill-ring-previous))
(with-eval-after-load 'page-break-lines
  (add-to-list 'page-break-lines-modes 'browse-kill-ring-mode))


;; Don't disable narrowing commands
;; 允许 narrowing 命令只显示区域/函数/页；C-x n w 可恢复完整 buffer。
;; 同时允许区域大小写转换，取消首次使用时的禁用提示。
(put 'narrow-to-region 'disabled nil)
(put 'narrow-to-page 'disabled nil)
(put 'narrow-to-defun 'disabled nil)
;; Don't disable case-change functions
(put 'upcase-region 'disabled nil)
(put 'downcase-region 'disabled nil)


;; Show matching parens
;; 标出光标附近配对的括号，只提供视觉提示，不代替 Paredit 的结构操作。
(add-hook 'after-init-hook 'show-paren-mode)



;;; Handy key bindings

;; C-. 设置标记，C-x C-. 返回全局标记；C-; 用 Avy 字母提示快速定位字符。
(global-set-key (kbd "C-.") 'set-mark-command)
(global-set-key (kbd "C-x C-.") 'pop-global-mark)

(when (maybe-require-package 'avy)
  (global-set-key (kbd "C-;") 'avy-goto-char-timer))

;; 多光标：C-< 标记前一个相同文本，C-> 或 C-+ 标记下一个，C-c C-< 标记全部。
;; 使用前通常先选中目标文本；Lisp 结构编辑时仍需留意多个位置的语法。
(require-package 'multiple-cursors)
;; multiple-cursors
(global-set-key (kbd "C-<") 'mc/mark-previous-like-this)
(global-set-key (kbd "C->") 'mc/mark-next-like-this)
(global-set-key (kbd "C-+") 'mc/mark-next-like-this)
(global-set-key (kbd "C-c C-<") 'mc/mark-all-like-this)

;; Train myself to use M-f and M-b instead
;; 移除全局 M-左右方向键绑定，原配置希望用 M-f/M-b 按词移动；局部模式可另行定义。
(global-unset-key [M-left])
(global-unset-key [M-right])

;; C-M-Backspace 剪切从当前位置到行首非空白字符之间的内容，并放入 kill-ring。
(defun kill-back-to-indentation ()
  "Kill from point back to the first non-whitespace character on the line."
  (interactive)
  (let ((prev-pos (point)))
    (back-to-indentation)
    (kill-region (point) prev-pos)))

(global-set-key (kbd "C-M-<backspace>") 'kill-back-to-indentation)



;;; Page break lines

;; 把文本中的分页符显示为横线；只改变显示，不删除文件里的分页符。
(when (maybe-require-package 'page-break-lines)
  (add-hook 'after-init-hook 'global-page-break-lines-mode)
  (with-eval-after-load 'page-break-lines
    (diminish 'page-break-lines-mode)))



;; Shift lines up and down with M-up and M-down. When paredit is enabled,
;; it will use those keybindings. For this reason, you might prefer to
;; use M-S-up and M-S-down, which will work even in lisp modes.

;; M-上下移动当前行/区域；Lisp 中 Paredit 可能优先使用这两个键。
;; M-S-上下也绑定行移动；C-c d / C-c u 向下/上复制当前行或区域。
(require-package 'move-dup)
(global-set-key [M-up] 'move-dup-move-lines-up)
(global-set-key [M-down] 'move-dup-move-lines-down)
(global-set-key [M-S-up] 'move-dup-move-lines-up)
(global-set-key [M-S-down] 'move-dup-move-lines-down)

(global-set-key (kbd "C-c d") 'move-dup-duplicate-down)
(global-set-key (kbd "C-c u") 'move-dup-duplicate-up)


;;; 保留个人导航命令，使用内置的字符串边界处理

;; 保留原命令名和 remap，内部委托现代 backward-up-list 处理字符串边界。
;; 正前缀向外回退，0 不移动，负前缀向相反方向；t t 与内置交互调用的参数一致。
;; CL 中 Paredit 若接管 C-M-u，仍按 Paredit 的结构导航执行。
(defun sanityinc/backward-up-sexp (arg)
  "Jump up to the start of the ARG'th enclosing sexp."
  (interactive "p")
  (backward-up-list arg t t))

(global-set-key [remap backward-up-list] 'sanityinc/backward-up-sexp) ; C-M-u, C-M-up



;;; Cut/copy the current line if no region is active
;; 没有活动选区时，复制/剪切命令按整行处理；有选区时仍操作选区。
(require-package 'whole-line-or-region)
(add-hook 'after-init-hook 'whole-line-or-region-global-mode)
(with-eval-after-load 'whole-line-or-region
  (diminish 'whole-line-or-region-local-mode))



;; C-o 在当前位置插入空行并修正两端缩进，光标留在原行一侧。
;; 数字前缀指定插入行数，并沿用当前模式的缩进、填充前缀和左边距。
(defun sanityinc/open-line-with-reindent (n)
  "A version of `open-line' which reindents the start and end positions.
If there is a fill prefix and/or a `left-margin', insert them
on the new line if the line would have been blank.
With arg N, insert N newlines."
  (interactive "*p")
  (let* ((do-fill-prefix (and fill-prefix (bolp)))
         (do-left-margin (and (bolp) (> (current-left-margin) 0)))
         (loc (point-marker))
         ;; Don't expand an abbrev before point.
         (abbrev-mode nil))
    (delete-horizontal-space t)
    (newline n)
    (indent-according-to-mode)
    (when (eolp)
      (delete-horizontal-space t))
    (goto-char loc)
    (while (> n 0)
      (cond ((bolp)
             (if do-left-margin (indent-to (current-left-margin)))
             (if do-fill-prefix (insert-and-inherit fill-prefix))))
      (forward-line 1)
      (setq n (1- n)))
    (goto-char loc)
    (end-of-line)
    (indent-according-to-mode)))

(global-set-key (kbd "C-o") 'sanityinc/open-line-with-reindent)



;; M-^ is inconvenient, so also bind M-j
;; M-j 合并到上一行，提供 join-line 的另一入口，原 M-^ 仍可使用。
(global-set-key (kbd "M-j") 'join-line)


;; Random line sorting
;; 选区后 M-x sanityinc/sort-lines-random 随机重排行；这是显式编辑命令。
(defun sanityinc/sort-lines-random (beg end)
  "Sort lines in region from BEG to END randomly."
  (interactive "r")
  (save-excursion
    (save-restriction
      (narrow-to-region beg end)
      (goto-char (point-min))
      (let ;; To make `end-of-line' and etc. to ignore fields.
          ((inhibit-field-text-motion t))
        (sort-subr nil 'forward-line 'end-of-line nil nil
                   (lambda (s1 s2) (eq (random 2) 0)))))))



;; 启动后高亮字符串中的转义序列，帮助区分反斜杠转义与普通字符。
(require-package 'highlight-escape-sequences)
(add-hook 'after-init-hook 'hes-mode)


;; 按下前缀键后等待约 1.5 秒显示后续键位，适合学习 C-c 等命令组。
(require-package 'which-key)
(add-hook 'after-init-hook 'which-key-mode)
(setq-default which-key-idle-delay 1.5)
(with-eval-after-load 'which-key
  (diminish 'which-key-mode))


;; 执行键盘宏期间临时绑定部分昂贵显示/命令后钩子，减少重复工作。
;; 动态绑定在宏执行返回后恢复；本轮保留原有宏执行策略。
(defun sanityinc/disable-features-during-macro-call (orig &rest args)
  "When running a macro, disable features that might be expensive.
ORIG is the advised function, which is called with its ARGS."
  (let (post-command-hook
        font-lock-mode
        (tab-always-indent (or (eq 'complete tab-always-indent) tab-always-indent)))
    (apply orig args)))

(advice-add 'kmacro-call-macro :around 'sanityinc/disable-features-during-macro-call)


(provide 'init-editing-utils)
;;; init-editing-utils.el ends here
