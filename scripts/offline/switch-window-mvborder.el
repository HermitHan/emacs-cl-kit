;;; switch-window-mvborder.el --- Resize split windows in Emacs CL Kit -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Emacs CL Kit contributors
;; SPDX-License-Identifier: GPL-3.0-or-later
;; This independent implementation is distributed under the GNU General
;; Public License, version 3 or later. See COPYING.emacs-cl-kit.

(defcustom switch-window-mvborder-increment 5
  "Number of columns or lines to move the window divider by default."
  :type 'integer
  :group 'switch-window)

(defun emacs-cl-kit--move-divider (direction horizontal amount)
  "Move the divider in DIRECTION by AMOUNT columns or lines.
HORIZONTAL selects a side-by-side split.  With no trailing neighbor,
move the leading divider.  Keep both dividers inside the frame."
  (let* ((forward (if horizontal 'right 'below))
         (backward (if horizontal 'left 'above))
         (neighbor (window-in-direction forward))
         (divider (if neighbor (selected-window) (window-in-direction backward)))
         (size (if amount (prefix-numeric-value amount) switch-window-mvborder-increment)))
    (when divider
      (adjust-window-trailing-edge divider (* direction size) horizontal))))

(defun switch-window-mvborder-left (amount)
  "Move the vertical divider left by AMOUNT columns."
  (interactive "P")
  (emacs-cl-kit--move-divider -1 t amount))

(defun switch-window-mvborder-right (amount)
  "Move the vertical divider right by AMOUNT columns."
  (interactive "P")
  (emacs-cl-kit--move-divider 1 t amount))

(defun switch-window-mvborder-up (amount)
  "Move the horizontal divider up by AMOUNT lines."
  (interactive "P")
  (emacs-cl-kit--move-divider -1 nil amount))

(defun switch-window-mvborder-down (amount)
  "Move the horizontal divider down by AMOUNT lines."
  (interactive "P")
  (emacs-cl-kit--move-divider 1 nil amount))

(provide 'switch-window-mvborder)
;;; switch-window-mvborder.el ends here
