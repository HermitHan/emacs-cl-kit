# Emacs CL Kit

[English](README.md) · **简体中文** · [中文使用手册](docs/使用手册.md)

Emacs CL Kit 是一套面向 macOS 和 Linux 的 Common Lisp 开发配置。在 Emacs 里改好一个函数，用 SLIME 把它编译到正在运行的 SBCL 或 LispWorks，就能立刻试一个输入，看看结果。要用 AI 帮忙时，可以让 gptel 解释选中的代码，或提出一份供你审阅的修改。

## 一行安装

先准备 **GNU Emacs 29.1 或更高版本**、Python 3.8+、Bash 和 curl。首次安装需要联网。要跟着下面的例子运行 Lisp，还需装好 **SBCL** 或已获授权的 **LispWorks 控制台程序**。发布时实测了 macOS 上的 Emacs 30.1 和 Linux 上的 Emacs 29.3。[获取 Emacs](https://www.gnu.org/software/emacs/download.html) · [获取 SBCL](https://sbcl.org/platform-table.html)

**新机器**可以直接在终端运行这一行，安装到 `~/.emacs.d`：

```sh
curl -fsSL https://github.com/HermitHan/emacs-cl-kit/releases/latest/download/emacs-portable-source.sh | bash
```

安装完成后，运行 `emacs -nw` 在终端打开 Emacs。首次安装若检测到多个 Lisp，可以输入名称或编号；新机器上直接回车或等 10 秒，有 SBCL 就会选它。

**已经有自己的 Emacs 配置？** 可以并排装一份试用。第一行安装到独立目录，成功后用第二行启动这份配置：

```sh
curl -fsSL https://github.com/HermitHan/emacs-cl-kit/releases/latest/download/emacs-portable-source.sh | bash -s -- --target "$HOME/.emacs-portable-trial"
emacs --init-directory "$HOME/.emacs-portable-trial" -nw
```

**目标机器不能联网？** 在能联网的机器上下载 `emacs-portable-offline.sh` 和同名 `.sha256` 文件，一起带到目标机，校验后运行 `bash ./emacs-portable-offline.sh`。目标机需备好 Emacs、Python、Bash 和要用的 Lisp 实现。发布页列有两种安装器、校验文件和在线安装器的备用下载地址。[下载与校验](https://github.com/HermitHan/emacs-cl-kit/releases/latest)

## 编译一个函数，在 REPL 里试它

下文中，`C-` 表示按住 Ctrl，`M-` 表示 Meta（通常是 Alt；终端里也可以先按一下 Esc，再按下一个键），`RET` 是回车。例如 `C-c C-c` 要按两次 Ctrl+c。输错命令时，按 `C-g` 取消。

1. **写源码。** 在 Emacs 按 `C-x C-f`，输入一个新的练习文件名，例如 `~/cl-kit-demo.lisp`，按回车。粘贴以下函数，按 `C-x C-s` 保存。如果手打，注意这套配置用方括号键输入圆括号，Paredit 会自动补上右括号。

   ```common-lisp
   (defun add-two (n)
     (+ n 2))
   ```

2. **启动 Lisp。** 按 `M-x`，输入 `slime` 并回车。等到出现类似 `CL-USER>` 的提示符。这个窗口里的 **REPL** 连接着你的 Lisp 进程，可以输入表达式、查看返回值。
3. **编译函数。** 按 `C-x b`，输入 `cl-kit-demo.lisp` 并回车，切回刚才的源码。把光标放进函数，按 `C-c C-c`。现在运行中的 Lisp 已经有了 `add-two` 的定义。
4. **调用函数。** 按 `C-c C-z` 切到相连的 REPL，输入 `(add-two 40)`，按 **`M-RET`** 提交，应该看到 **`42`**。在这套配置的 REPL 中，单按回车是换行。

回到源码，把 `2` 临时改成 `3`，先只保存。在原来的 REPL 再算一次 `(add-two 40)`，结果仍是 `42`。回到函数内按 `C-c C-c` 重新编译，再求值才会得到 `43`。保存改变的是磁盘上的文件，编译改变的是当前 Lisp 进程中的定义。做完练习，把函数改回加二，保存并编译。

## 编辑时常用的按键

| 在哪里 | 按什么 | 做什么 |
| --- | --- | --- |
| 编辑文本 | `C-w` / `M-w` / `C-y` | 复制选区 / 剪切选区 / 粘贴 |
| 编辑文本 | `M--` | 撤销（按住 Meta 再按减号） |
| 编辑代码 | `TAB` | 请求补全；Org 中保留折叠 |
| Lisp 源码 | `C-c C-c` / `C-c C-k` | 编译当前定义 / 编译并加载整个文件 |
| Lisp 源码 | `C-c C-r` / `C-c r` | 求值选区 / 用 AI 改写选区；留意最后一个键是否按住 Ctrl |

不知道一个键在当前位置会做什么时，按 `C-h k`，再按想查的键。

## 用 gptel 解释或改写这个函数

如果要用自己的 ChatGPT 订阅，在 Emacs 执行 `M-x gptel-openai-oauth-login`，按提示登录。安装完成后，上面的 Lisp 练习可以离线进行；纯 SSH 环境的授权步骤见手册。

**让它解释。** 回到源码，把光标放在 `(defun` 的左括号前，按 `C-SPC` 设置起点，再按 `C-M-f` 选中整个函数。运行 `M-x gptel-add` 把选区加入上下文。用 `M-x gptel` 打开聊天（提示聊天名称时可直接回车），输入“如果传入一个负数，这个函数会返回什么？举个例子”，按 **`C-c RET`** 发送。需要它一起读另一个文件时，到那个文件选中有关代码，再运行 `gptel-add`。

**让它改写。** 回到源码，选中整个定义，按 **`C-c r`**，输入“补一个简短的中文文档字符串，保持接口和行为”，回车。生成后会自动打开差异窗口。按 `a` 接受并写回源码缓冲区，`k` 拒绝，`r` 补充要求继续改。想先测试就按 `y` 复制候选代码，到 REPL 用 `C-y` 粘贴、`M-RET` 求值。接受后用 `C-x C-s` 保存，再用 `C-c C-c` 更新运行中的函数。

想让 AI 记住你的编码风格，可以用 `M-x han/gptel-edit-preferences` 编辑偏好。保存后，下一次聊天和改写都会读取。

## 继续使用

- **学 Emacs 和 Lisp。** 从分屏、求值和配置变量的小练习开始，随后可按问题查阅双后端、gptel、故障排查和学习资源。[中文使用手册](docs/使用手册.md)
- **把自己的设置带到另一台机器。** 先并排试用，再决定是否接管已有配置；SSH、LispWorks 和离线依赖各有说明。[迁移到已有设备](docs/迁移到已有设备.md) · [依赖与离线包](docs/依赖与离线包.md)
- **读配置源码。** 个人键位集中在 `init.el`，语言和工具分模块放在 `lisp/`。随安装附带的中文指南说明了各模块的用途和加载顺序。[配置阅读指南](payload/配置阅读指南.org) · [init.el](payload/init.el)

这套配置源自 Steve Purcell 的 emacs.d，保留原项目的 BSD 两条款许可。第三方扩展和资源遵循各自的许可。[上游项目](https://github.com/purcell/emacs.d) · [许可证](LICENSE) · [第三方说明](docs/third-party-distribution.md)
