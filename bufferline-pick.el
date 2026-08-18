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
         (index 0)
         (items nil))

    (dolist (buf tabs)
      (when (< index (length alphabet))
        (let ((char (nth index alphabet)))
          (push (cons char buf) items)
          (setq index (1+ index)))))

    (setq items (nreverse items))
    (if (null items)
        (message "No buffers to pick")
      (let* ((prompt (mapconcat (lambda (pair)
                                  (format "[%c] %s" (car pair) (buffer-name (cdr pair))))
                                items
                                "  "))
             (key (read-key (concat "Pick buffer: " prompt " ")))
             (chosen (cdr (assoc key items))))
        (if (and chosen (buffer-live-p chosen))
            (switch-to-buffer chosen)
          (message "Pick cancelled"))))))

;;;###autoload
(defun bufferline-pick-close ()
  "Interactively close a buffer by selecting its assigned letter."
  (interactive)
  (let* ((tabs (bufferline-buffers-get))
         (alphabet (string-to-list bufferline-pick-alphabet))
         (index 0)
         (items nil))

    (dolist (buf tabs)
      (when (< index (length alphabet))
        (let ((char (nth index alphabet)))
          (push (cons char buf) items)
          (setq index (1+ index)))))

    (setq items (nreverse items))
    (if (null items)
        (message "No buffers to close")
      (let* ((prompt (mapconcat (lambda (pair)
                                  (format "[%c] %s" (car pair) (buffer-name (cdr pair))))
                                items
                                "  "))
             (key (read-key (concat "Close buffer: " prompt " ")))
             (chosen (cdr (assoc key items))))
        (if (and chosen (buffer-live-p chosen))
            (let ((name (buffer-name chosen)))
              (kill-buffer chosen)
              (if (fboundp 'bufferline-ui-refresh)
                  (bufferline-ui-refresh)
                (force-mode-line-update t))
              (message "Closed buffer: %s" name))
          (message "Pick close cancelled"))))))

(provide 'bufferline-pick)
;;; bufferline-pick.el ends here
