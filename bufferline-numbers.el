;;; bufferline-numbers.el --- Buffer numbers and ordinal prefixes -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Szymon Wilczek
;; Author: Szymon Wilczek <swilczek.lx@gmail.com>
;; Version: 0.1.0
;; Package-Requires: ((emacs "28.1") (nerd-icons "0.1.0"))
;; URL: https://github.com/szymonwilczek/bufferline.el
;; Licensed under GPL-3.0.

;;; Code:

(require 'bufferline-config)

(defun bufferline-numbers-format (buffer index)
  "Format number prefix for BUFFER at INDEX based on `bufferline-numbers`."
  (let* ((ordinal (1+ index))
         (id (or (buffer-local-value 'bufferline-state--tab-order-id buffer) ordinal)))
    (cond
     ((functionp bufferline-numbers)
      (funcall bufferline-numbers ordinal id buffer))
     ((eq bufferline-numbers 'both)
      (format "%d:%d " ordinal id))
     ((or (eq bufferline-numbers 'ordinal) (eq bufferline-numbers 'buffer-id))
      (let ((num (if (eq bufferline-numbers 'ordinal) ordinal id)))
        (if (functionp bufferline-numbers-formatter)
            (funcall bufferline-numbers-formatter num buffer)
          (format (or bufferline-numbers-formatter "%d. ") num))))
     (t ""))))

(provide 'bufferline-numbers)
;;; bufferline-numbers.el ends here
