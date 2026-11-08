;;; init-isearch.el --- isearch settings -*- lexical-binding: t -*-
;;; Commentary:
;; 增量搜索与替换辅助；C-s/C-r 进入正向/反向搜索，局部键只在搜索中生效。

;;; Code:

;; Show number of matches while searching
;; Anzu 显示匹配计数，并接管原查询替换命令的展示；不改替换入口键位。
(when (maybe-require-package 'anzu)
  (add-hook 'after-init-hook 'global-anzu-mode)
  (setq anzu-mode-lighter "")
  (global-set-key [remap query-replace-regexp] 'anzu-query-replace-regexp)
  (global-set-key [remap query-replace] 'anzu-query-replace))

;; 搜索中的 DEL 编辑搜索文本；C-c C-o 将当前结果列入 Occur 列表。
(with-eval-after-load 'isearch
  ;; DEL during isearch should edit the search string, not jump back to the previous result
  (define-key isearch-mode-map [remap isearch-delete-char] 'isearch-del-char)

  ;; Activate occur easily inside isearch
  (when (fboundp 'isearch-occur)
    ;; to match ivy conventions
    (define-key isearch-mode-map (kbd "C-c C-o") 'isearch-occur)))

;; C-M-w 用光标处的完整符号替换正在搜索的文本。沿用当前正向或反向搜索。
(defun isearch-yank-symbol ()
  "在当前增量搜索中匹配光标处的完整符号。"
  (interactive)
  (let ((name (thing-at-point 'symbol t)))
    (if (null name)
        (ding)
      (let ((pattern (isearch-symbol-regexp name)))
        (setq isearch-string "" isearch-message ""
              isearch-regexp t isearch-yank-flag t)
        (isearch-process-search-string pattern pattern)))))

(define-key isearch-mode-map "\C-\M-w" 'isearch-yank-symbol)


;; 搜索中 C-RET 退出并到命中的另一端，便于接着选区或剪切。
(defun sanityinc/isearch-exit-other-end ()
  "Exit isearch, but at the other end of the search string.
This is useful when followed by an immediate kill."
  (interactive)
  (isearch-exit)
  (goto-char isearch-other-end))

(define-key isearch-mode-map [(control return)] 'sanityinc/isearch-exit-other-end)


(provide 'init-isearch)
;;; init-isearch.el ends here
