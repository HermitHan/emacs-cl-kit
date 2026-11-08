;;; init-sql.el --- Support for SQL -*- lexical-binding: t -*-
;;; Commentary:
;; SQL 文件与交互式数据库会话的连接、格式化、帮助和执行计划。
;; SQLi 是 Emacs 中运行数据库命令行客户端的 buffer，与 Common Lisp 的 SLIME REPL 无关。
;; 这里保留现有 SQL 键位；数据库客户端、连接参数及格式化程序需另行准备。
;;; Code:

;; SQL 库加载后才修改 PostgreSQL 参数；忽略个人 psqlrc，保持 Emacs 可识别的提示符。
(with-eval-after-load 'sql
  ;; sql-mode pretty much requires your psql to be uncustomised from stock settings
  (add-to-list 'sql-postgres-options "--no-psqlrc"))

;; 在 SQL 源码中用 C-c C-z 跳到对应 SQLi buffer 末尾。
;; 只有活跃的 SQLi 进程才可复用；没有可用会话时交给内置选择/启动流程处理一次。
(defun sanityinc/pop-to-sqli-buffer ()
  "Switch to the corresponding sqli buffer."
  (interactive)
  ;; sql-buffer 常为名称字符串；sql-buffer-live-p 同时接受名称与对象。
  (unless (sql-buffer-live-p sql-buffer)
    (sql-set-sqli-buffer))
  ;; 选择流程没有得到有效会话时直接结束，避免递归重试。
  (when (sql-buffer-live-p sql-buffer)
    (pop-to-buffer sql-buffer)
    (goto-char (point-max))))

(with-eval-after-load 'sql
  (define-key sql-mode-map (kbd "C-c C-z") 'sanityinc/pop-to-sqli-buffer)
  ;; 安装了 dash-at-point 时才按 PostgreSQL 产品选择 psql 文档集。
  ;; 模式 hook 负责新 buffer，advice 负责后来切换数据库产品的情况。
  (when (package-installed-p 'dash-at-point)
    (defun sanityinc/maybe-set-dash-db-docset (&rest _)
      (when (eq sql-product 'postgres)
        (setq-local dash-at-point-docset "psql")))

    (add-hook 'sql-mode-hook 'sanityinc/maybe-set-dash-db-docset)
    (add-hook 'sql-interactive-mode-hook 'sanityinc/maybe-set-dash-db-docset)
    (advice-add 'sql-set-product :after 'sanityinc/maybe-set-dash-db-docset)))

;; SQLi 的命令历史保存在配置目录的 .sqli_history；此处只指定历史文件路径。
(setq-default sql-input-ring-file-name
              (locate-user-emacs-file ".sqli_history"))

;; See my answer to https://emacs.stackexchange.com/questions/657/why-do-sql-mode-and-sql-interactive-mode-not-highlight-strings-the-same-way/673
;; 为 SQLi 的交互输出补充 SQL 语法着色；Oracle 保留包自身处理。
(defun sanityinc/font-lock-everything-in-sql-interactive-mode ()
  (unless (eq 'oracle sql-product)
    (sql-product-font-lock nil nil)))
(add-hook 'sql-interactive-mode-hook 'sanityinc/font-lock-everything-in-sql-interactive-mode)


;; C-c C-f 调用 sqlformat 格式化 SQL；Emacs 包之外还需要其所配置的外部格式化程序。
(require-package 'sqlformat)
(with-eval-after-load 'sql
  (define-key sql-mode-map (kbd "C-c C-f") 'sqlformat))

;; Package ideas:
;;   - PEV
;; M-x sanityinc/sql-explain-region-as-json：分析选区，没有选区时使用当前段落。
;; 此命令会调用 psql，并执行 EXPLAIN ANALYZE：数据库会实际运行被分析语句。
;; 连接信息沿用 SQL/SQLi buffer；带 C-u 时将 JSON 复制到 kill-ring，否则显示结果。
;; 这是手动命令，不在打开文件或保存时运行；当前实现会同步等待外部命令结束。
(defun sanityinc/sql-explain-region-as-json (beg end &optional copy)
  "Explain the SQL between BEG and END in detailed JSON format.
This is suitable for pasting into tools such as
http://tatiyants.com/pev/.

When the prefix argument COPY is non-nil, do not display the
resulting JSON, but instead copy it to the kill ring.

If the region is not active, uses the current paragraph, as per
`sql-send-paragraph'.

Connection information is taken from the special sql-* variables
set in the current buffer, so you will usually want to start a
SQLi session first, or otherwise set `sql-database' etc.

This command currently blocks the UI, sorry."
  (interactive "rP")
  (unless (eq sql-product 'postgres)
    (user-error "This command is for PostgreSQL only"))
  (unless (use-region-p)
    (setq beg (save-excursion (backward-paragraph) (point))
          end (save-excursion (forward-paragraph) (point))))
  (let ((query (buffer-substring-no-properties beg end)))
    (with-current-buffer (if (sql-buffer-live-p sql-buffer)
                             sql-buffer
                           (current-buffer))
      (let* ((process-environment
              (append (list (concat "PGDATABASE=" sql-database)
                            (concat "PGHOST=" sql-server)
                            (concat "PGUSER=" sql-user))
                      process-environment))
             (args (list "--no-psqlrc"
                         "-qAt"
                         "-w"             ; Never prompt for password
                         "-E"
                         "-c" (concat "EXPLAIN (ANALYZE, COSTS, VERBOSE, BUFFERS, FORMAT JSON) " query ";")
                         ))
             (err-file (make-temp-file "sql-explain-json")))
        (with-current-buffer (get-buffer-create "*sql-explain-json*")
          (setq buffer-read-only nil)
          (delete-region (point-min) (point-max))
          (let ((retcode (apply 'call-process sql-postgres-program nil (list (current-buffer) err-file) nil args)))
            (if (zerop retcode)
                (progn
                  (json-mode)
                  (read-only-mode 1)
                  (if copy
                      (progn
                        (kill-new (buffer-substring-no-properties (point-min) (point-max)))
                        (message "EXPLAIN output copied to kill-ring."))
                    (display-buffer (current-buffer))))
              (with-current-buffer (get-buffer-create "*sql-explain-errors*")
                (let ((inhibit-read-only t))
                  (insert-file-contents err-file nil nil nil t))
                (display-buffer (current-buffer))
                (user-error "EXPLAIN failed")))))))))


;; SQL 与 Dash 文档查询的模式映射，等两个库都加载后才登记。
;; Submitted upstream as https://github.com/stanaka/dash-at-point/pull/28
(with-eval-after-load 'sql
  (with-eval-after-load 'dash-at-point
    (add-to-list 'dash-at-point-mode-alist '(sql-mode . "psql,mysql,sqlite,postgis"))))


;; 仅调整 SQL buffer 中分页符的显示，不改变文件内容。
(with-eval-after-load 'page-break-lines
  (add-to-list 'page-break-lines-modes 'sql-mode))

(provide 'init-sql)
;;; init-sql.el ends here
