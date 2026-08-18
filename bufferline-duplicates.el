;;; bufferline-duplicates.el --- Disambiguate buffers with identical basenames -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Szymon Wilczek
;; Author: Szymon Wilczek <swilczek.lx@gmail.com>
;; Version: 0.1.0
;; Package-Requires: ((emacs "28.1") (nerd-icons "0.1.0"))
;; URL: https://github.com/szymonwilczek/bufferline.el
;; Licensed under GPL-3.0.

;;; Code:

(defun bufferline-duplicates-format-name (buffer live-buffers)
  "Return formatted name for BUFFER, prepending parent directory if duplicated."
  (let* ((file (buffer-file-name buffer))
         (raw-name (buffer-name buffer)))
    (if (not file)
        raw-name
      (let* ((base (file-name-nondirectory file))
             (duplicates (seq-filter
                          (lambda (b)
                            (let ((bf (buffer-file-name b)))
                              (and bf (not (eq b buffer))
                                   (string= (file-name-nondirectory bf) base))))
                          live-buffers)))
        (if duplicates
            (let* ((parent-dir (file-name-nondirectory (directory-file-name (file-name-directory file)))))
              (format "%s/%s" parent-dir base))
          raw-name)))))

(provide 'bufferline-duplicates)
;;; bufferline-duplicates.el ends here
