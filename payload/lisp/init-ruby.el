;;; init-ruby.el --- Support for the Ruby language -*- lexical-binding: t -*-
;;; Commentary:
;; Ruby 源码、REPL、测试、文档以及 ERB/EJS 模板支持。
;; 以下设置延续原有 Ruby 工作流；它们不改变 Common Lisp 的 SLIME 或 Paredit 键位。
;;; Code:

;; 基本识别：为 Gem 规范、Rack/Rails 辅助文件等选择 ruby-mode，锁文件用 conf-mode。
;; 关闭自动插入 encoding 注释；subword-mode 让单词移动识别驼峰名称的组成部分。
;;; Basic ruby setup
(require-package 'ruby-hash-syntax)

(add-auto-mode 'ruby-mode
               "\\.rxml\\'"
               "\\.rjs\\'" "\\.irbrc\\'" "\\.pryrc\\'" "\\.builder\\'" "\\.ru\\'"
               "\\.gemspec\\'" "Kirkfile\\'")
(add-auto-mode 'conf-mode "Gemfile\\.lock\\'")

(setq-default
 ruby-use-encoding-map nil
 ruby-insert-encoding-magic-comment nil)

(add-hook 'ruby-mode-hook 'subword-mode)

(with-eval-after-load 'page-break-lines
  (add-to-list 'page-break-lines-modes 'ruby-mode))

;; RSpec 测试操作由 rspec-mode 提供；此处只保证包存在，不自动运行测试。
(require-package 'rspec-mode)


;; Brewfile 的语法类似 Ruby，因此派生 ruby-mode；打开 Brewfile 时自动使用。
(define-derived-mode brewfile-mode ruby-mode "Brewfile"
  "A major mode for Brewfiles, used by homebrew-bundle on MacOS.")

(add-auto-mode 'brewfile-mode "Brewfile\\'")


;; Ruby REPL：替换已有 ruby-load-file 操作的实现，默认发送当前文件。
;; 发送前调用 save-some-buffers；带 C-u 或当前 buffer 没有文件时仍提示选择文件。
;;; Inferior ruby
(require-package 'inf-ruby)
(with-eval-after-load 'inf-ruby
  (defun sanityinc/ruby-load-file (&optional choose-file)
    (interactive "P")
    (if (or choose-file (not buffer-file-name))
        (call-interactively 'ruby-load-file)
      (save-some-buffers)
      (ruby-load-file buffer-file-name)))
  (define-key inf-ruby-minor-mode-map [remap ruby-load-file] 'sanityinc/ruby-load-file))



;; Ruby 模式键位：F7 运行当前测试，Shift-F7 运行当前 buffer 的编译/执行流程。
;; M-x rake 是 ruby-compilation-rake 的别名，实际执行依赖本机 Ruby/项目环境。
;;; Ruby compilation
(require-package 'ruby-compilation)

(with-eval-after-load 'ruby-mode
  (define-key ruby-mode-map [S-f7] 'ruby-compilation-this-buffer)
  (define-key ruby-mode-map [f7] 'ruby-compilation-this-test))

(with-eval-after-load 'ruby-compilation
  (defalias 'rake 'ruby-compilation-rake))



;; Robe 为 Ruby 编辑提供项目查询等能力；进入 Ruby 模式时开启，查询依赖可用 Ruby 会话。
;;; Robe
(when (maybe-require-package 'robe)
  (with-eval-after-load 'ruby-mode
    (add-hook 'ruby-mode-hook 'robe-mode)))



;; M-x ri 调用 yari 查询 Ruby 文档，需要可用的 RI 文档数据。
;;; ri support
(require-package 'yari)
(defalias 'ri 'yari)



;; Bundler 集成提供项目依赖工具命令；加载本配置不会自动执行 bundle install。
(require-package 'bundler)


;; YARD 辅助 Ruby 文档注释；进入 Ruby 模式启用，并隐藏其次模式指示以节省状态栏空间。
(when (maybe-require-package 'yard-mode)
  (add-hook 'ruby-mode-hook 'yard-mode)
  (with-eval-after-load 'yard-mode
    (diminish 'yard-mode)))


;; 模板混合编辑：MMM 把 ERB 的 Ruby 片段与外围 HTML/JS/YAML 等语法分开处理。
;; 这里是原有规则注册，不会生成或编译模板。HTML 中的 CSS 关联也在 init-css.el 登记，
;; JavaScript 规则由相应包提供；本轮保留加载顺序与重复关联，避免改动模板行为。
;;; ERB
(require-package 'mmm-mode)

(require 'derived)

;; 为给定主模式登记 .erb 规则；模式 hook 到实际进入该模式时才加载 mmm-erb。
(defun sanityinc/set-up-mode-for-erb (mode)
  (add-hook (derived-mode-hook-name mode) (lambda () (require 'mmm-erb)))
  (mmm-add-mode-ext-class mode "\\.erb\\'" 'erb))

(dolist (mode '(html-mode html-erb-mode nxml-mode))
  (sanityinc/set-up-mode-for-erb mode)
  (mmm-add-mode-ext-class mode "\\.r?html\\(\\.erb\\)?\\'" 'html-js)
  (mmm-add-mode-ext-class mode "\\.r?html\\(\\.erb\\)?\\'" 'html-css))

(mapc 'sanityinc/set-up-mode-for-erb
      '(coffee-mode js-mode js2-mode js3-mode markdown-mode textile-mode))

(mmm-add-mode-ext-class 'html-erb-mode "\\.jst\\.ejs\\'" 'ejs)

(add-auto-mode 'html-erb-mode "\\.rhtml\\'" "\\.html\\.erb\\'")
(add-to-list 'auto-mode-alist '("\\.jst\\.ejs\\'"  . html-erb-mode))

(mmm-add-mode-ext-class 'yaml-mode "\\.yaml\\(\\.erb\\)?\\'" 'erb)
(sanityinc/set-up-mode-for-erb 'yaml-mode)

(dolist (mode (list 'js-mode 'js2-mode 'js3-mode))
  (mmm-add-mode-ext-class mode "\\.js\\.erb\\'" 'erb))



;; 以下 SQL heredoc 识别方案被整体注释，目前没有启用，保留作参考。
;; Ruby - my convention for heredocs containing SQL

;; (require-package 'mmm-mode)
;; (eval-after-load 'mmm-mode
;;   '(progn
;;      (mmm-add-classes
;;       '((ruby-heredoc-sql
;;          :submode sql-mode
;;          :front "<<-?[\'\"]?\\(end_sql\\)[\'\"]?"
;;          :save-matches 1
;;          :front-offset (end-of-line 1)
;;          :back "^[ \t]*~1$"
;;          :delimiter-mode nil)))
;;      (mmm-add-mode-ext-class 'ruby-mode "\\.rb\\'" 'ruby-heredoc-sql)))

;; (add-to-list 'mmm-set-file-name-for-modes 'ruby-mode)



(provide 'init-ruby)
;;; init-ruby.el ends here
