;;; bufferline-numbers.el --- Buffer numbers and ordinal prefixes -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Szymon Wilczek
;; Author: Szymon Wilczek <swilczek.lx@gmail.com>
;; Version: 0.1.0
;; Package-Requires: ((emacs "28.1") (nerd-icons "0.1.0"))
;; URL: https://github.com/szymonwilczek/bufferline.el
;; Licensed under GPL-3.0.

;;; Code:

(defcustom bufferline-numbers nil
  "How to display buffer numbers in tabs: nil, 'ordinal, or 'buffer-id."
  :type '(choice (const :tag "None" nil)
                 (const :tag "Ordinal (1, 2, ...)" ordinal)
                 (const :tag "Buffer ID" buffer-id))
  :group 'bufferline)

(defun bufferline-numbers-format (buffer index)
  "Format number prefix for BUFFER at INDEX based on `bufferline-numbers`."
  (pcase bufferline-numbers
    ('ordinal (format "%d. " (1+ index)))
    ('buffer-id (format "%d. " (buffer-local-value 'bufferline-state--tab-order-id buffer)))
    (_ "")))

(provide 'bufferline-numbers)
;;; bufferline-numbers.el ends here
