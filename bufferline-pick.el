;;; bufferline-pick.el --- Quick letter buffer jump picker -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Szymon Wilczek
;; Author: Szymon Wilczek <swilczek.lx@gmail.com>
;; Version: 0.1.0
;; Package-Requires: ((emacs "28.1") (nerd-icons "0.1.0"))
;; URL: https://github.com/szymonwilczek/bufferline.el
;; Licensed under GPL-3.0.

;;; Code:

(require 'bufferline-config)
(require 'bufferline-buffers)

;;;###autoload
(defun bufferline-pick ()
  "Interactively jump to a visible buffer by selecting its assigned letter."
  (interactive)
  (let* ((tabs (bufferline-buffers-get))
         (alphabet (string-to-list bufferline-pick-alphabet))
         (map (make-sparse-keymap))
         (index 0)
         (items nil))

    (dolist (buf tabs)
      (when (< index (length alphabet))
        (let ((char (nth index alphabet)))
          (push (cons char buf) items)
          (define-key map (char-to-string char)
                      (lambda ()
                        (interactive)
                        (switch-to-buffer buf)))
          (setq index (1+ index)))))

    (message "Pick buffer: %s"
             (mapconcat (lambda (pair)
                          (format "[%c] %s" (car pair) (buffer-name (cdr pair))))
                        (nreverse items)
                        "  "))
    (let ((key (read-key)))
      (let ((chosen (cdr (assoc key items))))
        (if chosen
            (switch-to-buffer chosen)
          (message "Pick cancelled"))))))

(provide 'bufferline-pick)
;;; bufferline-pick.el ends here
