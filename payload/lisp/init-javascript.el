;;; init-javascript.el --- Support for Javascript and derivatives -*- lexical-binding: t -*-
;;; Commentary:
;; JavaScript、TypeScript、JSON、CoffeeScript 编辑和交互运行辅助。
;; 默认普通 .js 使用内置 js-mode；js2-mode 仍作为可选编辑/检查来源保留。
;;; Code:

;; 保证可选模式及 Prettier 命令包可用；单独安装 prettier-js 不会自动开启保存格式化。
(maybe-require-package 'json-mode)
(maybe-require-package 'js2-mode)
(maybe-require-package 'typescript-mode)
(maybe-require-package 'prettier-js)


;; 文件识别与显示：.js/.es6 及其 ERB 文件使用 js-mode；缩进宽度为两个空格。
;; 状态栏中的模式名称简化为 JS/JSX，不改变主模式本身。
;;; Basic js-mode setup

(add-to-list 'auto-mode-alist '("\\.\\(js\\|es6\\)\\(\\.erb\\)?\\'" . js-mode))

(with-eval-after-load 'js
  (sanityinc/major-mode-lighter 'js-mode "JS")
  (sanityinc/major-mode-lighter 'js-jsx-mode "JSX"))

(setq-default js-indent-level 2)



;; JS2 检查策略：默认关闭重复的错误着色；如果 Flycheck 找不到适用检查器，再开启 JS2 自身检查。
;; 这里判断的是是否存在适用检查器，不等同于判定检查进程已经成功运行。
;; js2-mode

;; Change some defaults: customize them to override
(setq-default js2-bounce-indent-p nil)
(with-eval-after-load 'js2-mode
  ;; Disable js2 mode's syntax error highlighting by default...
  (setq-default js2-mode-show-parse-errors nil
                js2-mode-show-strict-warnings nil)
  ;; ... but enable it if flycheck can't handle javascript
  (autoload 'flycheck-get-checker-for-buffer "flycheck")
  (defun sanityinc/enable-js2-checks-if-flycheck-inactive ()
    (unless (flycheck-get-checker-for-buffer)
      (setq-local js2-mode-show-parse-errors t)
      (setq-local js2-mode-show-strict-warnings t)
      (when (derived-mode-p 'js-mode)
        (js2-minor-mode 1))))
  (add-hook 'js-mode-hook 'sanityinc/enable-js2-checks-if-flycheck-inactive)
  (add-hook 'js2-mode-hook 'sanityinc/enable-js2-checks-if-flycheck-inactive)

  (js2-imenu-extras-setup))

;; 带 node 解释器声明的脚本使用 js2-mode；这与单纯通过扩展名识别文件是两条规则。
(add-to-list 'interpreter-mode-alist (cons "node" 'js2-mode))

(with-eval-after-load 'js2-mode
  (sanityinc/major-mode-lighter 'js2-mode "JS2")
  (sanityinc/major-mode-lighter 'js2-jsx-mode "JSX2"))



;; 项目定义查找：只有 rg/ag 可用时启用 xref-js2，优先使用 rg。
;; 释放 JS 模式局部的 M-.，由现有全局 xref 键位接管；后端按 buffer 局部注册。
(when (and (or (executable-find "rg") (executable-find "ag"))
           (maybe-require-package 'xref-js2))
  (when (executable-find "rg")
    (setq-default xref-js2-search-program 'rg))
  (defun sanityinc/enable-xref-js2 ()
    (add-hook 'xref-backend-functions #'xref-js2-xref-backend nil t))
  (with-eval-after-load 'js
    (define-key js-mode-map (kbd "M-.") nil)
    (add-hook 'js-mode-hook 'sanityinc/enable-xref-js2))
  (with-eval-after-load 'js2-mode
    (define-key js2-mode-map (kbd "M-.") nil)
    (add-hook 'js2-mode-hook 'sanityinc/enable-xref-js2)))



;; CoffeeScript 缩进沿用 JS 的宽度，并补充 .coffee.erb 文件识别。
;;; Coffeescript

(when (maybe-require-package 'coffee-mode)
  (with-eval-after-load 'coffee-mode
    (setq-default coffee-tab-width js-indent-level))

  (when (fboundp 'coffee-mode)
    (add-to-list 'auto-mode-alist '("\\.coffee\\.erb\\'" . coffee-mode))))


;; Node 交互：js-comint 使用 node；C-x C-e 发送前一个表达式，C-c b 发送整个 buffer。
;; 本段只登记交互快捷键，实际发送需要可用的 Node/JS 交互会话。
;; Run and interact with an inferior JS via js-comint.el

(when (maybe-require-package 'js-comint)
  (setq js-comint-program-command "node")

  (defvar inferior-js-minor-mode-map (make-sparse-keymap))
  (define-key inferior-js-minor-mode-map "\C-x\C-e" 'js-send-last-sexp)
  (define-key inferior-js-minor-mode-map "\C-cb" 'js-send-buffer)

  (define-minor-mode inferior-js-keys-mode
    "Bindings for communicating with an inferior js interpreter."
    :init-value nil :lighter " InfJS" :keymap inferior-js-minor-mode-map)

  (dolist (hook '(js2-mode-hook js-mode-hook))
    (add-hook hook 'inferior-js-keys-mode)))


;; Skewer 浏览器交互启用时关闭本 buffer 的 Node 发送快捷键，避免两套发送目标混淆。
;; Alternatively, use skewer-mode

(when (maybe-require-package 'skewer-mode)
  (with-eval-after-load 'skewer-mode
    (add-hook 'skewer-mode-hook
              (lambda () (inferior-js-keys-mode -1)))))



;; 进入相关模式时把项目 node_modules/.bin 纳入 buffer 的程序查找路径，使用项目本地工具版本。
(when (maybe-require-package 'add-node-modules-path)
  (dolist (mode '(typescript-mode js-mode js2-mode coffee-mode))
    (add-hook (derived-mode-hook-name mode) 'add-node-modules-path)))


(provide 'init-javascript)
;;; init-javascript.el ends here
