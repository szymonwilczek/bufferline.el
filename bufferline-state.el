;;; bufferline-state.el --- Buffer state management and tracking -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Szymon Wilczek
;; Author: Szymon Wilczek <swilczek.lx@gmail.com>
;; Version: 0.1.0
;; Package-Requires: ((emacs "28.1") (nerd-icons "0.1.0"))
;; URL: https://github.com/szymonwilczek/bufferline.el
;; Licensed under GPL-3.0.

;;; Code:

(defvar bufferline-state--tab-order-counter 0
  "Monotonically increasing counter for FIFO tab ordering.")

(defvar-local bufferline-state--tab-order-id nil
  "Buffer-local FIFO order index.")

(defvar-local bufferline-state--pinned nil
  "Non-nil if current buffer is pinned to the front of bufferline.")

(defun bufferline-state-pinned-p (buffer)
  "Return non-nil if BUFFER is pinned."
  (buffer-local-value 'bufferline-state--pinned buffer))

(defun bufferline-state-toggle-pin (&optional buffer)
  "Toggle pinned state of BUFFER (default current buffer)."
  (let ((buf (or buffer (current-buffer))))
    (with-current-buffer buf
      (setq bufferline-state--pinned (not bufferline-state--pinned)))))

(defun bufferline-state-register (buffer)
  "Assign an order index to BUFFER if not already set."
  (with-current-buffer buffer
    (unless bufferline-state--tab-order-id
      (setq bufferline-state--tab-order-counter (1+ bufferline-state--tab-order-counter))
      (setq bufferline-state--tab-order-id bufferline-state--tab-order-counter))))

(provide 'bufferline-state)
;;; bufferline-state.el ends here
