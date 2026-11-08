;;; init-gptel-workflow.el --- 聊天导航与改写审阅 -*- lexical-binding: t -*-

;; 工作流导览：
;; 1. 聊天靠 gptel 文本属性区分 user/assistant，C-c j 后接 b/p/n/u/a 定位消息。
;; 2. 源码选区 C-c r 发出 rewrite；候选先显示在 overlay，源文件原文仍保留。
;; 3. 完成后打开独立 Diff：a 接受、k 拒绝、r 续改、e 准备解释草稿，
;;    y 复制当前候选、Y 复制首次原文、s 回源码、q 关闭窗口、? 查看帮助。
;; 4. 复制只进入 kill ring；到 CL REPL 用 C-y 粘贴、M-RET 手动求值，RET 只换行。
;; 5. rewrite 不自动加入旁边聊天；需要讨论时按 e 导入可检查的草稿，再自行发送。
;; 以下较长的状态检查用于处理异步响应、源文变化和多轮续改，避免旧结果覆盖新内容。
;; 本文件只管理编辑/审阅；真实编译、测试和执行仍使用现有 SLIME 工作流。

;; Personal workflow; chat navigation uses gptel role properties.
(require 'cl-lib)
(require 'subr-x)
(require 'gptel)

;; 第一部分：聊天正文与消息导航。
;; 保存的聊天尾部可能有 gptel 角色边界的 Local Variables 元数据；导航和追加草稿
;; 应停在正文末尾，不把这段元数据当成用户输入，也不能误判正文中相似标题。
(defun han/gptel--chat-end ()
  "返回聊天正文末尾，保留已保存聊天末尾的 gptel 文件元数据。"
  (save-excursion
    (goto-char (point-max))
    (let ((end (point)) (case-fold-search t))
      (if (re-search-backward "^\\(.*?\\)Local Variables:[ \t]*\\(.*\\)$" nil t)
          (let ((begin (line-beginning-position))
                (prefix (regexp-quote (match-string-no-properties 1)))
                (suffix (regexp-quote (match-string-no-properties 2))))
            (forward-line 1)
            (if (and (re-search-forward
                      (concat "^" prefix "gptel--bounds:") nil t)
                     (re-search-forward
                      (concat "^" prefix "End:[ \t]*" suffix "$") nil t)
                     (string-empty-p
                      (string-trim (buffer-substring-no-properties (point) end))))
                begin
              end))
        end))))

;; 枚举消息时以 gptel=response 文本属性为准，标题只作显示前缀。
;; 因此代码块内的「## GPT」不会伪造一条回复；末尾尚未填写的用户输入区仍可定位。
(defun han/gptel--messages ()
  "Return visible conversation entries as (ROLE BEGIN BODY).
BEGIN includes a recognized display prefix; BODY is the navigation target.
Only `gptel' response properties identify assistant messages.  Prefixes
are considered solely at property boundaries, so headings inside code
blocks cannot create messages.  An empty final user prompt is retained."
  (let ((prompt (gptel-prompt-prefix-string))
        (reply (gptel-response-prefix-string))
        (limit (han/gptel--chat-end)) entries)
    (save-excursion
      (goto-char (point-min))
      (while (< (point) limit)
        (let* ((beg (point))
               (prop (get-text-property beg 'gptel))
               (end (next-single-property-change beg 'gptel nil limit)))
          (cond
           ((eq prop 'response)
            (let ((begin beg))
              (when (and (not (string-empty-p reply))
                         (>= (- beg (length reply)) (point-min))
                         (equal reply (buffer-substring-no-properties
                                       (- beg (length reply)) beg)))
                (setq begin (- beg (length reply))))
              (skip-chars-forward " \t\r\n" end)
              (when (< (point) end)
                (push (list 'assistant begin (point)) entries))))
           ((null prop)
            (let ((content-end end) begin body has-prompt)
              ;; The assistant title belongs to the preceding unmarked span.
              (when (and (< end limit)
                         (eq (get-text-property end 'gptel) 'response)
                         (not (string-empty-p reply))
                         (>= (- end (length reply)) beg)
                         (equal reply (buffer-substring-no-properties
                                       (- end (length reply)) end)))
                (setq content-end (- end (length reply))))
              (skip-chars-forward " \t\r\n" content-end)
              (setq begin (point))
              (when (and (not (string-empty-p prompt))
                         (<= (+ (point) (length prompt)) content-end)
                         (equal prompt (buffer-substring-no-properties
                                        (point) (+ (point) (length prompt)))))
                (setq has-prompt t)
                (forward-char (length prompt)))
              (let ((input-start (point)))
                (skip-chars-forward " \t\r\n" content-end)
                ;; 空输入后的换行仍属于输入区，不能跳到保存元数据上。
                (setq body
                      (if (and has-prompt (= (point) content-end)
                               (= end limit) (< limit (point-max)))
                          (min input-start (max begin (1- limit)))
                        (point))))
              (when (or (< body content-end)
                        (and has-prompt (= end limit)))
                (push (list 'user begin body) entries)))))
          (goto-char end))))
    (nreverse entries)))

;; 按当前位置寻找当前消息索引，再供前/后消息或角色过滤导航共用。
(defun han/gptel--message-index (messages)
  "Return index of the current message in MESSAGES."
  (let ((index 0) (current 0))
    (dolist (entry messages)
      (when (<= (nth 1 entry) (point)) (setq current index))
      (setq index (1+ index)))
    current))

;; STEP 用于按条移动；ROLE 用于寻找当前/最近的用户或 GPT 消息。
;; 已站在同角色正文开头时再按一次，会继续去上一条同角色消息。
(defun han/gptel--jump-message (&optional step role)
  "Move STEP messages, or to current/recent ROLE when ROLE is non-nil.
Repeating a role command at its target moves to the preceding same role."
  (unless (bound-and-true-p gptel-mode)
    (user-error "此命令只用于 gptel 聊天"))
  (let* ((messages (han/gptel--messages))
         (current (han/gptel--message-index messages))
         (target
          (if role
              (cl-find-if (lambda (entry)
                            (and (eq (car entry) role)
                                 (<= (nth 1 entry) (point))
                                 (/= (nth 2 entry) (point))))
                          (reverse messages))
            (let ((index (+ current (or step 0))))
              (and (>= index 0) (nth index messages))))))
    (unless target (user-error "这个方向没有更多%s消息"
                               (pcase role ('user "用户") ('assistant "GPT") (_ ""))))
    (goto-char (nth 2 target))))

;; 下面五个 interactive 命令既可通过 M-x 调用，也由聊天专属前缀键表调用。
(defun han/gptel-message-beginning ()
  "跳到当前聊天消息的正文开头。"
  (interactive)
  (han/gptel--jump-message))

(defun han/gptel-previous-message ()
  "跳到上一条聊天消息的正文开头。"
  (interactive)
  (han/gptel--jump-message -1))

(defun han/gptel-next-message ()
  "跳到下一条聊天消息的正文开头。"
  (interactive)
  (han/gptel--jump-message 1))

(defun han/gptel-user-message ()
  "跳到当前或最近用户消息开头；在该开头再次调用则到上一条用户消息。"
  (interactive)
  (han/gptel--jump-message nil 'user))

(defun han/gptel-assistant-message ()
  "跳到当前或最近 GPT 消息开头；在该开头再次调用则到上一条 GPT 消息。"
  (interactive)
  (han/gptel--jump-message nil 'assistant))

;; 只绑定 gptel-mode-map，不影响源码里的 C-c 前缀：
;; C-c j b 当前消息开头；p 上一条；n 下一条；u 用户消息；a GPT 消息。
;; 目标是消息正文开头，跳过「你/GPT」显示标题和前导空白。
(defvar han/gptel-chat-navigation-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "b") #'han/gptel-message-beginning)
    (define-key map (kbd "p") #'han/gptel-previous-message)
    (define-key map (kbd "n") #'han/gptel-next-message)
    (define-key map (kbd "u") #'han/gptel-user-message)
    (define-key map (kbd "a") #'han/gptel-assistant-message)
    map)
  "Navigation prefix available only in gptel chat buffers.")

(define-key gptel-mode-map (kbd "C-c j") han/gptel-chat-navigation-map)


(require 'cl-lib)
(require 'gptel)

;; 第二部分：改写快照与请求生命周期。
;; 每次请求都有独立 id，来源/审阅 buffer 用局部变量记录最近的候选。
;; :original 是首次改写前的选区；:source-text 是本轮发出时的真实源文；
;; :input 可能是上一轮候选；:result 是本轮完成的候选。这几者不能合并为一个字段。
;; :previous 只用于失败恢复；完成后断开旧链，避免长期持有整段请求历史。
(defvar han/gptel--rewrite-sequence 0)
(defvar-local han/gptel--last-rewrite nil
  "当前来源或比较 buffer 的最后一份完整改写快照。")
(defvar-local han/gptel--pending-rewrites nil)
(defvar-local han/gptel--rewrite-imports nil)

;; 把主模式名转换成解释草稿中的代码块语言标记，明确区分 CL 与 Emacs Lisp。
(defun han/gptel--rewrite-language (mode)
  (pcase mode
    ('lisp-mode "lisp")
    ('emacs-lisp-mode "emacs-lisp")
    (_ (string-remove-suffix "-mode" (symbol-name mode)))))

;; 在真正 gptel-request 发出前捕获 rewrite 参数；普通聊天和 dry-run 不建立记录。
;; 同一区域仍 pending 时拒绝叠加新请求；请求尚未发出便失败也统一走恢复逻辑。
;; overlay 是附着于 buffer 的显示对象，覆盖显示候选并不等于替换源文件文本。
(defun han/gptel--capture-rewrite (original prompt &rest args)
  "在 ORIGINAL 发出局部改写前，保存 PROMPT 和 ARGS 对应的快照。"
  (let* ((context (plist-get args :context))
         (ov (car-safe context))
         captured)
    (when (and (eq (plist-get args :callback) #'gptel--rewrite-callback)
               (not (plist-get args :dry-run))
               (overlayp ov) (overlay-buffer ov)
               (listp prompt) (stringp (car prompt)))
      (let* ((source (overlay-buffer ov))
             (previous (overlay-get ov 'han/gptel-rewrite-record))
             (_pending-check
              (when (eq (plist-get previous :status) 'pending)
                ;; 上游已为这次尝试分配临时回复 buffer，但尚未发请求。
                (when (buffer-live-p (cdr-safe context))
                  (kill-buffer (cdr context)))
                (user-error "这个区域的改写仍在生成，请等当前请求结束")))
             (source-text (with-current-buffer source
                            (buffer-substring-no-properties
                             (overlay-start ov) (overlay-end ov))))
             (record
              (list :id (cl-incf han/gptel--rewrite-sequence)
                    :status 'pending :source source :overlay ov
                    :previous previous :response-buffer (cdr-safe context)
                    :review-buffer (plist-get previous :review-buffer)
                    :candidate-buffer (plist-get previous :candidate-buffer)
                    :name (with-current-buffer source
                            (or buffer-file-name (buffer-name)))
                    :language (han/gptel--rewrite-language
                               (buffer-local-value 'major-mode source))
                    ;; 保留最初源文；迭代请求的输入可能已是上一轮候选。
                    :original (or (plist-get previous :original) source-text)
                    :source-text source-text
                    :input (substring-no-properties (car prompt))
                    :instruction (when (stringp (nth 2 prompt))
                                   (substring-no-properties (nth 2 prompt))))))
        (overlay-put ov 'han/gptel-rewrite-record record)
        (setq captured record)
        (with-current-buffer source
          (cl-pushnew ov han/gptel--pending-rewrites))))
    (condition-case error-data
        (apply original prompt args)
      ((error quit)
       (when captured
         (han/gptel--rewrite-failed
          captured (list :context context)
          (if (eq (car error-data) 'quit) "请求已取消" "请求未能发出")))
       (signal (car error-data) (cdr error-data))))))

;; 请求失败/取消：只有源文和 overlay 仍匹配本轮快照时，才能恢复上一版候选。
;; 恢复后保留失败要求供 r 重试；否则结束预览，防止把过期内容重新覆盖到源码上。
;; 清理 pending、回复 buffer 和提示状态，避免 Diff 永久停留在「生成中」。
(defun han/gptel--rewrite-failed (record info reason)
  "结束 RECORD 的失败请求；安全时恢复上一版候选，不修改源代码。"
  (let* ((ov (plist-get record :overlay))
         (source (plist-get record :source))
         (previous (plist-get record :previous))
         ;; 若成功结果已进入 Diff 绘制阶段，不把半刷新的 Diff 当成旧版。
         (restore (and (eq (plist-get record :status) 'pending)
                       previous (stringp (plist-get previous :result))
                       (buffer-live-p source) (overlayp ov)
                       (eq (overlay-buffer ov) source)
                       (with-current-buffer source
                         (save-restriction
                           (widen)
                           (equal (buffer-substring-no-properties
                                   (overlay-start ov) (overlay-end ov))
                                  (plist-get record :source-text))))))
         (response-buffer (cdr-safe (plist-get info :context))))
    (plist-put record :status 'failed)
    (plist-put record :failure reason)
    (when (and (buffer-live-p response-buffer) (not (eq response-buffer source)))
      (kill-buffer response-buffer))
    (when (buffer-live-p source)
      (with-current-buffer source
        (setq han/gptel--pending-rewrites (delq ov han/gptel--pending-rewrites))
        (if restore
            (progn
              ;; 失败要求保留给重试，不冒充上一版已完成的要求。
              (plist-put previous :retry-instruction (plist-get record :instruction))
              (plist-put previous :last-error reason)
              (overlay-put ov 'han/gptel-rewrite-record previous)
              (overlay-put ov 'gptel-rewrite (plist-get previous :result))
              (overlay-put ov 'display (plist-get previous :result))
              (overlay-put ov 'face 'gptel-rewrite-highlight-face)
              (overlay-put ov 'keymap gptel-rewrite-actions-map)
              (gptel--rewrite-update-status ov " 续改失败，上一版待审阅" '(warning default))
              (cl-pushnew ov gptel--rewrite-overlays)
              (setq han/gptel--last-rewrite previous))
          (setq gptel--rewrite-overlays (delq ov gptel--rewrite-overlays))
          (when (overlayp ov) (delete-overlay ov))
          (unless gptel--rewrite-overlays
            (remove-hook 'eldoc-documentation-functions #'gptel--rewrite-key-help t)))))
    (plist-put record :previous nil)
    (force-mode-line-update t)
    (message "改写未完成（%s）；%s" reason
             (if restore "上一版候选已保留，可审阅或按 r 重试"
               "源代码未由此请求替换，请从当前代码重新改写"))))

;; 异步回调可能在取消或下一轮请求之后才到达；同时核对 pending 状态与回复 buffer
;; 身份，防止旧请求改写新候选。只保护个人 rewrite 记录，普通 gptel 回调照常执行。
(defun han/gptel--rewrite-callback-guard (original response info)
  "处理个人改写的异步失败，避免预览消失后 Diff 永远显示生成中。"
  (let* ((context (plist-get info :context))
         (ov (car-safe context))
         (record (and (overlayp ov) (overlay-get ov 'han/gptel-rewrite-record))))
    (cond
     ((not record) (funcall original response info))
     ;; 已结束请求或旧请求的迟到回调不能覆盖新候选。
     ((or (not (eq (plist-get record :status) 'pending))
          (and (plist-member record :response-buffer)
               (not (eq (plist-get record :response-buffer) (cdr-safe context))))) nil)
     ((or (null response) (eq response 'abort) (not (overlay-buffer ov)))
      (han/gptel--rewrite-failed
       record info (if (eq response 'abort) "请求已取消"
                     (or (plist-get info :status) "请求失败"))))
     (t
      (condition-case err
          (funcall original response info)
        ((error quit)
         (han/gptel--rewrite-failed
          record info (if (eq (car err) 'quit) "请求已取消"
                        (format "回调失败：%s" (error-message-string err))))))))))

;; 热加载前已经存在的预览可能缺少请求快照；回退记录明确标记 fallback，
;; 解释时只能声称拿到当前源文，不能伪称保存了当时的完整要求。
(defun han/gptel--fallback-rewrite (ov)
  "为没有请求快照的已有预览 OV 建立明确标记的回退记录。"
  (let ((source (overlay-buffer ov)))
    (list :id (cl-incf han/gptel--rewrite-sequence)
          :status 'ready :fallback t :source source :overlay ov
          :name (with-current-buffer source (or buffer-file-name (buffer-name)))
          :language (han/gptel--rewrite-language
                     (buffer-local-value 'major-mode source))
          :original (with-current-buffer source
                      (buffer-substring-no-properties
                       (overlay-start ov) (overlay-end ov)))
          :source-text (with-current-buffer source
                         (buffer-substring-no-properties
                          (overlay-start ov) (overlay-end ov)))
          :result (substring-no-properties (overlay-get ov 'gptel-rewrite)))))

;; 第三部分：Diff / 候选审阅窗口的局部快捷键。
;; 单独的 minor-mode 键表只在个人审阅 buffer 启用，不改变普通 diff-mode。
;; q 只关闭窗口，候选仍待决定；a/k 才做接受/拒绝，均不会自动保存或执行代码。
(defvar han/gptel-review-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "a") #'han/gptel-review-accept)
    (define-key map (kbd "k") #'han/gptel-review-reject)
    (define-key map (kbd "e") #'han/gptel-review-explain)
    (define-key map (kbd "r") #'han/gptel-review-iterate)
    (define-key map (kbd "s") #'han/gptel-review-source)
    (define-key map (kbd "q") #'quit-window)
    (define-key map (kbd "?") #'han/gptel-review-help)
    map)
  "只在个人 gptel 审阅窗口中使用，不修改 diff-mode-map。")

;; 单独更新现有 keymap，热加载后已打开的审阅窗口也立即可用。
(define-key han/gptel-review-mode-map (kbd "y") #'han/gptel-review-copy-candidate)
(define-key han/gptel-review-mode-map (kbd "Y") #'han/gptel-review-copy-original)

;; 保存原 header-line，关闭审阅模式时恢复；补充要求的 minibuffer 历史单独保存。
(defvar-local han/gptel--review-old-header nil)
(defvar han/gptel--iteration-history nil)

;; 顶部状态每次重绘从当前记录推导，区分生成中、旧版本、已决定和失败恢复。
;; 旧 Diff 可以留作参考，但下面的动作校验会阻止它操作新一轮候选。
(defun han/gptel--review-header ()
  "显示审阅动作及当前候选状态。"
  (let* ((record han/gptel--last-rewrite)
         (ov (plist-get record :overlay))
         (latest (and (overlayp ov)
                      (overlay-get ov 'han/gptel-rewrite-record)))
         (state (cond
                 ((eq (plist-get latest :status) 'pending) "生成中")
                 ((eq (plist-get latest :status) 'failed) "生成失败")
                 ((plist-get record :decision)
                  (if (eq (plist-get record :decision) 'accepted)
                      "已接受" "已拒绝"))
                 ((or (not (overlayp ov)) (not (overlay-buffer ov))) "预览已结束")
                 ((not (eq latest record)) "旧版本")
                 ((plist-get record :last-error) "续改失败，上一版保留")
                 (t "待审阅"))))
    (format " GPT [%s]  y复制新 Y复制原  a接受 k拒绝 e解释 r续改 s源码 q关闭 ?帮助" state)))

(define-minor-mode han/gptel-review-mode
  "为独立 gptel Diff / 候选窗口提供审阅操作。"
  :init-value nil :lighter " GPT审阅" :keymap han/gptel-review-mode-map
  (if han/gptel-review-mode
      (progn
        (setq han/gptel--review-old-header header-line-format)
        (setq-local header-line-format '(:eval (han/gptel--review-header))))
    (setq header-line-format han/gptel--review-old-header)))

;; 所有审阅动作统一验证记录仍是当前已完成候选；涉及接受/续改时还比较真实源文。
;; 如果你在等待期间改过源码，先拒绝旧候选再从新代码请求，可避免静默覆盖修改。
(defun han/gptel--review-record (&optional check-source)
  "取得仍待审阅的候选；CHECK-SOURCE 时拒绝覆盖后来修改的源文。"
  (require 'gptel-rewrite)
  (let* ((record han/gptel--last-rewrite)
         (ov (plist-get record :overlay))
         (source (plist-get record :source)))
    (unless (and han/gptel-review-mode
                 (buffer-live-p source) (overlayp ov)
                 (eq (overlay-buffer ov) source)
                 (eq (overlay-get ov 'han/gptel-rewrite-record) record)
                 (eq (plist-get record :status) 'ready)
                 (not (plist-get record :decision))
                 (stringp (plist-get record :result))
                 (equal (overlay-get ov 'gptel-rewrite)
                        (plist-get record :result)))
      (user-error "候选正在生成、已结束或已过期；请使用最新完成的 Diff"))
    (when check-source
      (with-current-buffer source
        (save-restriction
          (widen)
          (unless (equal (buffer-substring-no-properties
                          (overlay-start ov) (overlay-end ov))
                         (plist-get record :source-text))
            (user-error "源代码在生成后已变化；请拒绝这份候选并从新代码重新改写")))))
    record))

(defun han/gptel-review-help ()
  "显示当前审阅窗口的快捷键。"
  (interactive)
  (message "y 复制当前候选；Y 复制首次原文；到 REPL 用 C-y 粘贴；a 接受；k 拒绝；e 解释草稿；r 续改；s 源码；q 关闭（保留候选）"))

;; y/Y 从纯文本快照复制，而不是从带 +/- 标记的 Diff 或 overlay 显示中截取。
;; 保留缩进、注释和文档字符串；只复制改写选区，不复制整个源文件或 Diff 标题。
;; 复制要求候选已完成且仍待审阅，防止误复制正在流式生成的半段代码。
(defun han/gptel--review-copy (field label)
  "复制当前完成的改写记录中 FIELD 对应的选区快照，并显示 LABEL。
仅写入 kill ring，不接受候选、不修改源文，也不编译或求值。"
  (let* ((record (han/gptel--review-record))
         (text (plist-get record field)))
    (unless (stringp text)
      (user-error "这份改写没有可复制的%s快照" label))
    (kill-new (substring-no-properties text))
    (message "已复制%s快照（%d 字符）；到 REPL 用 C-y 粘贴，尚未求值"
             label (length text))))

(defun han/gptel-review-copy-candidate ()
  "复制当前完整候选选区，保留文档字符串、注释和缩进。"
  (interactive)
  (han/gptel--review-copy :result "当前候选"))

(defun han/gptel-review-copy-original ()
  "复制首次改写前的原始选区；多次续改后仍保留首次原文。"
  (interactive)
  (han/gptel--review-copy :original "首次原文"))

;; s 返回来源 buffer 的改写起点；必要时 widen，使被窄化隐藏的选区重新可见。
(defun han/gptel-review-source ()
  "回到这份候选的来源 buffer。"
  (interactive)
  (let* ((record han/gptel--last-rewrite)
         (source (plist-get record :source))
         (ov (plist-get record :overlay)))
    (unless (buffer-live-p source) (user-error "来源 buffer 已关闭"))
    (pop-to-buffer source)
    (when (and (overlayp ov) (overlay-buffer ov))
      (unless (<= (point-min) (overlay-start ov) (point-max)) (widen))
      (goto-char (overlay-start ov)))))

;; a 通过上游接受函数替换选区，并用 atomic-change-group/undo-boundary 归为一次
;; 可撤销编辑，然后移除预览。文件仍未保存，CL image 也不会因此自动重新编译。
(defun han/gptel-review-accept ()
  "接受此窗口对应的候选，不保存文件、不编译或执行。"
  (interactive)
  (let* ((record (han/gptel--review-record t))
         (ov (plist-get record :overlay))
         (source (plist-get record :source)))
    (with-current-buffer source
      (save-restriction
        (widen)
        (barf-if-buffer-read-only)
        (undo-boundary)
        (atomic-change-group (gptel--rewrite-accept ov))
        (undo-boundary)
        (gptel--rewrite-reject ov)))
    (plist-put record :decision 'accepted)
    (pop-to-buffer source)
    (force-mode-line-update t)
    (message "已接受这一处改写；尚未保存，可用 undo 撤销")))

;; k 移除候选显示并记录拒绝；源 buffer 的原代码保持原样。
(defun han/gptel-review-reject ()
  "拒绝此窗口对应的候选，保留原代码。"
  (interactive)
  (let* ((record (han/gptel--review-record))
         (ov (plist-get record :overlay))
         (source (plist-get record :source)))
    (with-current-buffer source (gptel--rewrite-reject ov))
    (plist-put record :decision 'rejected)
    (pop-to-buffer source)
    (force-mode-line-update t)
    (message "已拒绝这一处候选，源代码未替换")))

;; e 是可选动作：把原文、候选和要求带入聊天草稿。默认 rewrite 仍只返回代码，
;; 文档字符串/注释如何写由共享偏好文件约束，不强制在 Diff 中追加解释段落。
(defun han/gptel-review-explain ()
  "把此候选带入聊天准备解释草稿，不自动发送。"
  (interactive)
  (han/gptel--review-record)
  (call-interactively #'han/gptel-explain-rewrite))

;; r 每次都会发出一个新的请求，并不是复用同一网络请求。
;; 它以当前候选为输入，累积此前要求和本轮补充；冲突时本轮优先，首次原文仍保留。
;; 这种「续改上下文」不等于旁边聊天的全部历史，也不是跨任务的永久记忆。
;; 已保存的个人偏好仍由独立 hook 在每次请求时附加；来源直到 a 接受才真正替换。
(defun han/gptel-review-iterate ()
  "输入补充要求，以当前候选继续改写，保留原源文直到接受。
保留此前改写要求，再附加本轮要求；冲突时以本轮要求为准。"
  (interactive)
  (han/gptel--review-record t)
  (let* ((extra (string-trim
                 (read-string (if (plist-get han/gptel--last-rewrite :retry-instruction)
                                  "继续改写（留空重试上次失败要求），补充要求："
                                "继续改写（当前候选未接受），补充要求：")
                              nil 'han/gptel--iteration-history)))
         ;; 输入提示期间源 buffer 或候选可能改变，发送前再次验证。
         (record (han/gptel--review-record t))
         (ov (plist-get record :overlay))
         (source (plist-get record :source))
         (retry (plist-get record :retry-instruction))
         (previous (or retry (plist-get record :instruction))))
    (when (and (string-empty-p extra) (not retry))
      (user-error "未输入补充要求，保留当前候选"))
    (with-current-buffer source
      (save-excursion
        (save-restriction
          (widen)
          (goto-char (overlay-start ov))
          (unless (eq (cdr (get-char-property-and-overlay (point) 'gptel-rewrite)) ov)
            (user-error "这里存在重叠或空预览，请回源代码确认改写区域"))
          (let ((mark-active nil))
            (gptel--suffix-rewrite
             (if (string-empty-p extra) retry
               (concat (when previous (concat previous "\n\n"))
                       "请在当前候选基础上继续修改。保留此前要求；冲突时以本轮补充为准。\n"
                       "本轮补充要求：\n" extra)))))))
    (force-mode-line-update t)
    (message "已基于当前候选继续改写；完成后更新 Diff，源代码仍未替换")))

;; 构造完整源码副本，再仅在副本应用候选，最后与真实 source 比较生成 Diff。
;; 这里调用上游 accept 时明确指定副本，不是在偷偷接受源文件中的改写。
;; 候选和 Diff 都设为只读，方便审阅；复制原始选区用 y/Y，不需剥离差异标记。
(defun han/gptel--show-rewrite-diff (record)
  "给 RECORD 创建独立比较窗口，不占用普通 *Diff* buffer。"
  (require 'diff)
  (let* ((source (plist-get record :source))
         (ov (plist-get record :overlay))
         (candidate (or (and (buffer-live-p (plist-get record :candidate-buffer))
                             (plist-get record :candidate-buffer))
                        (generate-new-buffer "*GPT 改写候选*")))
         (review (or (and (buffer-live-p (plist-get record :review-buffer))
                          (plist-get record :review-buffer))
                     (generate-new-buffer "*GPT 改写 Diff*"))))
    (plist-put record :candidate-buffer candidate)
    (plist-put record :review-buffer review)
    (with-current-buffer candidate
      (let ((inhibit-read-only t)
            (inhibit-message t))
        (widen)
        (erase-buffer)
        (insert (with-current-buffer source
                  (save-restriction (widen) (buffer-substring-no-properties
                                            (point-min) (point-max)))))
        ;; 上游接受函数只修改指定副本，不修改源 buffer。
        (gptel--rewrite-accept ov candidate))
      (set-buffer-modified-p nil))
    (let ((diff-entire-buffers t))
      (diff-no-select source candidate nil t review))
    (dolist (buffer (list candidate review))
      (with-current-buffer buffer
        (setq-local han/gptel--last-rewrite record)
        (setq-local buffer-read-only t)
        (unless han/gptel-review-mode (han/gptel-review-mode 1))))
    (with-current-buffer review
      (setq-local diff-jump-to-old-file t)
      (goto-char (point-min)))
    (display-buffer review)))

;; 上游默认完成动作转到这里：保存完整结果，清除 pending，刷新/复用审阅窗口。
;; 不在这里接受候选，也不保存文件、编译或求值。
(defun han/gptel-rewrite-ready (ov)
  "保存完成的改写 OV，再打开独立 Diff；不接受或执行候选代码。"
  (when (and (overlayp ov) (overlay-buffer ov)
             (stringp (overlay-get ov 'gptel-rewrite)))
    (let* ((source (overlay-buffer ov))
           (record (or (overlay-get ov 'han/gptel-rewrite-record)
                       (han/gptel--fallback-rewrite ov))))
      (setq record (plist-put record :result
                              (substring-no-properties
                               (overlay-get ov 'gptel-rewrite))))
      (setq record (plist-put record :status 'ready))
      (overlay-put ov 'han/gptel-rewrite-record record)
      (with-current-buffer source
        (setq han/gptel--last-rewrite record
              han/gptel--pending-rewrites
              (delq ov han/gptel--pending-rewrites)))
      (han/gptel--show-rewrite-diff record)
      (plist-put record :previous nil))))

;; 第四部分：把改写带入聊天讨论。
;; 先检查请求状态，避免在目标聊天正接收回复时插入草稿，打乱角色边界。
(defun han/gptel--request-active-p (buffer)
  "只检查请求元数据，判断 BUFFER 是否仍有 gptel 请求。"
  (cl-some
   (lambda (entry)
     (let ((fsm (cadr entry)))
       (and (gptel-fsm-p fsm)
            (eq (plist-get (gptel-fsm-info fsm) :buffer) buffer))))
   gptel--request-alist))

;; 优先用光标处预览，其次取当前 buffer 最近完成的记录；拒绝正在生成的半成品。
;; 这使解释对应明确的一份改写快照，而不是临时猜测屏幕上显示的文本。
(defun han/gptel--rewrite-for-explanation ()
  "取得光标处或当前 buffer 最后的完整改写，拒绝未完成的快照。"
  (let* ((ov (cl-find-if
              (lambda (item)
                (or (overlay-get item 'han/gptel-rewrite-record)
                    (overlay-get item 'gptel-rewrite)))
              (overlays-at (point))))
         (record (and ov (overlay-get ov 'han/gptel-rewrite-record))))
    (when (or (eq (plist-get record :status) 'pending)
              (and (not ov)
                   (or (han/gptel--request-active-p (current-buffer))
                       (cl-some
                        (lambda (item)
                          (and (overlay-buffer item)
                               (eq (plist-get
                                    (overlay-get item 'han/gptel-rewrite-record)
                                    :status)
                                   'pending)))
                        han/gptel--pending-rewrites))))
      (user-error "当前改写尚未完成，请等候选代码准备好后再解释"))
    (when (and ov (not record)
               (stringp (overlay-get ov 'gptel-rewrite)))
      (setq record (han/gptel--fallback-rewrite ov))
      (overlay-put ov 'han/gptel-rewrite-record record))
    (setq record (or record han/gptel--last-rewrite))
    (unless (and (eq (plist-get record :status) 'ready)
                 (stringp (plist-get record :result)))
      (user-error "这里没有可解释的完整改写；请回到源代码预览或比较窗口"))
    record))

;; 无聊天时创建「改写讨论」，一个聊天时复用，多个时由你选择目标。
;; 创建/选择聊天只准备编辑位置，不会自动把草稿发送给模型。
(defun han/gptel--choose-rewrite-chat ()
  "选择已有聊天；没有聊天时创建独立的改写讨论 buffer。"
  (let ((buffers (cl-remove-if-not
                  (lambda (buffer) (buffer-local-value 'gptel-mode buffer))
                  (buffer-list))))
    (pcase (length buffers)
      (0 (gptel (generate-new-buffer-name "*改写讨论*")))
      (1 (car buffers))
      (_ (get-buffer
          (completing-read "把改写带入哪个聊天："
                           (mapcar #'buffer-name buffers) nil t))))))

;; 按目标聊天是 Org 还是 Markdown 输出正确代码块；代码内部的反引号不能
;; 提前结束外层围栏，因此 Markdown 围栏长度需随内容调整。
(defun han/gptel--rewrite-code-block (text language)
  "按当前聊天格式，把 TEXT 包装为 LANGUAGE 代码块。"
  (if (derived-mode-p 'org-mode)
      (progn
        (require 'org-src)
        (format "#+begin_src %s\n%s\n#+end_src\n"
                language (org-escape-code-in-string text)))
    (let ((length 3) (start 0))
      ;; 避免代码内已有的反引号提前结束 Markdown 围栏。
      (while (string-match "`+" text start)
        (setq length (max length (1+ (- (match-end 0) (match-beginning 0))))
              start (match-end 0)))
      (let ((fence (make-string length ?`)))
        (format "%s%s\n%s\n%s\n" fence language text fence)))))

;; 解释草稿明确区分首次原文、本轮输入和候选，提醒尚未接受/运行。
;; 它复制本次改写所需内容，不读取未选择的其他文件或整个 Lisp image。
(defun han/gptel--rewrite-draft (record)
  "把 RECORD 格式化为当前聊天中的用户解释草稿。"
  (let ((language (plist-get record :language))
        (original (plist-get record :original))
        (input (plist-get record :input)))
    (concat
     "下面是一份从局部改写导入的代码记录。候选尚不代表已接受、编译或运行。\n"
     "来源：" (plist-get record :name) "\n\n"
     "本轮改写要求：\n"
     (or (plist-get record :instruction)
         "（未知：这份旧预览没有保存当时的改写要求。）") "\n\n"
     (if (plist-get record :fallback)
         "当前源文（旧预览未保存请求时快照）：\n"
       "最初原文（请求时快照）：\n")
     (han/gptel--rewrite-code-block original language)
     (when (and input (not (equal input original)))
       (concat "\n本轮实际输入（迭代时可能是上一轮候选）：\n"
               (han/gptel--rewrite-code-block input language)))
     "\nAI 建议代码（局部改写的结果）：\n"
     (han/gptel--rewrite-code-block (plist-get record :result) language)
     "\n请结合改写要求，解释主要差异、理由、行为变化和需要验证的假设。"
     "不要自动执行代码；尚未运行的内容请明确说明。\n\n"
     "我的补充问题：")))

;; M-x han/gptel-explain-rewrite 也可直接调用；重复调用定位已导入处，
;; C-u 前缀允许再次导入。同一改写 id 与聊天中的 marker 配对，避免意外重复粘贴。
;; 草稿追加而不覆盖尚未发送的用户输入；尾部文件元数据和 user 属性保持正确。
(defun han/gptel-explain-rewrite (&optional force)
  "把完整改写带入选定聊天，准备解释草稿，不自动发送。
保留现有聊天内容和设置。重复调用定位已导入处；前缀 FORCE 允许再导入。"
  (interactive "P")
  (require 'gptel-rewrite)
  (let* ((record (han/gptel--rewrite-for-explanation))
         (target (han/gptel--choose-rewrite-chat)))
    (when (han/gptel--request-active-p target)
      (user-error "目标聊天还在响应，请等本轮结束后再带入改写"))
    (with-current-buffer target
      (when buffer-read-only (user-error "目标聊天是只读 buffer"))
      (let ((previous (alist-get (plist-get record :id)
                                 han/gptel--rewrite-imports)))
        (if (and (not force) (markerp previous) (marker-buffer previous))
            (goto-char previous)
          (save-restriction
            (widen)
            (goto-char (han/gptel--chat-end))
            (let ((beg (point))
                  (prefix (gptel-prompt-prefix-string)))
              (atomic-change-group
                ;; 始终追加，保留用户已经输入但尚未发送的草稿。
                (unless
                    (let ((stem (string-trim-right prefix)))
                      (and (not (string-empty-p stem))
                           (save-excursion
                             (skip-chars-backward " \t\r\n")
                             (let ((start (- (point) (length stem))))
                               (and (>= start (point-min))
                                    (or (= start (point-min))
                                        (eq (char-before start) ?\n))
                                    (not (get-text-property start 'gptel))
                                    (equal stem (buffer-substring-no-properties
                                                 start (point))))))))
                  (unless (bobp) (insert "\n\n"))
                  (insert prefix))
                (insert (han/gptel--rewrite-draft record))
                ;; 元数据保持文件尾部，光标留在补充问题处。
                (unless (eobp)
                  (save-excursion (insert "\n\n")))
                ;; 角色来自属性而不是标题；保证导入段属于 user。
                (remove-text-properties
                 beg (point) '(gptel nil front-sticky nil rear-nonsticky nil)))
              (setf (alist-get (plist-get record :id) han/gptel--rewrite-imports)
                    (copy-marker beg))))))
      (pop-to-buffer target)
      (message "解释草稿已准备好；补充问题后用 gptel-send 发送"))))

;; 第五部分：接入现有 gptel 流程。命名 advice 重复加载不会重复叠加；
;; require 的 feature 标记也避免普通启动时重复加载整个模块。
;; 这些内部回调接口与当前安装版本配套，升级后需验证：正常完成、续改、取消、
;; 网络/回调失败、旧回调迟到、源文变化、复制及接受/拒绝，不能只测聊天能否回复。
(advice-add 'gptel-request :around #'han/gptel--capture-rewrite)
(advice-add 'gptel--rewrite-callback :around #'han/gptel--rewrite-callback-guard)
(setq gptel-rewrite-default-action #'han/gptel-rewrite-ready)


(provide 'init-gptel-workflow)
;;; init-gptel-workflow.el ends here
