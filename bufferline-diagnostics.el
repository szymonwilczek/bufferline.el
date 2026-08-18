;;; bufferline-diagnostics.el --- Diagnostics integration for buffer tabs -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Szymon Wilczek
;; Author: Szymon Wilczek <swilczek.lx@gmail.com>
;; Version: 0.1.0
;; Package-Requires: ((emacs "28.1") (nerd-icons "0.1.0"))
;; URL: https://github.com/szymonwilczek/bufferline.el
;; Licensed under GPL-3.0.

;;; Code:

(defun bufferline-diagnostics-badge (buffer)
  "Return diagnostic badge string for BUFFER using Flymake, or empty string."
  (with-current-buffer buffer
    (if (bound-and-true-p flymake-mode)
        (let* ((diags (flymake-diagnostics))
               (errs 0)
               (warns 0))
          (dolist (d diags)
            (pcase (flymake-diagnostic-type d)
              (:error (cl-incf errs))
              (:warning (cl-incf warns))))
          (cond
           ((> errs 0) (format "  %d" errs))
           ((> warns 0) (format "  %d" warns))
           (t "")))
      "")))

(provide 'bufferline-diagnostics)
;;; bufferline-diagnostics.el ends here
