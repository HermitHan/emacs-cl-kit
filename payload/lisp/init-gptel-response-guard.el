;;; init-gptel-response-guard.el --- 识别流式回复是否完整 -*- lexical-binding: t -*-

;;;; 模块：gptel Responses 流式结束保护
;; 职责：区分正常完成、服务端未完成/失败、连接中断和缺少结束事件。
;; 流程：清空本轮标记 → 补读结束事件 → 核验收尾 → 原有聊天/改写回调。
;; 范围：只作用于 OpenAI Responses 后端及其 OAuth 子类的 curl 流式请求。
;; 普通增量文本、工具调用及成功后的 Diff/快捷键仍由原有 gptel 处理。
;; 修改导航：事件含义见 record-event；传输结束判定见 stream-cleanup。
;; 本模块不重试请求、不改源码、不设置 token 上限、不保存授权或完整请求日志。
;; 使用 gptel 内部接口；升级包后应重跑流式分块、失败恢复及正常完成测试。

(require 'cl-lib)
(require 'subr-x)
(require 'gptel)
(require 'gptel-openai-responses)

(defun han/gptel--response-error (info message)
  "在请求 INFO 中记录未完成原因 MESSAGE，供聊天和 Diff 显示。
只修改请求元数据；已经收到的聊天文本不会删除。"
  (plist-put info :han-response-error message)
  (plist-put info :status message)
  (plist-put info :error message))

(defun han/gptel--response-error-detail (data)
  "从事件 DATA 提取简短的错误代码和说明，兼容嵌套与平铺格式。"
  (let* ((err (or (plist-get data :error)
                  (plist-get (plist-get data :response) :error)
                  data))
         (code (and (listp err) (plist-get err :code)))
         (message (if (stringp err) err
                    (and (listp err) (plist-get err :message)))))
    (truncate-string-to-width
     (string-join (delq nil (list (and code (format "%s" code))
                                  (and message (replace-regexp-in-string
                                                "[\n\r\t]+" " " (format "%s" message)))))
                  "：")
     180 nil nil "…")))

(defun han/gptel--response-record-event (event data info)
  "将完整的 SSE 事件 EVENT/DATA 中的结束信息写入 INFO。
上游负责增量正文和正常完成用量；这里只补充缺失的异常状态。"
  (let ((response (plist-get data :response)))
    (pcase event
      ("response.completed"
       ;; 只有事件和响应状态一致才算完整；此前已报告的错误仍然保留。
       (when (equal (plist-get response :status) "completed")
         (plist-put info :han-response-terminal 'completed)))
      ("response.incomplete"
       (let* ((reason (plist-get (plist-get response :incomplete_details) :reason))
              (description
               (pcase reason
                 ("max_output_tokens" "生成达到长度限制（max_output_tokens）")
                 ("content_filter" "生成被内容过滤中止（content_filter）")
                 (_ (format "服务端未完成生成（%s）" (or reason "原因未提供"))))))
         (plist-put info :han-response-terminal 'incomplete)
         (plist-put info :han-incomplete-reason reason)
         (plist-put info :stop-reason "incomplete")
         (gptel--openai-responses-update-tokens (plist-get response :usage) info)
         (han/gptel--response-error info (concat "回复未完成：" description))))
      ((or "response.failed" "error")
       (plist-put info :han-response-terminal 'failed)
       (plist-put info :stop-reason "failed")
       (when (equal event "response.failed")
         (gptel--openai-responses-update-tokens (plist-get response :usage) info))
       (let ((detail (han/gptel--response-error-detail data)))
         (han/gptel--response-error
          info (concat "回复失败：" (if (string-empty-p detail)
                                      "服务端没有提供详细原因" detail))))))))

(defun han/gptel--response-parse-stream (original backend info)
  "补充 ORIGINAL 对 BACKEND/INFO 的流式结束解析，不改变返回正文。
只扫描上游本次已成功消耗的区间，避免网络分块导致漏读或重复计数。"
  (if (not (gptel-openai-responses-p backend))
      (funcall original backend info)
    (let* ((start (point))
           (text (funcall original backend info))
           (end (point)))
      (save-excursion
        (save-match-data
          (goto-char start)
          (while (re-search-forward "^event: *\\([^\r\n]+\\)\r?$" end t)
            (let ((event (match-string-no-properties 1)))
              (forward-line 1)
              (when (looking-at "data:")
                (forward-char 5)
                ;; 限定为已消费区间，半个 JSON 留待下一次数据到达。
                (save-restriction
                  (narrow-to-region (point) end)
                  (condition-case nil
                      (han/gptel--response-record-event event (gptel--json-read) info)
                    (json-error nil))))))))
      text)))

(defun han/gptel--response-reset (fsm)
  "清空 FSM 的上一轮流式结束标记，避免工具续轮误用旧完成状态。"
  (let ((info (gptel-fsm-info fsm)))
    (when (and (gptel-openai-responses-p (plist-get info :backend))
               (plist-get info :stream))
      (dolist (key '(:han-response-terminal :han-response-error
                     :han-incomplete-reason :han-next-input-created :stop-reason))
        (plist-put info key nil)))))

(defun han/gptel--response-next-input (info)
  "在 INFO 对应聊天的半截回复后保留下一条输入位置。
沿用正常完成时的分隔和提示前缀，不把错误说明写入聊天上下文。
仅处理已有正文的聊天；源代码 rewrite 和原地插入不受影响。"
  (let ((end (plist-get info :tracking-marker))
        (buffer (plist-get info :buffer)))
    (when (and (markerp end) (buffer-live-p buffer)
               (eq (marker-buffer end) buffer)
               (not (plist-get info :in-place))
               (not (plist-get info :han-next-input-created)))
      (with-current-buffer buffer
        (when (bound-and-true-p gptel-mode)
          (save-excursion
            (set-marker-insertion-type end nil)
            (goto-char end)
            (insert gptel-response-separator (gptel-prompt-prefix-string)))
          (plist-put info :han-next-input-created t))))))

(defun han/gptel--response-finish-error (process fsm)
  "让 PROCESS/FSM 以失败状态收尾一次，并释放请求资源。
失败先传给原有回调：聊天保留已收文本，rewrite 恢复旧候选或结束预览。
显式进入 ERRS，避免上游连接故障分支短暂经过 DONE。"
  (let* ((info (gptel-fsm-info fsm))
         (buffer (process-buffer process)))
    (unwind-protect
        (progn
          (when (and gptel-log-level (buffer-live-p buffer))
            (gptel-curl--log-response buffer info))
          (with-demoted-errors "gptel callback error: %S"
            (funcall (plist-get info :callback) nil info))
          (han/gptel--response-next-input info)
          (gptel--fsm-transition fsm 'ERRS))
      (setf (alist-get process gptel--request-alist nil 'remove) nil)
      (when (buffer-live-p buffer) (kill-buffer buffer)))))

(defun han/gptel--response-stream-cleanup (original process status)
  "核验 PROCESS 结束后再调用 ORIGINAL；STATUS 是进程结束通知。
HTTP 成功只代表传输成功，必须同时收到明确的 completed 事件。
其他后端及通常的 HTTP 错误响应仍由上游处理。"
  (let* ((fsm (cadr (assq process gptel--request-alist)))
         (info (and fsm (gptel-fsm-info fsm))))
    (if (not (and info (plist-get info :stream)
                  (gptel-openai-responses-p (plist-get info :backend))))
        (funcall original process status)
      (let ((exit-code (process-exit-status process))
            (http-status (plist-get info :http-status)))
        (cond
         ((not (zerop exit-code))
          (han/gptel--response-error
           info (format "回复未完成：连接中断（curl 退出码 %d）" exit-code)))
         ((plist-get info :han-response-error)
          ;; error 事件可能被上游转成另一种结构，统一恢复可读原因。
          (han/gptel--response-error info (plist-get info :han-response-error)))
         ((and (not (plist-get info :error))
               (or (null http-status) (member http-status '("200" "100")))
               (not (eq (plist-get info :han-response-terminal) 'completed)))
          (han/gptel--response-error
           info "回复可能不完整：连接已结束，但未收到正常完成事件")))
        (if (plist-get info :error)
            (han/gptel--response-finish-error process fsm)
          (funcall original process status))))))

;; 同名 advice 可重复加载而不叠加；不重定义包源码，也不改聊天或 SLIME 键位。
(advice-add 'gptel-curl-get-response :before #'han/gptel--response-reset)
(advice-add 'gptel-curl--parse-stream :around #'han/gptel--response-parse-stream)
(advice-add 'gptel-curl--stream-cleanup :around #'han/gptel--response-stream-cleanup)

(provide 'init-gptel-response-guard)
;;; init-gptel-response-guard.el ends here
