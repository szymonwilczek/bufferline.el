;;; bufferline-duplicates.el --- Disambiguate buffers with identical basenames -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Szymon Wilczek
;; Author: Szymon Wilczek <swilczek.lx@gmail.com>
;; Version: 0.1.0
;; Package-Requires: ((emacs "28.1") (nerd-icons "0.1.0"))
;; URL: https://github.com/szymonwilczek/bufferline.el
;; Licensed under GPL-3.0.

;;; Code:

(require 'bufferline-config)

(defun bufferline-duplicates--extract-prefix (filepath depth)
  "Extract up to DEPTH parent directory components from FILEPATH with trailing slash."
  (let* ((dir (file-name-directory filepath))
         (parts (when dir
                  (split-string (directory-file-name dir) "/" t)))
         (n (max 1 (or depth 1)))
         (sub-parts (if (<= (length parts) n)
                        parts
                      (seq-drop parts (- (length parts) n)))))
    (if sub-parts
        (concat (string-join sub-parts "/") "/")
      "")))

(defun bufferline-duplicates-resolve (buffer live-buffers)
  "Return a cons cell (DIR-PREFIX . BASE-NAME) for BUFFER.
DIR-PREFIX is a string with a trailing slash if BUFFER shares its basename with another buffer, or nil."
  (let* ((file (buffer-file-name buffer))
         (raw-name (buffer-name buffer)))
    (if (not file)
        (cons nil raw-name)
      (let* ((base (file-name-nondirectory file))
             (duplicates (seq-filter
                          (lambda (b)
                            (let ((bf (buffer-file-name b)))
                              (and bf (not (eq b buffer))
                                   (string= (file-name-nondirectory bf) base))))
                          live-buffers)))
        (if (and duplicates bufferline-show-duplicate-prefix)
            (cons (bufferline-duplicates--extract-prefix file bufferline-duplicate-prefix-depth) base)
          (cons nil raw-name))))))

(defun bufferline-duplicates-format-name (buffer live-buffers)
  "Return full formatted name string for BUFFER for measurement purposes."
  (let ((pair (bufferline-duplicates-resolve buffer live-buffers)))
    (if (car pair)
        (concat (car pair) (cdr pair))
      (cdr pair))))

(provide 'bufferline-duplicates)
;;; bufferline-duplicates.el ends here
