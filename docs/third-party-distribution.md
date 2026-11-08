# 第三方依赖与发行范围 / Third-party distribution

仓库根目录与配置目录保留了 Steve Purcell 原配置的版权和再发行条件。Emacs 扩展、手册、图标及音频各自有上游作者和条款。安装来源和版本见[依赖说明](依赖与离线包.md)。[原配置许可证](../payload/LICENSE)

The project retains the original copyright and redistribution terms for Steve Purcell’s configuration. Each Emacs extension and its documentation and media retain their individual upstream terms. See the [configuration license](../payload/LICENSE) and [dependency guide](依赖与离线包.md).

## Org 配置中的示例 / Examples in the Org configuration

Org 的 refile 设置和 `sanityinc/verify-refile-target` 改编自 Bernt Hansen 的教程。作者将其中的代码按 GPL 第 3 版或更新版本发布。安装目录中的 `COPYING.org-examples` 保留 GPL 正文，模块源码标注了出处及改动。The refile settings and target filter in `init-org.el` adapt Bernt Hansen’s GPL-3.0-or-later examples. The installed module records the attribution and modifications and ships alongside the full license. [原教程及许可 / Original tutorial and license](https://doc.norang.ca/org-mode.html) · [GPL text](../payload/COPYING.org-examples)

## 公开离线版 / Public offline edition

从 v0.1.1 起，离线版从 214 个锁定的公开 ELPA 归档构建。安装后可在对应包目录的 `upstream-notices/`、`upstream-source/` 和包原有的许可证文件中查看上游声明和随附源码，包括 MIT、Apache、GPL 以及 CSS 文档和 Company 图标的独立署名。个人迁移快照保留独立校验值。[公开构建脚本](../scripts/build-public-bundle.py) · [补充文件的来源与校验值](../deps/public-offline-notices.json)

The public offline edition is built from 214 pinned public ELPA archives. The build adds upstream notices and source materials, including the separate credits for the CSS documentation data and Company icons. Each supplemental file has a recorded source and SHA-256. The private migration snapshot has its own checksum. [Build script](../scripts/build-public-bundle.py) · [Supplemental files](../deps/public-offline-notices.json)

| 离线版的内容 / Offline contents | 使用时的区别 / What to expect |
| --- | --- |
| SLIME、gptel、Emacs Lisp 扩展 / SLIME, gptel and Emacs Lisp extensions | 包保留锁定版本。SLIME 的旧 CLISP 交叉引用文件省略；SBCL 和 LispWorks 使用各自的后端。The legacy CLISP cross-reference file is omitted. SBCL and LispWorks use their own backends. |
| 番茄钟、窗口、定位 / Timer, windows and location | 番茄钟使用本项目生成的提示音，窗口边界命令使用独立实现。要在 macOS 使用自动定位，需自行提供 `osx-location-helper` 指定的程序。The timer uses newly synthesized sounds. The window divider commands have an independent implementation. macOS geolocation requires a separately supplied helper. |
| 辅助资源 / Optional resources | 省略第三方扩展的预生成 Info 手册、演示图片、Haskell 通知图标、PureScript 和 RSpec 的可选 snippets 及 PSCi 开发工具。两本项目使用手册随包提供。The offline kit includes both project handbooks. Prebuilt third-party Info manuals, demo images, the Haskell notification logo, optional PureScript and RSpec snippets, and the PSCi development helper are omitted. |

## 个人迁移快照的核对记录 / Notes on the private migration snapshot

- **Haml、Sass、nix-buffer。** 参考快照中的代码对应上游提供的 MIT 声明。私用快照没有保留这三份完整声明。Each pinned upstream revision carries a full MIT notice which the personal snapshot omits. [haml-mode](https://github.com/nex3/haml-mode/blob/fe83c65c1f002f7c36480b758727c1afbad9a1b2/MIT-LICENSE) · [sass-mode](https://github.com/nex3/sass-mode/blob/247a0d4b509f10b28e4687cd8763492bca03599b/MIT-LICENSE) · [nix-buffer](https://github.com/shlevy/nix-buffer/blob/db57cda36e7477bdc7ef5a136357b971b1d4d099/LICENSE)
- **Dockerfile 与 Compose。** 两个模式对应的上游提交各附 Apache 2.0 正文。私用快照只保留各自的 Lisp 文件与包描述。The personal snapshot includes the Lisp and package descriptors from these two modes. Their pinned projects also ship the Apache 2.0 license text. [dockerfile-mode](https://github.com/spotify/dockerfile-mode/blob/7ce17e054eca4d56ca8bc1e4a6a0dbf58efd8d52/LICENSE) · [docker-compose-mode](https://github.com/meqif/docker-compose-mode/blob/abaa4f3aeb5c62d7d16e186dd7d77f4e846e126a/LICENSE)
- **Company 图标。** 公开离线版保留 `icons/` 下的 54 个 SVG，以及 CC BY 4.0 正文和 Microsoft 与贡献者的署名。个人迁移快照另含 24 张演示截图。The offline release includes the 54 SVG icons with their license and attribution. The private snapshot also contains 24 screenshots under `images/small/`. [Company icon attribution](https://github.com/company-mode/company-mode/blob/8d599ebc8a9aca27c0a6157aeb31c5b7f05ed0a3/icons/attribution.md)
- **声音与动画。** org-pomodoro 的三段 WAV 和 spinner 的两张 GIF 都能与固定提交逐字节匹配。核查时未找到专门说明这些资源授权范围的声明。The three recordings and two GIFs match the pinned upstream files byte for byte. The review did not establish separate permission for redistributing those assets. [org-pomodoro resources](https://github.com/lolownia/org-pomodoro/tree/3f5bcfb80d61556d35fc29e5ddb09750df962cc6/resources) · [spinner files](https://github.com/Malabarba/spinner.el/tree/bca794fa6f6b007292cdac9b0a850a3711986db5)
