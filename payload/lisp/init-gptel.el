;;; init-gptel.el --- ChatGPT assistance for Common Lisp -*- lexical-binding: t -*-

;; 模块导览：本文件负责后端、模型、聊天外观与入口；
;; init-gptel-preferences.el 每次请求读取个人规则；
;; init-gptel-workflow.el 负责消息导航、Diff 审阅、续改、复制和解释草稿。
;; 这些模块不编译或执行生成的 Common Lisp；验证仍由你通过 SLIME 完成。
;; 快捷键以当前 buffer 的 C-h k 查询为准；配置里的 gptel-- 开头名称是内部接口，
;; 升级 gptel 后应回归测试预览/续改/失败恢复，不宜把相关保护简单删作冗余。

;; 独立的聊天/改写功能；保留现有 SLIME、补全、结构编辑和快捷键。
;; 安装由 package.el 单独完成，启动时不刷新软件源或自动安装包。
(require 'gptel)
(require 'gptel-openai-oauth)

;; 让现有包管理流程把 gptel 视为用户选装包，避免日后被当作孤立依赖清理。
(with-eval-after-load 'package
  (add-to-list 'package-selected-packages 'gptel))

;; 使用已配置的 ChatGPT 订阅授权后端；模型名是明确选择，并非自动追踪最新模型。
;; use-tools/tools 关闭工具调用：聊天不会因此自动读取所有 buffer 或执行任意命令。
;; 需要其他文件时显式 gptel-add 添加上下文；任务变更后检查并移除无关上下文。
;; 基础系统提示与偏好文件叠加；rewrite 自身仍负责限定输出为可替换的代码文本。
(setq gptel-backend (gptel-make-openai-oauth "ChatGPT subscription")
      gptel-model 'gpt-5.6-sol
      gptel-default-mode 'markdown-mode
      gptel-use-tools nil
      gptel-tools nil
      gptel-system-prompt
      "Help the user write Common Lisp. Distinguish it from Emacs Lisp and follow the project's packages, naming and style.
When explaining code, describe the relevant behavior and assumptions, and identify any missing context.
Keep changes within the requested scope and preserve public interfaces and dependencies unless the task requires a change.
The user compiles and evaluates code with SLIME. Only claim verification for checks that actually ran.")

;; 聊天显示：明确标注双方，回复使用适配当前主题的底色和侧边标记。
;; 前缀只用于阅读，gptel 仍用自己的文本属性区分模型消息角色。
(setf (alist-get 'markdown-mode gptel-prompt-prefix-alist) "## 你\n\n"
      (alist-get 'markdown-mode gptel-response-prefix-alist) "## GPT\n\n")

;; gptel-mode-hook 在启用/关闭聊天模式时调整外观；setq-local 和 hook 的 LOCAL=t
;; 让自动滚动、回复结束定位只作用于当前聊天，不把代码 buffer 一并滚到底部。
;; visual-line-mode 仅按窗口宽度显示折行，不向聊天文本插入真实换行。
(defun han/gptel-chat-appearance ()
  "在 gptel 聊天中启用角色高亮、折行和回复跟随，不修改聊天文本。"
  (interactive)
  (if gptel-mode
      (progn
        (setq-local gptel-highlight-methods '(margin face))
        ;; 避免重复运行时不断增加左边距。
        (unless gptel-highlight-mode
          (gptel-highlight-mode 1))
        (visual-line-mode 1)
        ;; 仅聊天 buffer 跟随流式回复，并在结束后移动到下一条输入处。
        (add-hook 'gptel-post-stream-hook #'gptel-auto-scroll nil t)
        (add-hook 'gptel-post-response-functions #'gptel-end-of-response nil t))
    (remove-hook 'gptel-post-stream-hook #'gptel-auto-scroll t)
    (remove-hook 'gptel-post-response-functions #'gptel-end-of-response t)
    (when gptel-highlight-mode
      (gptel-highlight-mode -1))))

(add-hook 'gptel-mode-hook #'han/gptel-chat-appearance)

;; rewrite 顶部提示条由 overlay 的 before-string 显示，不是源文件中的代码。
;; 终端标签留出文本边缘和分窗分隔线两列，修复右括号 ] 单独跑到下一行的问题。
;; 相对 right 的对齐表达式会随窗口宽度调整；GUI 保留上游像素布局。
(defun han/gptel--rewrite-label-padding (fsm)
  "为终端 rewrite 模型标签预留右边缘空位，避免右括号单独续行。
仅调整提示条的空白显示；图形界面继续使用 gptel 的像素对齐。"
  (unless (display-graphic-p)
    (when-let* ((ov (car-safe (plist-get (gptel-fsm-info fsm) :context)))
                ((overlayp ov))
                (status (overlay-get ov 'status))
                (gap (nth 2 status))
                (label (nth 3 status))
                ((and (stringp gap) (stringp label))))
      ;; 上游留一列；终端左右分窗还需避开分隔线占用的一列。
      ;; 使用相对 right 的显示属性，窗口调整大小后仍自动右对齐。
      (setf (nth 2 status)
            (propertize gap 'display
                        `(space :align-to (- right ,(+ 2 (string-width label))))))
      (overlay-put ov 'before-string (apply #'concat status)))))

;; 上游预览区会临时占用 RET 和多个 SLIME 的 C-c 键位；只保留鼠标入口。
;; 预览区不接管 SLIME 键位；审阅动作改由独立 Diff 窗口和鼠标菜单提供。
;; 同名 advice 挂到等待状态更新之后，仅修正显示空白，不改变请求或候选内容。
(with-eval-after-load 'gptel-rewrite
  (setq gptel-rewrite-actions-map
        (let ((map (make-sparse-keymap)))
          (define-key map [mouse-1] #'gptel--rewrite-dispatch)
          map))
  (advice-add 'gptel--rewrite-update-wait :after #'han/gptel--rewrite-label-padding))

;; M-x han/gptel-review 打开光标处预览菜单；用于源码内已有 rewrite overlay。
;; 常规流程则在生成完成后自动打开 Diff，按其中的 a/k/r/y/Y 等审阅快捷键操作。
(defun han/gptel-review ()
  "审阅光标所在位置的 AI 改写，不占用现有 CL 快捷键。"
  (interactive)
  (require 'gptel-rewrite)
  (call-interactively #'gptel--rewrite-dispatch))

;; 首次使用：M-x gptel-openai-oauth-login，完成浏览器中的订阅授权。
;; 解释代码：选区 -> M-x gptel-add -> M-x gptel。
;; 修改代码：选区 -> C-c r（gptel-rewrite）；生成后自动打开 Diff 审阅。
;; gptel-add 的上下文会用于后续请求，换任务时可在 gptel-menu 中检查/移除。
;; C-c r 是用户快捷键；与 SLIME 的 C-c C-r（求值选区）不同。
;; 保留原有 CL 快捷键，不接入自动求值或自动加载 Lisp image。
(global-set-key (kbd "C-c r") #'gptel-rewrite)

;; 核验订阅后端的流式结束事件，避免半截回复被标为正常完成。
;; 独立模块只补充响应状态处理；不改变模型、上下文、快捷键或审阅动作。
(require 'init-gptel-response-guard)

;; 每次请求读取已保存的个人偏好；聊天和 rewrite 共用。
(require 'init-gptel-preferences)

;; 聊天定位、改写审阅和解释草稿，独立维护。
(require 'init-gptel-workflow)

(provide 'init-gptel)
;;; init-gptel.el ends here
