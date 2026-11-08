;;; init-gptel-preferences.el --- 每次请求读取个人偏好 -*- lexical-binding: t -*-

;; 用法：M-x han/gptel-edit-preferences，修改 gptel-preferences.md 后 C-x C-s 保存。
;; 保存后下一次聊天或 rewrite 请求重新读取；已经发出的请求不回溯修改。
;; 这里保存长期编码倾向，不是聊天记录，也不会自动收集其他 buffer 作为上下文。
;; 普通 ;; 注释供人阅读；defcustom/defun 内的字符串是 Emacs 可查询的帮助文本。

(require 'subr-x)
(require 'seq)
(require 'gptel)

;; 路径相对 user-emacs-directory（通常 ~/.emacs.d/），文件内容是普通 UTF-8 文本。
;; 通过 Customize 也可修改路径；不存在或空白文件意味着不附加个人规则。
(defcustom han/gptel-preferences-file
  (expand-file-name "gptel-preferences.md" user-emacs-directory)
  "聊天和 rewrite 共用的 UTF-8 纯文本偏好文件。
每次请求重新读磁盘；保存后下次请求生效。空文件或不存在时不附加偏好。"
  :type 'file
  :group 'gptel)

(defcustom han/gptel-response-language nil
  "gptel 回答使用的语言，例如 \"zh-CN\" 或 \"English\"。
nil 表示跟随本次提问或改写指令的语言，无法判断时参考系统消息语言。
本次明确提出的语言要求优先。在 Customize 中保存即可为本机设置。"
  :type '(choice (const :tag "Automatic" nil) (string :tag "Preferred language"))
  :group 'gptel)

(defun han/gptel--locale-language ()
  "取得系统消息的语言标签。C、POSIX、未设置或不识别的值回退到 en。"
  (let* ((locale (seq-find (lambda (value) (and value (not (string-blank-p value))))
                           (mapcar #'getenv '("LC_ALL" "LC_MESSAGES" "LANG"))))
         (tag (car (split-string (or locale "") "[.@]"))))
    (if (and tag (string-match-p "\\`[A-Za-z]\\{2,3\\}\\(?:[-_][A-Za-z0-9]\\{2,8\\}\\)*\\'" tag))
        (subst-char-in-string ?_ ?- tag)
      "en")))

(defun han/gptel--language-instruction ()
  "构造本次模型请求的语言规则；只传回退语言标签或用户选择的语言。"
  (let ((preferred (string-trim (or han/gptel-response-language ""))))
    (concat
     "Response language: Follow an explicit language or translation request for this turn first. "
     (if (string-empty-p preferred)
         (concat "Otherwise use the language of the user's latest natural-language question or rewrite instruction. "
                 "In a review draft, use the user's added question (我的补充问题), then the latest user-written rewrite instruction. "
                 "Ignore code, quotations, role labels, generated scaffolding and the language of this preference file when inferring it. "
                 "If the user's language is unclear, use the system locale fallback: " (han/gptel--locale-language))
       (concat "Otherwise use the preferred language: " preferred))
     ". Preserve the original language of rewritten prose and the project's language for comments and docstrings, "
     "unless the user requests a change. For new comments or docstrings with no established project language, use the response language. "
     "Keep the requested output format, including replacement-only rewrites.")))

;; 标记属于每个请求的临时 buffer；同一转换流程多次经过 hook 时只附加一次，
;; 新请求仍会使用新临时 buffer，因此可以重新读取你刚保存的文件。
(defvar-local han/gptel--preferences-applied nil
  "只在当前请求的临时 buffer 中标记是否已经附加偏好。")

;; FSM 是 gptel 的请求状态机。先核对当前 buffer 确实是该请求的数据 buffer，
;; 再读取偏好并拼接系统提示；保留已有 directive 的其余内容，不修改来源 buffer。
;; 只 insert-file-contents 读取纯文本，不加载偏好文件，也不处理文件局部变量。
(defun han/gptel--inject-preferences (fsm)
  "给 FSM 的请求临时 buffer 附加已保存的个人偏好和本次语言规则。
保留原系统提示词、对话模板和已有上下文，不修改聊天或源代码。"
  (unless (eq (current-buffer) (plist-get (gptel-fsm-info fsm) :data))
    (error "个人偏好只能附加到 gptel 请求的临时 buffer"))
  (unless han/gptel--preferences-applied
    (let* ((directive (gptel--parse-directive gptel-system-prompt 'raw))
           (preferences (when (file-exists-p han/gptel-preferences-file)
                          (with-temp-buffer
                            (let ((coding-system-for-read 'utf-8))
                              (insert-file-contents han/gptel-preferences-file))
                            (string-trim (buffer-string)))))
           (system (string-join
                    (delq nil
                          (list (car directive)
                                (when (and preferences (not (string-empty-p preferences)))
                                  (concat "Default programming preferences:\n" preferences))
                                (han/gptel--language-instruction)))
                    "\n\n")))
      (setq-local gptel-system-prompt
                  (if (cdr directive) (cons system (cdr directive)) system)))
    (setq-local han/gptel--preferences-applied t)))

;; 编辑入口只打开文件，不发送模型请求；规则仍需与具体任务和输出格式相容。
(defun han/gptel-edit-preferences ()
  "打开个人偏好文件；用 C-x C-s 保存后，下次请求即生效。"
  (interactive)
  (find-file han/gptel-preferences-file))

;; 聊天和 rewrite 都使用此公开扩展点。只追加，不替换已有转换函数。
;; 请求使用独立临时 buffer，避免偏好污染聊天历史或全局系统提示词。
;; hook 深度 90 让个人规则在较后的转换阶段附加；同一个命名函数不会重复登记。
;; 不替换整条 hook 链，因此 gptel 的上下文处理和其他扩展仍按原流程执行。
(add-hook 'gptel-prompt-transform-functions #'han/gptel--inject-preferences 90)

(provide 'init-gptel-preferences)
;;; init-gptel-preferences.el ends here
