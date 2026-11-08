# 第三方依赖与发行范围 / Third-party distribution

仓库根目录与配置目录保留了 Steve Purcell 原配置的版权和再发行条件。Emacs 扩展、手册、图标及音频各自有上游作者和条款。安装来源和版本见[依赖说明](依赖与离线包.md)。[原配置许可证](../payload/LICENSE)

The project retains the original copyright and redistribution terms for Steve Purcell’s configuration. Each Emacs extension and its documentation and media retain their individual upstream terms. See the [configuration license](../payload/LICENSE) and [dependency guide](依赖与离线包.md).

## Org 配置中的示例 / Examples in the Org configuration

Org 的 refile 设置和 `sanityinc/verify-refile-target` 改编自 Bernt Hansen 的教程。作者将其中的代码按 GPL 第 3 版或更新版本发布。安装目录中的 `COPYING.org-examples` 保留 GPL 正文，模块源码标注了出处及改动。The refile settings and target filter in `init-org.el` adapt Bernt Hansen’s GPL-3.0-or-later examples. The installed module records the attribution and modifications and ships alongside the full license. [原教程及许可 / Original tutorial and license](https://doc.norang.ca/org-mode.html) · [GPL text](../payload/COPYING.org-examples)

## 公开安装与离线迁移 / Public installs and private transfers

公开发行配置和安装工具时，将个人离线快照留在本地。自己在设备间复制配置时，可以使用已校验的私用快照。若另外发布离线依赖包，请从各对应版本收集适用的许可正文、署名、随包声明及所需源码，并逐项核对媒体和手册。

Keep the personal offline snapshot local when publishing the configuration and installer. A verified private copy can be used for transfers between your own devices. A separately published offline collection needs its own review of applicable licenses, credits, notices, source, manuals and media at the actual versions being shipped.

## 固定版本中的实例 / Examples at the pinned revisions

- **Haml、Sass、nix-buffer。** 参考快照中的代码对应上游提供的 MIT 声明。私用快照没有保留这三份完整声明。Each pinned upstream revision carries a full MIT notice which the personal snapshot omits. [haml-mode](https://github.com/nex3/haml-mode/blob/fe83c65c1f002f7c36480b758727c1afbad9a1b2/MIT-LICENSE) · [sass-mode](https://github.com/nex3/sass-mode/blob/247a0d4b509f10b28e4687cd8763492bca03599b/MIT-LICENSE) · [nix-buffer](https://github.com/shlevy/nix-buffer/blob/db57cda36e7477bdc7ef5a136357b971b1d4d099/LICENSE)
- **Dockerfile 与 Compose。** 两个模式对应的上游提交各附 Apache 2.0 正文。私用快照只保留各自的 Lisp 文件与包描述。The personal snapshot includes the Lisp and package descriptors from these two modes. Their pinned projects also ship the Apache 2.0 license text. [dockerfile-mode](https://github.com/spotify/dockerfile-mode/blob/7ce17e054eca4d56ca8bc1e4a6a0dbf58efd8d52/LICENSE) · [docker-compose-mode](https://github.com/meqif/docker-compose-mode/blob/abaa4f3aeb5c62d7d16e186dd7d77f4e846e126a/LICENSE)
- **Company 图标。** 78 个图标使用 CC BY 4.0，私用快照同时保留了许可正文以及 Microsoft 和贡献者的署名。The snapshot includes the icon license and attribution alongside the 78 icons. [Company icon attribution](https://github.com/company-mode/company-mode/blob/8d599ebc8a9aca27c0a6157aeb31c5b7f05ed0a3/icons/attribution.md)
- **声音与动画。** org-pomodoro 的三段 WAV 和 spinner 的两张 GIF 都能与固定提交逐字节匹配。核查时未找到专门说明这些资源授权范围的声明。The three recordings and two GIFs match the pinned upstream files byte for byte. The review did not establish separate permission for redistributing those assets. [org-pomodoro resources](https://github.com/lolownia/org-pomodoro/tree/3f5bcfb80d61556d35fc29e5ddb09750df962cc6/resources) · [spinner files](https://github.com/Malabarba/spinner.el/tree/bca794fa6f6b007292cdac9b0a850a3711986db5)
