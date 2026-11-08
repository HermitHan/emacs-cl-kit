;;; init-nxml.el --- Support for editing XML with NXML -*- lexical-binding: t -*-
;;; Commentary:
;; XML/XSD/SVG/plist 等文件统一使用内置 nxml-mode；另提供两种手动格式化命令。
;; 此模块调整 XML 文件，不涉及 Common Lisp 的结构编辑。
;;; Code:

;; 扩展名和文件开头的 XML 声明都可触发模式识别；xml-mode 也重定向到 nxml-mode。
;; 输入斜线时允许 nXML 自动补全结束标签。
(add-auto-mode
 'nxml-mode
 (concat "\\."
         (regexp-opt
          '("xml" "xsd" "sch" "rng" "xslt" "svg" "rss"
            "gpx" "tcx" "plist"))
         "\\'"))
(setq magic-mode-alist (cons '("<\\?xml " . nxml-mode) magic-mode-alist))
(fset 'xml-mode 'nxml-mode)
(setq nxml-slash-auto-complete-flag t)


;; M-x sanityinc/pp-xml-region 用 nXML 缩进选区或整份缓冲区。
;; 相邻标签之间仅有空格或制表符时补一个换行；含文字的节点保持行内内容。
(defun sanityinc/pp-xml-region (beg end)
  "换行并缩进 BEG 至 END 内的相邻 XML 标签。没有活动选区时处理全文。"
  (interactive "r")
  (save-excursion
    (unless (use-region-p)
      (setq beg (point-min)
            end (point-max)))
    (let ((limit (copy-marker end t)))
      (unwind-protect
          (progn
            (replace-regexp-in-region "\\(>[ \t]*\\)<" "\\1\n<" beg limit)
            (nxml-mode)
            (indent-region beg limit))
        (set-marker limit nil)))))


;; Integration with tidy for html + xml

;; M-x sanityinc/tidy-buffer-xml：以外部 tidy -xml 格式化选区或全文并替换原内容。
;; 需要 PATH 中有 tidy，错误输出到 *tidy-errors*；它可能重写标记，请按实际结果审阅。
(defun sanityinc/tidy-buffer-xml (beg end)
  "Run \"tidy -xml\" on the region from BEG to END, or whole buffer."
  (interactive "r")
  (unless (use-region-p)
    (setq beg (point-min)
          end (point-max)))
  (shell-command-on-region beg end "tidy -xml -q -i" (current-buffer) t "*tidy-errors*" t))


(provide 'init-nxml)
;;; init-nxml.el ends here
