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

(defun bufferline-state-register (buffer)
  "Assign an order index to BUFFER if not already set."
  (with-current-buffer buffer
    (unless bufferline-state--tab-order-id
      (setq bufferline-state--tab-order-counter (1+ bufferline-state--tab-order-counter))
      (setq bufferline-state--tab-order-id bufferline-state--tab-order-counter))))

(provide 'bufferline-state)
;;; bufferline-state.el ends here
