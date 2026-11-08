# Emacs CL Kit

**English** · [简体中文](README.zh-CN.md) · [English handbook](docs/handbook.en.md)

A Common Lisp setup for Emacs on macOS and Linux. Edit a function, compile it into a running SBCL or LispWorks session with SLIME, then call it immediately. The same workflow works in a terminal over SSH. Optional gptel commands let you discuss a function or review a proposed edit in Emacs.

## One-line install

You need **GNU Emacs 29.1 or later**, Python 3.8+, Bash, curl and a network connection for the first install. To run the example below, install **SBCL** or have a licensed **LispWorks console** executable available. The release was tested with Emacs 30.1 on macOS and 29.3 on Linux.

**On a new machine**, run the installer from any directory. It installs into `~/.emacs.d`. The second command opens Emacs in your terminal.

```sh
curl -fsSL https://github.com/HermitHan/emacs-cl-kit/releases/latest/download/emacs-portable-source.sh | bash
emacs -nw
```

**If you already use Emacs**, install alongside your current configuration and start that copy explicitly.

```sh
curl -fsSL https://github.com/HermitHan/emacs-cl-kit/releases/latest/download/emacs-portable-source.sh | bash -s -- --target "$HOME/.emacs-portable-trial"
emacs --init-directory "$HOME/.emacs-portable-trial" -nw
```

When prompted, choose a Lisp implementation or press Return. On a fresh install, the default is SBCL if available. If GitHub's download URL times out, the release notes give an alternate URL for the same installer. [v0.1.0 release notes](https://github.com/HermitHan/emacs-cl-kit/releases/tag/v0.1.0)

## Compile and call your first function

`C-` means hold Ctrl. `M-` means Meta, usually Alt. In a terminal you can also press Esc, release it, then press the next key. `RET` means Return. To enter `C-x C-f`, press Ctrl+x followed by Ctrl+f.

1. In Emacs, press `C-x C-f`, enter `~/cl-kit-demo.lisp`, and press Return. Paste the definition below and save with `C-x C-s`.

   ```common-lisp
   (defun add-two (n)
     (+ n 2))
   ```

2. Press `M-x`, type `slime`, and press Return. Wait for the Lisp prompt, usually `CL-USER>`. This is the REPL, where you can call functions in the running Lisp process.
3. Press `C-x b`, enter `cl-kit-demo.lisp`, and press Return to get back to the source. Put the cursor inside `add-two` and press **`C-c C-c`** to compile the definition into that process.
4. Press `C-c C-z` to switch to the REPL. Type `(add-two 40)` and press **`M-RET`**. You should see **`42`**. In this configuration plain Return inserts a newline.

Try changing `2` to `3` in the source file and saving. Call `(add-two 40)` again and it still returns `42`. Compile the edited definition with `C-c C-c`, then call it again. Now it returns `43`. Saving updates the file on disk. Compiling updates the running Lisp session. Change the number back to `2`, save and compile once more.

## Editing keys in this configuration

| To do this | Keys |
| --- | --- |
| Select, copy, cut, paste | Set the mark with `C-SPC` and move the cursor. `C-w` copies, `M-w` cuts and `C-y` pastes. |
| Type parentheses or square brackets | The physical `[` and `]` keys type parentheses. The parenthesis keys type square brackets. Paredit pairs delimiters in Lisp buffers. |
| Complete, undo or cancel a command | `TAB` normally runs completion (Org keeps folding), `M--` undoes an edit, and `C-g` cancels a command. |

To check a binding in the current buffer, press `C-h k` followed by the key.

## Ask gptel about the same function

To use the ChatGPT backend, run `M-x gptel-openai-oauth-login` and sign in with your own subscription account. You can do all the Lisp exercises offline after installation.

**Explain.** Place the cursor just before the opening parenthesis of `(defun`. Press `C-SPC` and then `C-M-f` to select the whole definition. Run `M-x gptel-add` to give the chat that code as context. Run `M-x gptel`, accept the suggested chat name and ask “What does `(add-two -2)` return, and why?”, and send with `C-c RET`.

**Rewrite.** Select the definition in the source again and press `C-c r`. Try “Add a short docstring and preserve the behavior.” The diff opens for review. Press `a` to accept, `k` to reject, or `r` to ask for another revision. After accepting, save and compile as before. To set lasting preferences for chat and rewrite, run `M-x han/gptel-edit-preferences` and save your changes.

## Go further

- For multiple Lisp backends, testing rewrites in the REPL, Emacs Lisp exercises, updates and recovery, see the [handbook](docs/handbook.en.md).
- To follow the startup sequence and read the key bindings, open [early-init.el](payload/early-init.el) and [init.el](payload/init.el).
- The configuration derives from Steve Purcell’s Emacs setup. [License](LICENSE) · [Third-party notices](docs/third-party-distribution.md)
