;;; bufferline-commands.el --- Interactive navigation and manipulation commands -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Szymon Wilczek
;; Author: Szymon Wilczek <swilczek.lx@gmail.com>
;; Version: 0.1.0
;; Package-Requires: ((emacs "28.1") (nerd-icons "0.1.0"))
;; URL: https://github.com/szymonwilczek/bufferline.el
;; Licensed under GPL-3.0.

;;; Code:

(require 'bufferline-buffers)
(require 'bufferline-pick)

;;;###autoload
(defun bufferline-next-tab ()
  "Switch cyclically to the next bufferline tab."
  (interactive)
  (let* ((tabs (bufferline-buffers-all))
         (pos (seq-position tabs (current-buffer))))
    (if pos
        (switch-to-buffer (nth (if (= pos (1- (length tabs))) 0 (1+ pos)) tabs))
      (when tabs (switch-to-buffer (car tabs))))))

;;;###autoload
(defun bufferline-prev-tab ()
  "Switch cyclically to the previous bufferline tab."
  (interactive)
  (let* ((tabs (bufferline-buffers-all))
         (pos (seq-position tabs (current-buffer))))
    (if pos
        (switch-to-buffer (nth (if (= pos 0) (1- (length tabs)) (1- pos)) tabs))
      (when tabs (switch-to-buffer (car (last tabs)))))))

;;;###autoload
(defun bufferline-close-tab (&optional buffer)
  "Close current or specified BUFFER without disturbing window layout."
  (interactive)
  (let ((buf (or buffer (current-buffer))))
    (bufferline-next-tab)
    (kill-buffer buf)))

;;;###autoload
(defun bufferline-toggle-pin (&optional buffer)
  "Toggle pinned status of current or specified BUFFER."
  (interactive)
  (let ((buf (or buffer (current-buffer))))
    (bufferline-state-toggle-pin buf)
    (force-mode-line-update t)
    (message "Buffer %s is now %s"
             (buffer-name buf)
             (if (bufferline-state-pinned-p buf) "pinned" "unpinned"))))

(provide 'bufferline-commands)
;;; bufferline-commands.el ends here
