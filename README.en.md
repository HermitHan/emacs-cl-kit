# Portable Emacs for Common Lisp

[简体中文](README.md) · **English**

Use Emacs on macOS or Linux to edit a Lisp function, compile it into a running SBCL or LispWorks session, and try it immediately. Optional gptel chat and rewrite commands work alongside SLIME. The Common Lisp exercises below run offline once setup is complete.

[One-line install](#one-line-install) · [Set up a new machine](#set-up-a-new-machine) · [Learn the editor](#learn-the-editor) · [Run your first Common Lisp function](#run-your-first-common-lisp-function) · [Try Emacs Lisp](#try-emacs-lisp) · [Use gptel](#use-gptel) · [Make it yours](#make-it-yours) · [Troubleshoot](#troubleshoot) · [Find a good reference](#find-a-good-reference)

## One-line install

**Available once the GitHub Release is published.** On a Mac or Linux machine with the prerequisites below, run this in any directory to install into `~/.emacs.d`. curl streams the installer directly to Bash and the installer fetches its pinned dependencies.

```sh
curl -fsSL https://github.com/HermitHan/emacs-cl-kit/releases/latest/download/emacs-portable-source.sh | bash
```

Start Emacs with `emacs -nw`. If you already have an Emacs configuration, use the [separate trial directory](#install-in-a-separate-directory) below.

## Set up a new machine

### What you supply

| To do this | Prepare on the machine where Emacs will run |
| --- | --- |
| Launch the full configuration | GNU Emacs **29.1 or later**, Bash (macOS Bash 3.2 works), Python **3.8+**, `tar`, curl and internet access for the first online installation. |
| Compile Common Lisp | Install SBCL, or provide an executable LispWorks console image and its license. Either one is enough for this tutorial. |
| Use your existing projects | Bring their source, data, and any required libraries. Install Quicklisp separately if your project uses it. |
| Use gptel | Have `curl`, a network connection and your own account for the configured ChatGPT subscription backend. Authorize each new configuration directory. You can skip this step for the Lisp exercises. |

If you're starting from scratch, install the Emacs and SBCL packages for your operating system, or follow the platform instructions from their publishers. In the shell, run `emacs --version`, `python3 --version` and, for SBCL, `sbcl --version`. Some Linux distributions ship an older Emacs. If several versions are installed, run `export EMACS=/absolute/path/to/emacs` before the install command and launch that same executable afterwards. [GNU Emacs downloads](https://www.gnu.org/software/emacs/download.html) · [SBCL downloads](https://sbcl.org/platform-table.html)

**Compatibility.** The oldest full installation tested is **Emacs 29.3 on Linux**, with SBCL and LispWorks connected simultaneously. **Emacs 30.1 on macOS** was tested with SBCL. These checks cover startup, compilation and evaluation, key bindings, gptel chat/rewrite request preparation, and a repeat install. They run without a live AI request. Pinned dependencies including Affe, Forge and Ghub require 29.1. Versions 29.1 and 29.2 and other unlisted releases have not been tested end to end. The installer checks for 29.1 or later and sets no upper limit. The 26.1 check inherited in `init.el` only applies to the base configuration.

### Install in a separate directory

Pass the target directory after `bash -s --` to keep this setup alongside your existing configuration.

```sh
curl -fsSL https://github.com/HermitHan/emacs-cl-kit/releases/latest/download/emacs-portable-source.sh | bash -s -- --target "$HOME/.emacs-portable-trial"
```

Launch the trial with `emacs --init-directory "$HOME/.emacs-portable-trial" -nw`. Omit `-nw` to use a graphical frame. Evaluate `user-init-file` with `M-:` inside Emacs to see which configuration it loaded.

**Preview and choose a backend.** For example, end the pipeline with `bash -s -- --dry-run` to preview changes to the default directory. During an interactive installation, choose a detected Lisp by name or number at the terminal prompt. Press Return or wait **10 seconds** to accept SBCL when available, then the first available alternative. Use `--non-interactive` for unattended installs and `--backend` for an explicit choice. You can also use the editor without a Lisp executable. In Bash or zsh automation, run `set -o pipefail` before the pipeline to propagate curl failures.

**Optional verification before execution.** The installer checks the SHA-256 of its embedded archive. To check the script itself first, download `emacs-portable-source.sh` and `emacs-portable-source.sh.sha256` from the same release into one directory. Run `shasum -a 256 -c emacs-portable-source.sh.sha256` on macOS or `sha256sum -c emacs-portable-source.sh.sha256` on Linux. After verification, run `bash ./emacs-portable-source.sh` with the same installer options. [Dependencies and offline installation (Chinese)](docs/依赖与离线包.md)

## Learn the editor

A **buffer** holds the text you're editing. A file buffer keeps its changes in memory until you save. Other buffers hold a REPL, help text or a chat. A **window** is a pane showing a buffer. Switching panes keeps both buffers open. The **minibuffer** at the bottom asks for a filename, buffer name or command. Press Return to confirm or `C-g` to cancel.

In key notation, `C-` means hold Control and `M-` means Meta, usually Alt or Option. In terminals you can often press and release Escape, then press the next key for Meta. `RET` is Return and `SPC` is Space. For `C-x C-f`, press Control-x and then Control-f. For `M-x slime RET`, press Meta-x, type the command name, then press Return.

| Task | Keys to try |
| --- | --- |
| Open or create a file / save it | `C-x C-f` / `C-x C-s` |
| Switch to a named buffer / switch panes | `C-x b` / `M-o` |
| Select text | Put **point** (the cursor) at one end, press `C-SPC` to set the **mark**, and move to the other end. The span between them is the **region**. |
| Copy / cut / paste the region | Physical `C-w` / `M-w` / `C-y`. The first two are personal remappings. |
| Undo an edit / cancel an unfinished command | `M--` / `C-g` |
| Find help for a key / command / variable | `C-h k` then the key / `C-h f` then a command / `C-h v` then a variable |
| Start the built-in tutorial / exit Emacs | `C-h t` / `C-x C-c`. Read any save prompts before exiting. |

Try `C-h k` followed by the physical key `C-w` in a file buffer. The help buffer tells you which command your current mode will run. Manuals typically show Emacs defaults. This configuration also swaps square and round bracket input, maps physical `TAB` to `M-/` for completion, and preserves outline folding on `TAB` in Org buffers. Use `M-\` for the original Tab event. Paredit helps keep parentheses balanced in Lisp buffers. You can paste the complete Lisp examples below verbatim. [Personal key translations](payload/init.el) · [Configuration guide (Chinese)](payload/配置阅读指南.org)

## Run your first Common Lisp function

1. Press `C-x C-f`, enter `~/tutorial.lisp`, and press Return. Use a different scratch filename if you already have a file of that name. Paste this definition and save with `C-x C-s`.

   ```lisp
   (defun add-two (n)
     (+ n 2))
   ```

   `defun` names the function, `(n)` lists its parameter, and `(+ n 2)` returns the sum. In a Lisp call, the name of the operation comes first.

2. Run `M-x slime RET` and wait for a Lisp prompt such as `CL-USER>`. A **REPL** reads an expression, evaluates it and prints the result. For this exercise, keep the new session in its initial Common Lisp user package.
3. Use `C-x b tutorial.lisp RET` to return to the source. Place point inside `add-two` and press `C-c C-c`. SLIME compiles the definition and loads it into the connected Lisp process.
4. Press `C-c C-z` to visit its REPL. Enter `(add-two 40)` and press **`M-RET`**. Expect **`42`**. Try `(add-two -2)` the same way and expect **`0`**. In this REPL an ordinary Return inserts a newline, which lets you finish editing a multiline expression before evaluating it.

The file on disk and the function in the running Lisp have separate lifetimes. Change `2` to `3`, save, compile again with `C-c C-c`, then evaluate `(add-two 40)` to get `43`. Restore `2`, save and compile again for the remaining exercises. Restarting the Lisp process clears definitions from this session. To compile and load the whole source file, use `C-c C-k`. To evaluate an active source region, use `C-c C-r`.

With the original `(+ n 2)` definition loaded again, evaluate `(mapcar #'add-two '(-2 0 40))` in the REPL. Expect **`(0 2 42)`**. The `#'add-two` argument supplies the function, and the quote before `(-2 0 40)` supplies a literal list. `mapcar` calls the function on each element and collects the results in order.

With point on `mapcar`, press `C-c l` to open its Common Lisp HyperSpec entry. SLIME uses your configured local copy if available, otherwise this configuration opens the HTTPS manual.

### Work with more than one Lisp

`M-x slime` starts the default implementation. With `M-x han/slime-start`, choose a detected implementation for a new connection. Run `(lisp-implementation-type)` at its prompt to check which Lisp is answering. Each REPL has its own definitions. If two are open, use `M-x slime-list-connections`, move to the desired connection and press `d` to direct unpinned source buffers to it.

If your LispWorks console image has a different executable name, export `LISPWORKS` with its full executable path in the environment of **both** the installer and Emacs. For a machine with a console command named `my-lispworks`, select it directly for the trial directory.

```sh
curl -fsSL https://github.com/HermitHan/emacs-cl-kit/releases/latest/download/emacs-portable-source.sh | bash -s -- --target "$HOME/.emacs-portable-trial" --backend my-lispworks --non-interactive
```

The saved name goes into `var/slime-default-lisp` under the target directory. To choose SBCL for one launch, run `SLIME_DEFAULT_LISP=sbcl emacs --init-directory "$HOME/.emacs-portable-trial" -nw`. Startup tries a valid environment override, the saved selection, SBCL, and then the first available implementation. SLIME needs a console executable. A shell alias, GUI-only launcher or batch build command cannot be used as that executable.

## Try Emacs Lisp

The Common Lisp REPL runs SBCL or LispWorks. Emacs runs **Emacs Lisp** inside the editor to implement commands, buffers and key bindings. Try this in Emacs itself:

1. Press `M-:` (Meta-colon, which evaluates an Emacs Lisp expression), paste the expression below, and press Return. The echo area should report **`3`**.

   ```emacs-lisp
   (length '(a b c))
   ```

2. The quote makes `(a b c)` literal list data. Add a fourth symbol to the list and evaluate again. You can also use `C-x b *scratch* RET`, paste the expression, leave point after its final parenthesis with no active region, and press `C-x C-e` to evaluate it.
3. Try `C-h f length RET` to read the function documentation. In a throwaway buffer, `M-: (setq-local fill-column 88) RET` changes the suggested filling width in that buffer. Inspect it with `C-h v fill-column RET`. That local experiment ends when the buffer is killed. To save a user option for future sessions, see [Make it yours](#make-it-yours).

## Use gptel

### Set up chat and choose its context

On each new installation, run `M-x gptel-openai-oauth-login` and follow the sign-in prompts. For a remote terminal with a browser on another machine, press `M-:`, paste `(gptel-openai-oauth-login nil 'device)` and press Return. Follow the device authorization instructions displayed by gptel. The token is stored under the installed configuration directory. Keep this directory's `.cache/gptel-openai/` private.

Select the complete `add-two` definition in `tutorial.lisp`, then run `M-x gptel-add` to add that region as context. Run `M-x gptel`, open a chat and ask “What happens when I pass a negative number to this function?” Send with `M-x gptel-send` or `C-c RET` in the chat. Chat uses the conversation in the current buffer and the context you choose. Review included material through `M-x gptel-menu`; remove stale context when changing projects. Tool calls are disabled in this setup.

In a chat buffer, `C-c j b` moves to the beginning of the current message. Use `C-c j p` and `C-c j n` for previous and next, or `C-c j u` and `C-c j a` to go to the current or most recent user or assistant message. Repeating the role key sequence moves to the preceding message by that role.

### Review a proposed edit before accepting it

1. Return to `tutorial.lisp`, select the function again, and press **`C-c r`** (plain `r`). Enter “Add a one-line docstring describing the parameter and result. Keep the behavior” and confirm. The difference from SLIME's **`C-c C-r`** is the Control modifier on the last key.
2. The Diff opens when the proposal is ready. Use ordinary scrolling to inspect it. Press `y` to copy the entire candidate or `Y` to copy the original selection. The copied text is ready to paste, without diff markers.
3. To test the candidate, go to the tutorial's REPL, paste with `C-y`, and submit the definition with `M-RET`. Then try `(add-two 40)` and `(add-two -2)`. This updates the function **in that running Lisp** while the source still awaits your decision. This example selects a full definition. A fragment copied from inside a function may depend on its surrounding variables.
4. Return to the Diff. Press `a` to accept into the source, `k` to reject, or `r` to refine the pending candidate with another instruction. Press `e` for an explanation draft in chat, which you can edit and send yourself. `s` returns to the source, `q` closes the review window, and `?` shows the keys. Accepting changes the buffer. Save and compile to keep disk and REPL in sync. If you tested a candidate and then rejected it, recompile the original definition to restore it in the running Lisp.

Each fresh rewrite is a separate request. Refining with `r` carries the current candidate and relevant instructions into the next request. Use `e` to bring the recorded edit into a chat. For persistent style preferences, edit the installed `gptel-preferences.md` with `M-x han/gptel-edit-preferences`. Saved changes apply on the next chat or rewrite request.

**Response language.** By default gptel follows the natural language of the question or rewrite instruction. If the language is unclear, it uses the first nonempty setting among `LC_ALL`, `LC_MESSAGES`, and `LANG`, with English as the fallback for an unset, `C` or `POSIX` locale. Rewrites preserve the language of existing prose and follow the project's conventions for comments and docstrings. To choose a fixed language, run `M-x customize-option RET han/gptel-response-language RET`, select **Preferred language**, enter a value such as `English`, and choose **Apply and Save**. Select **Automatic** to resume following the question. An explicit request for a language or translation takes priority. The review key hints and the bundled preference text are written in Chinese.

## Make it yours

The source templates are under `payload/`. The installer copies their **contents** into the selected target. To find the configuration you're running now, use `M-: user-init-file RET` and `M-: user-emacs-directory RET`.

| What you want to learn or change | Where to look |
| --- | --- |
| Understand startup order and personal key translations | [Early initialization](payload/early-init.el) and [main configuration](payload/init.el) |
| Understand Lisp selection, connections and REPL behavior | [Backend detection](payload/lisp/init-common-lisp.el) and [SLIME setup](payload/lisp/init-slime.el) |
| Change AI style, chat behavior or review actions | [Preference text](payload/gptel-preferences.md), [gptel setup](payload/lisp/init-gptel.el) and [review workflow](payload/lisp/init-gptel-workflow.el) |
| Find where recent files, history and session state live | [State layout](payload/lisp/init-state.el) and the installed `var/` |
| Keep a Customize option across restarts | Use `M-x customize-option`, then **Apply and Save**. Emacs uses the target's machine-local `custom.el`. |

When reading a module, look for `require` to see what it loads, `setq` to see what it sets, and `add-hook` to find what runs when a mode starts. In the relevant buffer, `C-h m` describes active modes and `C-h k` explains a key's effective binding. A major mode determines the basic editing behavior (for example, Lisp mode), and minor modes add features such as Paredit or SLIME. Keep personal changes in your own version of the template if you want them on every machine. Restart the trial to check changes that affect startup. [Module-by-module reading guide (Chinese)](payload/配置阅读指南.org)

## Updates and recovery

To check for updates, rerun the one-line installer with the same target you chose originally. Unmodified managed files can be updated automatically. If a managed file was edited or deleted locally, or an unmanaged file at its destination differs, the normal installation reports the conflicting paths and stops. Compare your changes with the templates before deciding what to keep.

Before adopting an existing daily configuration, close that Emacs and make a full backup outside its directory. The installer reports compiled `.elc` files alongside managed Lisp sources and stops. Back up and move the listed bytecode before retrying. Use `--adopt --dry-run` to see the individual paths involved, then use `--adopt` if you wish to replace them.

The installer creates a sibling `<target>.portable-backups/` directory and prints the exact `--restore` command. After a piped install, that command runs a local copy from the transaction backup and works offline. Restore checks both the current contents and permissions of affected files. Packages, histories and unrelated files stay under the user's control. [Migration walkthrough (Chinese)](docs/迁移到已有设备.md)

## Troubleshoot

| Symptom | What to check |
| --- | --- |
| Emacs opens with unexpected keys or packages | Evaluate `user-init-file` with `M-:` and check the directory. Restart using the explicit trial command. Check the binding in the affected buffer with `C-h k`. |
| No Lisp backend appears | Check `sbcl --version` in the shell, then `M-: (executable-find "sbcl") RET` inside Emacs to see which executable it can find. For LispWorks set `LISPWORKS` before installing and launching. Over SSH, the server supplies the executables. |
| The REPL adds lines or reports an undefined function | Submit with `M-RET` (try Escape followed by Return in a terminal) or `M-x slime-repl-return`. Compile the definition from the source buffer and check the selected connection and package. |
| A rewrite asks for an active region | Place point before the definition, set the mark and move past its last parenthesis. Run `C-c r` again. If the terminal intercepts `C-SPC`, use `M-x set-mark-command`. |
| gptel cannot explain code in another file | Add the intended region or buffer with `M-x gptel-add`. Check the context in `M-x gptel-menu` and send the question again. For a sign-in problem, rerun the OAuth login in the same trial. |
| Installation reports a missing or mismatched snapshot | Check access to the upstream URL named in the error and retry. If providing a private snapshot, verify its pinned checksum. `--config-only` copies configuration while skipping package and startup checks. |
| Startup reported an error | Read `*Messages*` with `C-x b *Messages* RET`. To diagnose the trial, start `emacs --init-directory "$HOME/.emacs-portable-trial" --debug-init -nw` and inspect the first failing module. |

## Find a good reference

| What you want to learn | Start here |
| --- | --- |
| Move around without memorizing a key chart | Run `C-h t`, then read “Basic Editing Commands,” “Buffers” and “Windows.” Use `C-h i` for manuals installed on the machine. [GNU Emacs Manual](https://www.gnu.org/software/emacs/manual/html_node/emacs/) |
| Understand the Lisp behind the editor | Work through “Practicing Evaluation” and “How To Write Function Definitions” in `*scratch*`. [An Introduction to Programming in Emacs Lisp](https://www.gnu.org/software/lispintro/) |
| Learn Common Lisp by writing programs | Start with “Lather, Rinse, Repeat” and then build the simple database in chapter 3. [Practical Common Lisp by Peter Seibel](https://gigamonkeys.com/book/) |
| Look up exactly what a Common Lisp operator accepts or returns | Use the symbol index to find `DEFUN` and `+` from the exercise. [Common Lisp HyperSpec](https://www.lispworks.com/documentation/HyperSpec/Front/index.htm) |
| Explore interactive development and debugging | Read “Evaluation commands,” “Compilation commands” and the SLDB debugger section. [SLIME User Manual](https://slime.common-lisp.dev/doc/html/) |
| Understand prompts, chat context and rewrite features | Start with the usage examples. This distribution pins gptel 0.9.9.6 and adds its own review bindings. [gptel upstream documentation](https://github.com/karthink/gptel) |

## Package contents and maintenance

The public release contains the configuration, installer and pinned dependency metadata. Third-party package contents are fetched on the user's machine from the [archive lock file](deps/online-packages.json). The private offline snapshot covers 212 reference packages plus `compat` and `which-key` for Emacs 29. The target Emacs generates its own autoloads. Each user authorizes gptel separately. [Package baseline](deps/reference-packages.tsv)

Build the source release with `python3 scripts/make-release.py --output NEW_DIRECTORY`. It emits a tar archive, a standalone Bash installer and a SHA-256 sidecar for each. Only the files in the two release manifests are eligible. For a private offline edition, use another output directory and add `--offline-bundle /path/to/offline-packages.tar.gz`. The builder verifies the inner snapshot against its pinned hash. To bring changes back from a running Emacs, use `scripts/export-config.py` to export the reviewed files into a fresh directory and compare them with `payload/`. [Configuration manifest](scripts/config-files.txt) · [Release manifest](scripts/release-files.txt)

The configuration derives from Steve Purcell's Emacs setup and retains its BSD two-clause license. Third-party packages and resources retain their own licenses. [Third-party distribution scope](docs/third-party-distribution.md) · [Upstream configuration](https://github.com/purcell/emacs.d) · [License](LICENSE)
