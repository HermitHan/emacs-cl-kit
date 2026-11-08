;;; init-docker.el --- Work with Docker and its tools -*- lexical-binding: t -*-
;;; Commentary:
;; Docker 管理界面与 Dockerfile/Compose 编辑模式。
;; 管理命令需要 Docker CLI 及可连接的服务；加载配置不会启动/停止容器。
;;; Code:

;; M-x docker-images / docker-volumes / docker-networks / docker-containers 打开对应列表。
;; fullframe 让列表独占当前 frame，退出 tablist 时恢复原来的窗口布局。
(when (maybe-require-package 'docker)
  (fullframe docker-images tablist-quit)
  (fullframe docker-volumes tablist-quit)
  (fullframe docker-networks tablist-quit)
  (fullframe docker-containers tablist-quit))
;; 下面两个包提供文件编辑支持，与是否打开 Docker 管理列表相互独立。
(maybe-require-package 'dockerfile-mode)
(maybe-require-package 'docker-compose-mode)


(provide 'init-docker)
;;; init-docker.el ends here
