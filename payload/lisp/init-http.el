;;; init-http.el --- Work with HTTP APIs -*- lexical-binding: t -*-
;;; Commentary:
;; HTTP API 手工调试工具：httprepl 交互会话与 restclient 请求文件。
;; 请求仅在调用相应发送命令时发生；本配置不会自动访问网络。
;;; Code:

(maybe-require-package 'httprepl)
;; httprepl 收到 image 类型的内容时，用 image-mode 显示返回的图片 buffer。
(with-eval-after-load 'httprepl
  (push '("image" . image) httprepl-content-type-alist)
  (push '(image . ((lambda (b) (with-current-buffer b
                                 (image-mode)
                                 b))))
        httprepl-content-type-middleware-alist))


;; .rest 文件自动使用 restclient-mode；M-x sanityinc/restclient 打开可复用的临时请求 buffer。
;; 该辅助命令只切换模式和显示窗口，不会自动发送其中的请求。
(when (maybe-require-package 'restclient)
  (add-auto-mode 'restclient-mode "\\.rest\\'")

  (defun sanityinc/restclient ()
    "Work with `rest' in the *restclient* buffer."
    (interactive)
    (with-current-buffer (get-buffer-create "*restclient*")
      (restclient-mode)
      (pop-to-buffer (current-buffer)))))


(provide 'init-http)
;;; init-http.el ends here
