# 用 Emacs 开发 Common Lisp

**简体中文** · [English](README.en.md)

这套个人配置把 Emacs、SLIME 和可选的 gptel 放在同一个工作环境中。你可以在 Mac 上用 SBCL，在 Linux 服务器上选 LispWorks，沿用同一套编辑键位。如果你第一次用 Emacs，先装到独立目录，跟着下面的练习让自己写的函数返回 `42`。装好后，这部分练习可以离线完成。

[一行安装](#一行安装) · [准备环境](#准备环境) · [并排试用](#并排试用) · [Emacs 入门](#在-emacs-里打开和编辑文件) · [Common Lisp 练习](#用-slime-编译第一个函数) · [Emacs Lisp 与配置](#用-emacs-lisp-理解自己的配置) · [gptel](#用-gptel-解释与改写代码) · [解决问题](#遇到问题时) · [学习资源](#继续学习)

## 一行安装

**GitHub Release 发布后可用。** 在装有下列依赖的 Mac 或 Linux 上，打开终端，从任意目录运行这一行即可安装到 `~/.emacs.d`。curl 将发行脚本直接交给 Bash，免去克隆仓库或手动保存脚本。

```sh
curl -fsSL https://github.com/HermitHan/emacs-cl-kit/releases/latest/download/emacs-portable-source.sh | bash
```

安装完成后运行 `emacs -nw`。如果已经有自己的 Emacs 配置，建议使用下面的[并排试用命令](#并排试用)指定独立目录。

## 准备环境

| 你想做什么 | 需要自己准备 | 安装后会得到什么 |
| --- | --- | --- |
| 打开、编辑文件 | GNU Emacs **29.1 或更高**、Bash（兼容 3.2）、Python **3.8+**、tar、curl 和首次在线安装的网络连接 | 一套已配置的编辑环境，含个人快捷键、其他语言模块和中文阅读指南 |
| 编译和执行 Common Lisp | 本机可运行的 SBCL，或已安装并获授权的 LispWorks **控制台**程序 | SLIME 编辑与 REPL 工作流、对应的 Swank 端代码 |
| 运行自己的 CL 项目 | 项目源码和项目用到的系统库；按项目需要另配 Quicklisp 等 | 可以直接在新环境中编译或加载你的文件；本教程的练习只用标准 CL |
| 使用 AI | 可用的 ChatGPT 订阅账户、网络和 curl；在新设备亲自完成授权 | gptel 聊天、选区改写、Diff 审阅和每次请求读取的风格偏好 |

从空机起步，可以先用系统包管理器安装 Emacs 和 SBCL，或使用对应平台的安装说明。终端运行 `emacs --version`、`python3 --version`；打算用 SBCL 再运行 `sbcl --version`。若服务器默认提供的 Emacs 太旧，准备另一个可执行文件，安装前在终端运行 `export EMACS=/完整路径/emacs` 指定安装器使用的版本，之后也用同一程序启动。[GNU Emacs 下载与安装](https://www.gnu.org/software/emacs/download.html) · [SBCL 下载](https://sbcl.org/platform-table.html)

**版本如何判断**　Linux Emacs **29.3** 已实测 SBCL 与 LispWorks 同时连接、编译求值；macOS Emacs **30.1** 已实测 SBCL。两端均测试过空目录离线安装、配置启动、主要快捷键和重复安装。完整配置的最低要求来自固定依赖（如 `affe`、`forge`、`ghub`），为 **29.1**；29.1、29.2 及其他未列版本尚无本项目端到端实测记录，28.x 及更早版本会被完整安装拒绝。`--config-only` 只复制配置，跳过依赖和启动检查。

## 并排试用

把目标目录传给 Bash，即可将配置装到独立目录。首次安装会联网下载固定版本的 Emacs 包。

```sh
curl -fsSL https://github.com/HermitHan/emacs-cl-kit/releases/latest/download/emacs-portable-source.sh | bash -s -- --target "$HOME/.emacs-portable-trial"
```

**首次启动。** 运行 `emacs --init-directory "$HOME/.emacs-portable-trial" -nw` 打开试用环境。图形版可省略 `-nw`。在 Emacs 中按 `M-:`，输入 `user-init-file` 并回车，可查看实际加载的文件。

**预演和选择后端。** 管道后用 `bash -s --` 将后续参数交给安装器，例如 `bash -s -- --dry-run` 预览默认目录的变更。首次安装时可在终端按名称或编号选择 Lisp。回车或等待默认 10 秒会优先选 SBCL，其次选其他可用实现。无人值守可加 `--non-interactive`，指定后端用 `--backend`。没有 Lisp 时也可安装编辑器。自动化脚本使用 Bash 或 zsh 时可在管道前设置 `set -o pipefail`，让下载错误也体现在退出状态中。

**先校验再运行。** 安装器会校验内嵌归档的 SHA-256。若希望先核对脚本本身，可从同一 Release 将 `emacs-portable-source.sh` 和 `emacs-portable-source.sh.sha256` 下载到同一目录，在 macOS 运行 `shasum -a 256 -c emacs-portable-source.sh.sha256`，在 Linux 运行 `sha256sum -c emacs-portable-source.sh.sha256`。校验通过后运行 `bash ./emacs-portable-source.sh`，同样支持 `--target` 等选项。[依赖来源与离线安装](docs/依赖与离线包.md)

### 在不同设备选择后端

重复安装会保留本机仍然可用的选择。想把试用环境的默认实现改成 Linux 已有的 `my-lispworks`，使用同一管道传入后端名称即可。

```sh
curl -fsSL https://github.com/HermitHan/emacs-cl-kit/releases/latest/download/emacs-portable-source.sh | bash -s -- --target "$HOME/.emacs-portable-trial" --backend my-lispworks --non-interactive
```

重启后生效。默认实现名保存在目标目录的 `var/slime-default-lisp`。启动时依次尝试有效的 `SLIME_DEFAULT_LISP`、已保存的选择、SBCL、首个可用实现。只想本次用 SBCL，可运行 `SLIME_DEFAULT_LISP=sbcl emacs --init-directory "$HOME/.emacs-portable-trial" -nw`。安装器还支持 `--timeout 秒数` 调整交互等待时间。

SLIME 会查找 PATH 中的 `sbcl`、`my-lispworks`、`lispworks`、`han-lispworks` 等控制台程序。LispWorks 映像在其他位置时，让安装器及之后启动的 Emacs 都继承 `LISPWORKS`，值为可执行文件的完整路径。shell 别名、含参数的整串命令和图形程序入口无法用作这里的控制台程序。[已有 Linux 环境的迁移步骤](docs/迁移到已有设备.md)

## 在 Emacs 里打开和编辑文件

`C-` 表示按住 Ctrl，`M-` 表示 Meta（常用 Alt，终端里也可先按 Esc 再按另一键），`RET` 是回车，`SPC` 是空格。`C-x C-f` 先按 Ctrl+x，再按 Ctrl+f。`M-x slime RET` 则是按 Meta+x，在屏幕底部的 **minibuffer** 输入命令名，再回车。如果输到一半想重新来，按 `C-g` 取消当前操作。

磁盘上的文件打开后由一个 **buffer** 承载，修改先进入 buffer，保存才写回文件。`*Messages*` 或 Lisp REPL 也都是 buffer，可以没有对应的文件。一个 **window** 是显示某个 buffer 的分屏，多个分屏可以看同一文件。每个 buffer 有自己的**主模式**（如 `lisp-mode`），还可同时启用 SLIME、Paredit 等**次模式**；同一个键在源码、REPL 和聊天中可能有不同用途。

| 要做的事 | 按键与效果 |
| --- | --- |
| 打开或新建文件 | `C-x C-f` 输入路径并回车。先挑一个已有、可写的练习目录。 |
| 移动、选取文字 | 箭头移动；`C-a` 行首，`C-e` 行尾。`C-SPC` 设置标记，再移动光标，二者之间是选区（region）。终端截走 `C-SPC` 时可用 `M-x set-mark-command`。 |
| 保存、撤销、退出 | `C-x C-s` 保存当前文件；这里 `M--` 撤销。`C-x C-c` 退出 Emacs，按提示处理尚未保存的文件。 |
| 换 buffer、分屏 | `C-x b` 输入 buffer 名；`C-x 2` 上下分屏，`C-x 3` 左右分屏，`M-o` 切换分屏。两个窗口时 `C-x 1` 留下当前窗口，原 buffer 仍可用。 |
| 查帮助 | `C-h t` 打开内置交互教程；`C-h k` 后按想查的键，可看到当前 buffer 的绑定；`C-h f` 查函数，`C-h v` 查变量，`C-h m` 查看当前模式。 |

**这套配置有自己的物理按键习惯。** `[`、`]` 输入圆括号，实体圆括号键输入方括号；Lisp 模式里的 Paredit 还会自动配对。第一次练习可以直接粘贴完整代码。这里 `C-w` 复制、`M-w` 剪切、`C-y` 粘贴；`TAB` 通常翻译为 `M-/`，Org 中保留折叠。要对照 GNU 教程练习原生键位，可以另开 `emacs -Q -nw`，按 `C-h t`。日常配置的全部按键翻译可看[入口文件](payload/init.el)和[中文阅读指南](payload/配置阅读指南.org)。

## 用 SLIME 编译第一个函数

Emacs 负责编辑；SBCL 或 LispWorks 在另一个进程中运行 Common Lisp。**SLIME** 在两者间传递代码和结果。**REPL** 是这个 Lisp 进程的交互入口，每次读入一个表达式，求值并显示结果。

1. 在试用 Emacs 中按 `C-x C-f`，到可写的练习目录新建 `tutorial.lisp`。粘贴以下定义，按 `C-x C-s` 保存。

   ```common-lisp
   (defun add-two (n)
     (+ n 2))
   ```

2. 按 `M-x slime RET`，等 REPL 出现（提示符通常含 `CL-USER`）。可输入 `(lisp-implementation-type)`，按 **`M-RET`**，查看这次连到 SBCL 还是 LispWorks。本配置在 REPL 中的普通 `RET` 用于换行。
3. 按 `C-x b`，输入 `tutorial.lisp` 回车，回到源码。把光标放在函数体内，按 **`C-c C-c`** 编译当前顶层定义，等编译完成。保存文件与把定义编译到运行中的 Lisp 是两个动作。
4. 在源码按 `C-c C-z` 进入相连的 REPL。输入 `(add-two 40)`，按 `M-RET`，应得到 **`42`**；再试 `(add-two -2)`，应得到 **`0`**。读表达式时看左边：`defun` 定义函数，`(n)` 声明一个参数，`(+ n 2)` 调用加法；函数返回最后一个表达式的值。
5. 想观察交互开发的效果，可以回源码把 `2` 临时改成 `3`，保存并重新 `C-c C-c`；同一个 REPL 此时对 `(add-two 40)` 会返回 `43`。练完改回 `2`，再保存和编译。

把同一个函数应用到多个数时，可以直接把函数交给 `mapcar`。在 REPL 输入 `(mapcar #'add-two '(-2 0 40))` 后按 `M-RET`，应得到 **`(0 2 42)`**。这里 `#'add-two` 取得函数，`'` 将后面的列表作为数据；`mapcar` 逐个调用该函数并收集返回值。

要查标准符号的参数与返回值，把光标放在 `mapcar` 上按 `C-c l`。SLIME 会打开 Common Lisp HyperSpec 中的符号条目；已设本地手册的用户会使用自己的镜像。

文件有多个定义时，`C-c C-k` 编译并加载整个源码文件；只求值选区用 `C-c C-r`。`M-x han/slime-start` 可按名称启动第二个实现。`M-x slime-list-connections` 后，在目标连接上按 `d` 选默认连接。**每个 Lisp 进程有自己的定义**；切到另一个后端练习时，回到源文件给它也编译一次。

## 用 Emacs Lisp 理解自己的配置

`tutorial.lisp` 交给 Common Lisp。编辑器的 `.el` 配置则由 **Emacs Lisp** 解释。按 `M-:`，输入下式并回车，屏幕底部应显示 **`3`**。这条练习无需启动 SLIME。

```emacs-lisp
(length '(a b c))
```

`'` 引用后面的列表，使 `a b c` 作为数据传给 `length`。还可用 `C-x b *scratch* RET` 切到草稿 buffer，粘贴表达式，把光标放在最后一个右括号**之后**，取消选区后按 `C-x C-e` 求值。一次求值作用于当前 Emacs 会话；想在下次启动也生效，要通过 Customize 保存选项，或把需要执行的代码写入启动时会加载的文件。

**练习一次只影响当前 buffer 的设置。** 用 `C-x C-f ~/tutorial-settings.txt RET` 打开一个新的练习 buffer，按 `M-:` 输入 `(setq-local fill-column 88)` 并回车。再按 `C-h v fill-column RET`，帮助页应显示本 buffer 的值为 `88`。它控制填充段落时的目标列宽；已经写好的文字不会自动重排。回练习 buffer 求值 `(kill-local-variable 'fill-column)` 即可让它重新使用默认值。

| 想读或修改什么 | 从哪里开始 |
| --- | --- |
| 启动与键位 | [early-init.el](payload/early-init.el) 先设置启动行为，[init.el](payload/init.el) 按次序加载模块并定义个人键位；两者都是正式配置。 |
| 语言工具和窗口 | [配置阅读指南](payload/配置阅读指南.org) 有模块地图。遇到 `require` 时可用 `M-x find-library` 找到对应库；`add-hook` 表示在进入某模式等事件发生时运行函数。 |
| 仅修改本机选项 | `M-x customize-option` 查一个选项，修改后选 `Apply and Save`。Customize 写到**安装目录**的 `custom.el`。用 `M-: user-emacs-directory RET` 可查该目录。 |
| AI 的长期偏好 | `M-x han/gptel-edit-preferences` 打开本机的 [gptel-preferences.md](payload/gptel-preferences.md)。可以改短函数、`LOOP`、注释风格等规则；保存后下次聊天和改写会重新读取。 |
| 维护便携模板 | 项目里的 `payload/` 是安装源。安装器把它复制到目标目录；编辑模板后，需重新安装才会改变目标。直接修改安装目录中的受管文件，更新时请核对本地差异。 |

## 用 gptel 解释与改写代码

**首次授权。** 在新设备执行 `M-x gptel-openai-oauth-login RET`，按提示用自己的账户完成登录。纯 SSH 环境可按 `M-:` 求值 `(gptel-openai-oauth-login nil 'device)`，用有浏览器的设备完成授权。每个独立配置目录单独保管授权。安装验证只检查模块、快捷键和本地生成的请求，不会使用真实账号发送 AI 请求。

**从提问到上下文。** 在 `tutorial.lisp` 里选中刚写的函数，执行 `M-x gptel-add`。再用 `M-x gptel` 打开聊天，确认聊天 buffer 名，输入“解释这个函数的参数和返回值，并给一个负数例子”，按 **`C-c RET`** 或 `M-x gptel-send` 发送。需要参考另一个 buffer 时，到那个 buffer 选中相关段落再 `gptel-add`；在 `M-x gptel-menu` 检查上下文，换项目时移除用完的内容。显式加入的代码会随适用请求交给后端。聊天中 `C-c j b` 到本条正文开头，末键换成 `p`、`n` 到上一条、下一条，`u`、`a` 按用户或 GPT 角色定位。

**从选区到 Diff。** 在源文件选中整个 `defun`，按 **`C-c r`**，输入“给这个函数补一个简短的文档字符串，保持接口和行为”，回车发起改写。这个键和 SLIME 的 **`C-c C-r`** 只差最后一个 Ctrl。生成后会打开差异窗口：

| Diff 键 | 可以做什么 |
| --- | --- |
| `y` / `Y` | 复制纯文本候选 / 首次原文。到练习用的 REPL 按 `C-y` 粘贴候选函数，`M-RET` 提交，再运行原来的两个测试。 |
| `r` | 保留未接受状态，基于当前候选补充要求，继续修改。 |
| `e` | 把改写要求、原文和候选带进聊天，生成可编辑的解释草稿，再由你发送。独立改写不会自动成为相邻聊天的历史。 |
| `a` / `k` | 接受候选并写入源码 buffer / 拒绝候选。接受后用 `C-x C-s` 保存。 |
| `s` / `q` / `?` | 回源码 / 关闭 Diff 窗口、保留候选 / 查看按键帮助。 |

本例选了整个 `defun`，复制出来可以独立求值。若只改了函数体内的一小段，里面的局部变量可能只在原函数里有意义。预先在 REPL 测试候选定义，会改变那个 Lisp 进程里正在运行的函数，即使源文件尚未接受修改。若最后按 `k` 拒绝，要让 REPL 也恢复原定义，回到源码的原函数再按 `C-c C-c`。

**语言。** 默认跟随本次提问或改写指令；只有代码等无法判断时，依次参考 `LC_ALL`、`LC_MESSAGES`、`LANG`，未设置或为 `C`、`POSIX` 时回退英语。想在本机固定中文或其他语言，运行 `M-x customize-option RET han/gptel-response-language RET`，选固定语言、填语言名并 `Apply and Save`。单次明确指定的语言优先。重写既有文本时保留原文语言，代码注释及文档字符串沿用项目约定；需要翻译可直接提出。Diff 按键提示和随附的偏好文本用中文。

## 遇到问题时

| 现象 | 如何定位 |
| --- | --- |
| 启动后看不到自定义设置 | 用 `M-: user-init-file RET` 核对实际路径。若原来有 `~/.emacs`、`~/.emacs.el` 或 XDG 配置，继续用 `--init-directory` 显式启动。启动信息可在 `C-x b *Messages* RET` 中查看。 |
| SLIME 找不到实现 | 在 Emacs 用 `M-: (executable-find "sbcl") RET` 核对它看到的 PATH。LispWorks 用户检查控制台映像及 `LISPWORKS`；SSH 登录后运行的 Emacs 使用服务器上的程序。 |
| REPL 提示 `ADD-TWO` 未定义 | 查看当前连接和包。在练习的新 REPL 使用 `CL-USER`，回 `tutorial.lisp` 用 `C-c C-c`，从同一源码 buffer 用 `C-c C-z` 再试。 |
| `RET` 只换行，快捷键与别人的不同 | REPL 提交用 `M-RET`，聊天发送用 `C-c RET`。分别在对应 buffer 按 `C-h k` 查询；终端没有传递组合键时可用 `M-x slime-repl-return` 或 `M-x gptel-send`。 |
| 安装提示缺少依赖或哈希不符 | 确认能够访问提示中的上游地址，网络恢复后可重试。若显式提供离线快照，请核对固定哈希。已有 ELPA 目录校验失败时用新的试用目录。 |
| gptel 能打开但没有回复 | 核对这台设备的授权、网络和 `curl`，再看状态和 `*Messages*`。本地模块加载成功与服务端是否接受这次请求分别检查。 |

## 更新、恢复与维护

升级时，对**同一个目标目录**再次运行对应的一行安装命令。受管文件仍与旧安装记录一致时会更新；遇到本机修改、删除，或目标已有不同内容的同名文件，安装器会列出冲突并停止。新设备可以省略 `--target` 安装到 `~/.emacs.d`。有既有配置时，独立目录也适合长期使用。

如果确实要接管旧目录，先退出使用该目录的 Emacs，将目录完整备份到外面。安装器会报告受管 Lisp 模块旁可能遮蔽源码的同名 `.elc`。先备份并移走列出的旧字节码，再预演。`--adopt --dry-run` 会列出将被接管的具体路径。核对差异后再决定是否使用 `--adopt`。

安装器在目标旁的 `目标名.portable-backups/` 保存事务恢复点，并打印对应的 `--restore` 命令。管道安装的恢复命令使用备份中的本地程序，断网也能执行。恢复前会核对文件的内容和权限。恢复范围是该事务涉及的受管文件；ELPA 包、历史记录和其他设备状态由用户保管。gptel 的授权保存在本机配置目录下的 `.cache/gptel-openai/`。

维护者运行 `python3 scripts/make-release.py --output 新目录` 可同时生成公开源码归档、单文件安装器和两份 SHA-256 校验文件。打包器只读取两份明确列出的发行文件清单。私用离线版另用 `--offline-bundle /路径/offline-packages.tar.gz` 在单独目录生成，打包时会验证固定哈希。用 `scripts/export-config.py` 可将日常配置中的受管文件导出到新目录，再与 `payload/` 比较。配置继承 Steve Purcell 的 BSD 两条款许可。[配置清单](scripts/config-files.txt) · [发行清单](scripts/release-files.txt) · [依赖](docs/依赖与离线包.md) · [第三方分发范围](docs/third-party-distribution.md) · [原配置](https://github.com/purcell/emacs.d) · [许可证](LICENSE)

## 继续学习

| 什么时候看 | 建议的读法 |
| --- | --- |
| 还在熟悉编辑器 | 先做 `C-h t` 的移动、打开文件和退出练习，再在手册里查 Buffers、Windows、Mark 三章。离线时 `C-h i` 可打开本机 Info 目录。[GNU Emacs Manual](https://www.gnu.org/software/emacs/manual/html_node/emacs/) |
| 想读懂或修改 `.el` | 从列表、求值和函数定义开始；读一小节就到 `*scratch*` 试一个表达式。[GNU《An Introduction to Programming in Emacs Lisp》](https://www.gnu.org/software/lispintro/) |
| 想系统学 Common Lisp | 先读第 2 章 REPL、第 5 章函数，再尝试第 3 章的小型数据库；按上面的编辑、编译、调用流程做例子。[Peter Seibel《Practical Common Lisp》](https://gigamonkeys.com/book/) |
| 想查某个 CL 函数的精确行为 | 用符号索引查 `mapcar` 或 `reduce`，看参数、返回值和例子；适合写代码时按需翻阅。[Common Lisp HyperSpec](https://www.lispworks.com/documentation/HyperSpec/Front/index.htm) |
| 想进阶使用 REPL、编译和调试器 | 从 Compilation、REPL、Debugger 章节入手，同时用 `C-h k` 比较本配置键位。[SLIME User Manual](https://slime.common-lisp.dev/doc/html/) |
| 想扩展 AI 上下文或理解请求范围 | 读上游的 Context、Rewriting 等说明；本配置采用固定版本，按键与本机命令帮助对应。[gptel 上游文档](https://github.com/karthink/gptel) |
