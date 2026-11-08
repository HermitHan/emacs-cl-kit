;;; init-css.el --- CSS/Less/SASS/SCSS support -*- lexical-binding: t -*-
;;; Commentary:
;; CSS、Sass、SCSS、Less 的编辑、内嵌语法、颜色预览和 Eldoc 提示。
;; 文件类型的 mode 提供编辑功能；浏览器预览和外部编译仍有各自运行条件。
;;; Code:

;; 在 CSS/HTML/Sass buffer 中启用 rainbow-mode，把颜色值显示成对应色块。
;;; Colourise CSS colour literals
(when (maybe-require-package 'rainbow-mode)
  (dolist (hook '(css-mode-hook html-mode-hook sass-mode-hook))
    (add-hook hook 'rainbow-mode)))


;; MMM 负责同一个文件中的多种语法：style 标签、CDATA 和行内 style 属性使用 css-mode。
;; 规则在 mmm-vars 加载后注册，作用于 HTML/NXML 的 HTML 或 ERB 文件。
;; init-ruby.el 也为 ERB 登记了 html-css 关联。
;;; Embedding in html
(require-package 'mmm-mode)
(with-eval-after-load 'mmm-vars
  (mmm-add-group
   'html-css
   '((css-cdata
      :submode css-mode
      :face mmm-code-submode-face
      :front "<style[^>]*>[ \t\n]*\\(//\\)?<!\\[CDATA\\[[ \t]*\n?"
      :back "[ \t]*\\(//\\)?]]>[ \t\n]*</style>"
      :insert ((?c css-tag nil @ "<style type=\"text/css\">"
                   @ "\n" _ "\n" @ "</style>" @)))
     (css
      :submode css-mode
      :face mmm-code-submode-face
      :front "<style[^>]*>[ \t]*\n?"
      :back "[ \t]*</style>"
      :insert ((?c css-tag nil @ "<style type=\"text/css\">"
                   @ "\n" _ "\n" @ "</style>" @)))
     (css-inline
      :submode css-mode
      :face mmm-code-submode-face
      :front "style=\""
      :back "\"")))
  (dolist (mode (list 'html-mode 'nxml-mode))
    (mmm-add-mode-ext-class mode "\\.r?html\\(\\.erb\\)?\\'" 'html-css)))




;; Sass 使用独立包；SCSS 优先使用 Emacs 内置模式，旧环境缺少它时才安装兼容包。
;; 当前内置 SCSS 不读取旧外部包的 scss-compile-at-save，故不再保留该无效设置。
;;; SASS and SCSS
(require-package 'sass-mode)
(unless (fboundp 'scss-mode)
  ;; Prefer the scss-mode built into Emacs
  (require-package 'scss-mode))



;; Less 同样优先内置模式；skewer-less-mode 用于与 Skewer 浏览器会话联动。
;; 加载模式不等于已经建立浏览器连接，预览仍需可用的 Skewer 会话。
;;; LESS
(unless (fboundp 'less-css-mode)
  ;; Prefer the scss-mode built into Emacs
  (require-package 'less-css-mode))
(when (maybe-require-package 'skewer-less)
  (add-hook 'less-css-mode-hook 'skewer-less-mode))



;; 普通 CSS buffer 也安装 Skewer 的 CSS 联动模式，供浏览器实时预览使用。
;; Skewer CSS
(when (maybe-require-package 'skewer-mode)
  (add-hook 'css-mode-hook 'skewer-css-mode))


;; Eldoc 在光标附近展示 CSS 属性/语法提示；新版 Emacs 的提示源是函数列表。
;; 这里以 buffer-local hook 追加提示，不覆盖 Flymake 等其他 Eldoc 来源。
;;; Use eldoc for syntax hints
(require-package 'css-eldoc)
(defun sanityinc/css-eldoc-documentation (&rest _args)
  "适配新版 Eldoc 的回调参数，并返回 CSS 提示。"
  (css-eldoc-function))

(defun sanityinc/css-eldoc-setup ()
  "将 CSS 提示加入 Eldoc，保留诊断等其他提示来源。"
  (require 'css-eldoc)
  (if (boundp 'eldoc-documentation-functions)
      (add-hook 'eldoc-documentation-functions #'sanityinc/css-eldoc-documentation nil t)
    (setq-local eldoc-documentation-function #'css-eldoc-function))
  (eldoc-mode 1))
(add-hook 'css-mode-hook #'sanityinc/css-eldoc-setup)


(provide 'init-css)
;;; init-css.el ends here
