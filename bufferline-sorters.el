;;; bufferline-sorters.el --- Sorters and buffer ordering strategies -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Szymon Wilczek
;; Author: Szymon Wilczek <swilczek.lx@gmail.com>
;; Version: 0.1.0
;; Package-Requires: ((emacs "28.1") (nerd-icons "0.1.0"))
;; URL: https://github.com/szymonwilczek/bufferline.el
;; Licensed under GPL-3.0.

;;; Code:

(defun bufferline-sorters-by-fifo (buffers)
  "Sort BUFFERS by their monotonic visit timestamp."
  (seq-sort
   (lambda (a b)
     (< (or (buffer-local-value 'bufferline-state--tab-order-id a) 0)
        (or (buffer-local-value 'bufferline-state--tab-order-id b) 0)))
   buffers))

(defun bufferline-sorters-by-extension (buffers)
  "Sort BUFFERS by file extension."
  (seq-sort
   (lambda (a b)
     (let ((ea (or (file-name-extension (or (buffer-file-name a) "")) ""))
           (eb (or (file-name-extension (or (buffer-file-name b) "")) "")))
       (string< ea eb)))
   buffers))

(defun bufferline-sorters-by-directory (buffers)
  "Sort BUFFERS by file directory."
  (seq-sort
   (lambda (a b)
     (let ((da (or (file-name-directory (or (buffer-file-name a) "")) ""))
           (db (or (file-name-directory (or (buffer-file-name b) "")) "")))
       (string< da db)))
   buffers))

(provide 'bufferline-sorters)
;;; bufferline-sorters.el ends here
