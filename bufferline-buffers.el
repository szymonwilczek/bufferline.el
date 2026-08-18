;;; Buffer filtering, sorting, and window truncation -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Szymon Wilczek
;; Author: Szymon Wilczek <swilczek.lx@gmail.com>
;; Version: 0.1.0
;; Package-Requires: ((emacs "28.1") (nerd-icons "0.1.0"))
;; URL: https://github.com/szymonwilczek/bufferline.el
;; Licensed under GPL-3.0.

;;; Code:

(require 'tab-line)
(require 'bufferline-config)
(require 'bufferline-state)
(require 'bufferline-sorters)
(require 'bufferline-duplicates)

(defvar-local bufferline-buffers--left-count 0
  "Number of truncated buffers to the left in current window.")

(defvar-local bufferline-buffers--right-count 0
  "Number of truncated buffers to the right in current window.")

(defun bufferline-buffers-all ()
  "Filter and return sorted list of live user buffers for current window."
  (let ((tabs (seq-filter
               (lambda (buf)
                 (let ((name (buffer-name buf))
                       (mode (buffer-local-value 'major-mode buf)))
                   (and (buffer-live-p buf)
                        (not (string-prefix-p " " name))
                        (not (string-prefix-p "*" name))
                        (not (memq mode bufferline-exclude-modes)))))
               (tab-line-tabs-window-buffers))))

    (dolist (buf tabs)
      (bufferline-state-register buf))

    (bufferline-sorters-apply tabs)))

(defun bufferline-buffers-tab-width (buffer live-tabs)
  "Calculate estimated rendered character width for BUFFER tab."
  (let* ((name (if bufferline-show-duplicate-prefix
                   (bufferline-duplicates-format-name buffer live-tabs)
                 (buffer-name buffer)))
         (len (min (length name) bufferline-max-name-length)))

    ;; 1 char indicator + 2 pad + 2 icon + 1 mid-pad + name + 2 pad + 1 sep
    (+ len 9)))

(defun bufferline-buffers-get ()
  "Calculate visible slice of buffers fitting within current window width,
returning only valid buffer objects and storing left/right truncation counts."
  (let* ((all-tabs (bufferline-buffers-all))
         (active-buf (window-buffer (selected-window)))
         (win-width (max 20 (window-width))))
    (setq bufferline-buffers--left-count 0
          bufferline-buffers--right-count 0)
    (if (or (not bufferline-show-trunc-markers)
            (null all-tabs)
            (<= (length all-tabs) 1))
        all-tabs
      (let* ((pos (or (seq-position all-tabs active-buf) 0))
             (before (seq-take all-tabs pos))
             (current (list (nth pos all-tabs)))
             (after (seq-drop all-tabs (1+ pos)))
             (before-lens (mapcar (lambda (b) (bufferline-buffers-tab-width b all-tabs)) before))
             (current-len (bufferline-buffers-tab-width (car current) all-tabs))
             (after-lens (mapcar (lambda (b) (bufferline-buffers-tab-width b all-tabs)) after))
             (left-count 0)
             (right-count 0)
             (avail-width (- win-width 6)))

        ;; truncate tabs until everything fits in window width
        (while (and (or before after)
                    (> (+ (apply #'+ 0 before-lens)
                          current-len
                          (apply #'+ 0 after-lens)
                          (if (> left-count 0) 6 0)
                          (if (> right-count 0) 6 0))
                       avail-width))
          (let ((before-total (apply #'+ 0 before-lens))
                (after-total (apply #'+ 0 after-lens)))
            (if (and before (>= before-total after-total))
                (progn
                  (setq before (cdr before))
                  (setq before-lens (cdr before-lens))
                  (setq left-count (1+ left-count)))
              (when after
                (setq after (butlast after))
                (setq after-lens (butlast after-lens))
                (setq right-count (1+ right-count))))))

        (setq bufferline-buffers--left-count left-count
              bufferline-buffers--right-count right-count)
        (append before current after)))))

(provide 'bufferline-buffers)
;;; bufferline-buffers.el ends here
