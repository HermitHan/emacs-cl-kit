;;; init-csv.el --- CSV files -*- lexical-binding: t -*-
;;; Commentary:
;; CSV/分隔文本编辑支持，扩展名不区分 CSV 大小写。
;; csv-mode 的对齐、排序等命令可通过 M-x 查询；这里没有添加个人快捷键。
;;; Code:

(when (maybe-require-package 'csv-mode)
  (add-auto-mode 'csv-mode "\\.[Cc][Ss][Vv]\\'")

  ;; 接受逗号、分号、竖线和空格作为可用分隔符；因此含普通空格的文本也可能被分列。
  (setq csv-separators '("," ";" "|" " ")))

(provide 'init-csv)
;;; init-csv.el ends here
