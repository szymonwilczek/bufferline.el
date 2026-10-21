;;; bufferline-diagnostics.el --- Diagnostics integration for buffer tabs -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Szymon Wilczek
;; Author: Szymon Wilczek <swilczek.lx@gmail.com>
;; Package-Requires: ((emacs "28.1") (nerd-icons "0.1.0"))
;; URL: https://github.com/szymonwilczek/bufferline.el
;; Licensed under GPL-3.0.

;;; Code:

(require 'bufferline-config)

(declare-function flymake-diagnostics "flymake")
(declare-function flymake-diagnostic-type "flymake")

(defun bufferline-diagnostics--flymake-level (diagnostic)
  "Return the level of Flymake DIAGNOSTIC: `error', `warning', `note' or nil.
Types defined by backends, such as those of Eglot, are classified by the
Flymake category they inherit from."
  (let ((type (flymake-diagnostic-type diagnostic)))
    (pcase (or (and (symbolp type) (get type 'flymake-category)) type)
      ((or :error 'flymake-error) 'error)
      ((or :warning 'flymake-warning) 'warning)
      ((or :note 'flymake-note) 'note))))

(defun bufferline-diagnostics--flymake-counts (buffer)
  "Return the Flymake diagnostic counts of BUFFER, or nil without Flymake."
  (with-current-buffer buffer
    (when (bound-and-true-p flymake-mode)
      (let ((counts (list (cons 'error 0) (cons 'warning 0) (cons 'note 0))))
        (dolist (d (flymake-diagnostics))
          (let ((cell (assq (bufferline-diagnostics--flymake-level d) counts)))
            (when cell
              (setcdr cell (1+ (cdr cell))))))
        counts))))

(defun bufferline-diagnostics-counts (buffer)
  "Return the diagnostic counts of BUFFER, or nil when nothing checks it.
The counts are an alist ((error . N) (warning . N) (note . N))."
  (bufferline-diagnostics--flymake-counts buffer))

(defun bufferline-diagnostics-level (counts)
  "Return the most severe level with a non-zero count in COUNTS, or nil."
  (seq-find (lambda (level) (> (or (cdr (assq level counts)) 0) 0))
            '(error warning note)))

(defun bufferline-diagnostics-badge (buffer)
  "Return diagnostic badge string for BUFFER, or empty string."
  (let ((counts (bufferline-diagnostics-counts buffer)))
    (if (null counts)
        ""
      (let ((errs (cdr (assq 'error counts)))
            (warns (cdr (assq 'warning counts)))
            (notes (cdr (assq 'note counts))))
        (if (functionp bufferline-diagnostics-indicator)
            (funcall bufferline-diagnostics-indicator
                     (+ errs warns notes)
                     (bufferline-diagnostics-level counts)
                     counts
                     buffer)
          (cond
           ((> errs 0) (format " %s %d" bufferline-diagnostics-error-icon errs))
           ((> warns 0) (format " %s %d" bufferline-diagnostics-warning-icon warns))
           ((> notes 0) (format " %s %d" bufferline-diagnostics-info-icon notes))
           (t "")))))))

(provide 'bufferline-diagnostics)
;;; bufferline-diagnostics.el ends here
