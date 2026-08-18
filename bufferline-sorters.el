;;; bufferline-sorters.el --- Sorters and buffer ordering strategies -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Szymon Wilczek
;; Author: Szymon Wilczek <swilczek.lx@gmail.com>
;; Version: 0.1.0
;; Package-Requires: ((emacs "28.1") (nerd-icons "0.1.0"))
;; URL: https://github.com/szymonwilczek/bufferline.el
;; Licensed under GPL-3.0.

;;; Code:

(require 'bufferline-config)

(defun bufferline-sorters-by-fifo (buffers)
  "Sort BUFFERS by pinned state first, then by their monotonic visit timestamp."
  (seq-sort
   (lambda (a b)
     (let ((pa (buffer-local-value 'bufferline-state--pinned a))
           (pb (buffer-local-value 'bufferline-state--pinned b)))
       (cond
        ((and pa (not pb)) t)
        ((and (not pa) pb) nil)
        (t (< (or (buffer-local-value 'bufferline-state--tab-order-id a) 0)
              (or (buffer-local-value 'bufferline-state--tab-order-id b) 0))))))
   buffers))

(defun bufferline-sorters-by-name (buffers)
  "Sort BUFFERS by pinned state first, then alphabetically by buffer name."
  (seq-sort
   (lambda (a b)
     (let ((pa (buffer-local-value 'bufferline-state--pinned a))
           (pb (buffer-local-value 'bufferline-state--pinned b)))
       (cond
        ((and pa (not pb)) t)
        ((and (not pa) pb) nil)
        (t (string< (buffer-name a) (buffer-name b))))))
   buffers))

(defun bufferline-sorters-by-extension (buffers)
  "Sort BUFFERS by pinned state first, then by file extension."
  (seq-sort
   (lambda (a b)
     (let ((pa (buffer-local-value 'bufferline-state--pinned a))
           (pb (buffer-local-value 'bufferline-state--pinned b)))
       (cond
        ((and pa (not pb)) t)
        ((and (not pa) pb) nil)
        (t (let ((ea (or (file-name-extension (or (buffer-file-name a) "")) ""))
                 (eb (or (file-name-extension (or (buffer-file-name b) "")) "")))
             (string< ea eb))))))
   buffers))

(defun bufferline-sorters-by-directory (buffers)
  "Sort BUFFERS by pinned state first, then by directory path."
  (seq-sort
   (lambda (a b)
     (let ((pa (buffer-local-value 'bufferline-state--pinned a))
           (pb (buffer-local-value 'bufferline-state--pinned b)))
       (cond
        ((and pa (not pb)) t)
        ((and (not pa) pb) nil)
        (t (let ((da (or (file-name-directory (or (buffer-file-name a) "")) ""))
                 (db (or (file-name-directory (or (buffer-file-name b) "")) "")))
             (string< da db))))))
   buffers))

(defun bufferline-sorters-apply (buffers)
  "Sort BUFFERS according to `bufferline-sort-by` setting."
  (pcase bufferline-sort-by
    ('name (bufferline-sorters-by-name buffers))
    ('extension (bufferline-sorters-by-extension buffers))
    ('directory (bufferline-sorters-by-directory buffers))
    (_ (bufferline-sorters-by-fifo buffers))))

(provide 'bufferline-sorters)
;;; bufferline-sorters.el ends here
