# Emacs CL Kit handbook

[Back to the README](../README.md) · [简体中文](使用手册.md)

Once you can call `(add-two 40)` in the REPL, you have everything you need for these exercises. When looking up a key, pay attention to the buffer you're in. Source buffers, REPLs and chats each have their own bindings.

## Find your way around Emacs

**Keep the source and REPL in view.** In `cl-kit-demo.lisp`, press `C-x 3` for a side-by-side split. This selects the new pane. If the running REPL is not already visible there, press `C-x b`, type `*slime-repl` and select its buffer. Use `M-o` to move between them. Two windows can show the same buffer, so an edit in one appears in both. When you want one pane to fill the frame, press `C-x 1`. The other buffer is still available through `C-x b`.

**Find out what a key does here.** In the REPL, press `C-h k` followed by `M-RET`. The help buffer names the command, `slime-repl-return`. In a source buffer, `C-h m` describes the major mode, such as Lisp, and active minor modes, such as SLIME or Paredit. If your terminal intercepts `C-SPC`, use `M-x set-mark-command` and move point to select some text. To practise the default Emacs keys from the GNU tutorial, run `emacs -Q -nw` in a second terminal and press `C-h t`.

**Try a setting in a single buffer.** Open a practice text file with `C-x C-f`. Press `M-:`, enter `(setq-local fill-column 88)` and press Return. Check the local value with `C-h v fill-column RET`. Then use `M-:` to evaluate `(kill-local-variable 'fill-column)` and restore the default. The setting controls the target width when filling paragraphs. To try another Emacs Lisp expression, paste `(length '(a b c))` into `*scratch*`, put point just after the final parenthesis and press `C-x C-e`. The echo area should display `3`. Emacs itself evaluates both exercises.

## Experiment with a running Lisp

Keep the `add-two` definition from the README loaded. Enter this expression in its REPL and submit it with `M-RET`. Expect `(0 2 42)`.

```common-lisp
(mapcar #'add-two '(-2 0 40))
```

`#'add-two` supplies the function. `mapcar` calls it on each element and collects the results. To reuse that operation in a program, add a second definition to the same source file.

```common-lisp
(defun add-two-to-each (numbers)
  (mapcar #'add-two numbers))
```

Save the file, then use `C-c C-k` to compile and load it. In the REPL, try `(add-two-to-each '(-2 0 40))`, then `(add-two-to-each '())`. The first returns the same three numbers and the second returns the empty list, `NIL`. To evaluate just a selected expression in a source buffer, use `C-c C-r`.

**Compare SBCL and LispWorks side by side.** Run `M-x slime` for your default implementation, then `M-x han/slime-start` to pick another. Evaluate `(lisp-implementation-type)` in each REPL to check which is which. Run `M-x slime-list-connections`, move to the connection you want and press `d` to make it the default for source buffers without a pinned connection. Each process needs its own compiled definition of `add-two`.

**Choose what starts next time.** The installer saves the selected name in `var/slime-default-lisp` under your configuration directory. To change it, rerun the installation pipeline with `bash -s -- --backend NAME` on the right. Include the same `--target` if you specified one originally. For a single launch of a trial installation, use:

```sh
SLIME_DEFAULT_LISP=sbcl emacs --init-directory "$HOME/.emacs-portable-trial" -nw
```

At startup, Emacs tries the environment override, the saved selection, SBCL and then the first available implementation. If a LispWorks console image lives outside `PATH`, set `LISPWORKS` to its executable path in the environment of both the installer and Emacs. [Linux migration walkthrough (Chinese)](迁移到已有设备.md)

## Give gptel the right context

**Add a definition from another file.** Visit that buffer, select the relevant definition and run `M-x gptel-add`. In your chat, check the context with `M-x gptel-menu` and send with `C-c RET`. When you switch projects, remove context you no longer need. For account authorization over SSH, evaluate `(gptel-openai-oauth-login nil 'device)` with `M-:` and follow the prompts on a device with a browser.

In a chat, `C-c j b` goes to the start of the current message. Use `C-c j p` and `C-c j n` for the previous and next messages. `C-c j u` finds the current or most recent user message and `C-c j a` does the same for the assistant. Press the role sequence again at that position to find the preceding message by that role.

**Test a rewrite before accepting it.** Select the whole `add-two` definition. Press `C-c r` and ask for a docstring. When the Diff opens, use the key that matches what you want to do next.

| What you want to do | In the Diff |
| --- | --- |
| Try the candidate in your REPL | `y` copies the candidate as plain text. Paste with `C-y` in the REPL, submit with `M-RET` and test `(add-two 40)`. `Y` copies the original text from the first round. |
| Refine it while keeping it pending | `r` takes another instruction, such as “Shorten the docstring to one sentence.” The next request includes the candidate and previous rewrite instructions. |
| Discuss this particular change in chat | `e` prepares an editable chat draft with the original, the candidate and the instructions. Send it when you're ready. A fresh rewrite has its own context. |
| Apply or discard the edit | `a` puts the candidate into the source buffer. Save it with `C-x C-s`. `k` rejects the candidate. |
| Leave the review open for later | `s` returns to the source. `q` closes the Diff window and keeps the candidate pending. `?` shows the review keys. |

Submitting a candidate in the REPL changes the running definition immediately. If you reject it with `k`, compile the original definition again with `C-c C-c` to restore the REPL's behaviour. This technique works well with a whole function. A few isolated lines may depend on local variables from the enclosing function.

**Save a preference for future requests.** Open the installed `gptel-preferences.md` with `M-x han/gptel-edit-preferences`. Try adding “When traversing lists, prefer `mapcar` or `dolist`.” Save with `C-x C-s`. Both chat and rewrite read the file on the next request. Replies normally follow the language of your question. For ambiguous input such as code alone, gptel uses the system language as a fallback. To choose a fixed language, run `M-x customize-option RET han/gptel-response-language RET`, select `Preferred language`, enter a language name and choose `Apply and Save`. You can still request another language in an individual prompt.

## Customize, update and restore

| What you want to change | Where to look |
| --- | --- |
| Global keys and the order in which modules load | In the installed directory, `early-init.el` handles early startup and `init.el` loads the modules and defines personal key translations. [Key definitions](../payload/init.el) · [Module guide (Chinese)](../payload/配置阅读指南.org) |
| A setting on this machine | Use `M-x customize-option` and select `Apply and Save`. Customize writes to the machine-local `custom.el`. Evaluate `user-emacs-directory` with `M-:` to find it. |
| Changes you want on multiple machines | The repository's `payload/` contains the installation templates. Keep portable changes in your own copy of those templates. The installed `var/` holds runtime data such as history. gptel keeps its authorization under `.cache/gptel-openai/`. [State directories](../payload/lisp/init-state.el) |

To update, run the installer again with **the same target**. Use `bash -s -- --dry-run` on the right side of the pipeline to preview the default installation, adding your original `--target` if you installed alongside it. If you changed or deleted a managed file locally, compare the paths listed by the installer. To adopt an existing configuration, close the Emacs using it, make a full backup outside the directory and preview with `--adopt --dry-run`. If the installer reports old `.elc` files alongside the managed sources, back them up and move them aside. Emacs could otherwise load the old bytecode.

An installation that changes files creates a sibling `<target>.portable-backups/` and prints the restore command for that transaction. After a piped install, this command uses a local copy in the backup and works offline. Restore checks the contents and permissions of the affected files. Installed packages, histories and unrelated files are managed separately. [Dependencies and offline installation (Chinese)](依赖与离线包.md)

**Verify a downloaded installer.** Download `emacs-portable-source.sh` and its `.sha256` file from the same release. In their directory, run `shasum -a 256 -c emacs-portable-source.sh.sha256` on macOS or `sha256sum -c emacs-portable-source.sh.sha256` on Linux. After it reports `OK`, run `bash ./emacs-portable-source.sh` with the same `--target` if you used one previously.

**Build your own release.** From the repository root, run `python3 scripts/make-release.py --output dist` to build the standalone installer and source archive, each with its SHA-256 checksum. To bring local edits back into your copy of the project, use `scripts/export-config.py` to export the listed configuration files into a new directory and compare them with `payload/`. [Configuration files](../scripts/config-files.txt) · [Release files](../scripts/release-files.txt)

## Troubleshoot by symptom

| Symptom | First check |
| --- | --- |
| Emacs starts with unfamiliar keys | Evaluate `user-init-file` with `M-:`. Use the README's `--init-directory` launch command for your trial. For startup errors, open `*Messages*` or add `--debug-init` to the launch command. |
| SLIME cannot find a Lisp | Inside Emacs, evaluate `(executable-find "sbcl")` with `M-:`. Over SSH, check the remote machine. LispWorks needs an executable console image. |
| Return adds a line, or the REPL says a function is undefined | Submit with `M-RET`. If your terminal intercepts it, use `M-x slime-repl-return`. Check the package and implementation at the REPL, then compile the definition for that connection. |
| Rewrite asks for a region, or chat cannot see another file | In the source, set the mark and select the entire function before pressing `C-c r`. For chat, select the relevant text in the other buffer and run `M-x gptel-add`. |
| gptel signs in but no reply appears | Check the network, `curl`, chat status and `*Messages*` in the installation where you signed in. If needed, run `M-x gptel-openai-oauth-login` there again. |
| A download times out or a hash check fails | Find the file named in the error. For the installer, the release notes give an alternate URL. For an upstream package, retry when the network is available. A private offline bundle must match the release's pinned hash. [Release notes](https://github.com/HermitHan/emacs-cl-kit/releases) |

## Where to read next

- **Learn the editor.** Try movement, selection and help in `C-h t`, then read the manual's “Buffers” and “Windows” chapters. `C-h i` opens manuals installed locally. [GNU Emacs Manual](https://www.gnu.org/software/emacs/manual/html_node/emacs/)
- **Read Emacs configuration.** Start with lists, evaluation and `defun`. Open an installed `lisp/init-*.el` file and look up `require` or `add-hook` with `C-h f`. [An Introduction to Programming in Emacs Lisp](https://www.gnu.org/software/lispintro/)
- **Learn Common Lisp.** Chapters 2 and 3 of *Practical Common Lisp* take you from a REPL to a small database. To look up the arguments and return values of a standard symbol, press `C-c l` on it in a Lisp source buffer. [Practical Common Lisp](https://gigamonkeys.com/book/) · [Common Lisp HyperSpec](https://www.lispworks.com/documentation/HyperSpec/Front/index.htm)
- **Go deeper with SLIME and gptel.** Read SLIME's compilation, REPL and debugger sections when you want to understand a live Lisp session. See gptel's examples for context and rewrites. Use `C-h k` in the relevant buffer to check this setup's bindings. [SLIME User Manual](https://slime.common-lisp.dev/doc/html/) · [gptel](https://github.com/karthink/gptel)
