;;; bufferline-pick.el --- Quick letter buffer jump picker -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Szymon Wilczek
;; Author: Szymon Wilczek <swilczek.lx@gmail.com>
;; Package-Requires: ((emacs "28.1") (nerd-icons "0.1.0"))
;; URL: https://github.com/szymonwilczek/bufferline.el
;; Licensed under GPL-3.0.

;;; Code:

(require 'bufferline-config)
(require 'bufferline-buffers)

(defun bufferline-pick--assign (buffers)
  "Pair BUFFERS with the letters of `bufferline-pick-alphabet' in order.
Return an alist of (CHAR . BUFFER).  Buffers beyond the length of the
alphabet get no letter and are left out."
  (let ((alphabet (string-to-list bufferline-pick-alphabet))
        items)
    (while (and buffers alphabet)
      (push (cons (pop alphabet) (pop buffers)) items))
    (nreverse items)))

(defvar bufferline-pick--labels nil
  "Alist of (BUFFER . CHAR) drawn on the tabs during an in-place pick.")

(defvar bufferline-pick--window nil
  "Window whose tabs show `bufferline-pick--labels', or nil.")

(defun bufferline-pick-label (buffer)
  "Return the letter to draw on the tab of BUFFER, or nil.
A letter is returned only during an in-place pick, and only while the
tab line of the window the pick runs in is being drawn."
  (and bufferline-pick--window
       (eq (selected-window) bufferline-pick--window)
       (cdr (assq buffer bufferline-pick--labels))))

(defun bufferline-pick--redraw ()
  "Redraw every tab line so pick letters appear or disappear."
  (if (fboundp 'bufferline-ui-refresh)
      (bufferline-ui-refresh)
    (force-mode-line-update t)))

(defun bufferline-pick--read-key (prompt items)
  "Read a key with PROMPT, showing the letters of ITEMS.
ITEMS is an alist of (CHAR . BUFFER).  The letters go into the prompt or,
when `bufferline-pick-in-place' is non-nil, onto the tabs themselves."
  (if (not bufferline-pick-in-place)
      (read-key (concat prompt
                        (mapconcat (lambda (pair)
                                     (format "[%c] %s" (car pair) (buffer-name (cdr pair))))
                                   items
                                   "  ")
                        " "))
    (unwind-protect
        (let ((bufferline-pick--labels
               (mapcar (lambda (pair) (cons (cdr pair) (car pair))) items))
              (bufferline-pick--window (selected-window)))
          (bufferline-pick--redraw)
          (read-key prompt))
      ;; runs once the labels are unbound,
      ;; so the tabs lose their letters even when the pick is quit
      (bufferline-pick--redraw))))

(defun bufferline-pick--read (prompt items)
  "Read a key with PROMPT and return the buffer ITEMS assign to it.
ITEMS is an alist of (CHAR . BUFFER).  Return nil when the key matches
no letter or its buffer has been killed meanwhile."
  (let ((chosen (cdr (assoc (bufferline-pick--read-key prompt items) items))))
    (and chosen (buffer-live-p chosen) chosen)))

(defun bufferline-pick-read-buffer (prompt)
  "Ask for a visible tab by its assigned letter with PROMPT.
Return the chosen live buffer, or nil when the key matches no tab."
  (let ((items (bufferline-pick--assign (bufferline-buffers-get))))
    (when items
      (bufferline-pick--read prompt items))))

;;;###autoload
(defun bufferline-pick ()
  "Interactively jump to a visible buffer by selecting its assigned letter."
  (interactive)
  (let ((items (bufferline-pick--assign (bufferline-buffers-get))))
    (if (null items)
        (message "No buffers to pick")
      (let ((chosen (bufferline-pick--read "Pick buffer: " items)))
        (if chosen
            (switch-to-buffer chosen)
          (message "Pick cancelled"))))))

;;;###autoload
(defun bufferline-pick-close ()
  "Interactively close a buffer by selecting its assigned letter."
  (interactive)
  (let ((items (bufferline-pick--assign (bufferline-buffers-get))))
    (if (null items)
        (message "No buffers to close")
      (let ((chosen (bufferline-pick--read "Close buffer: " items)))
        (if chosen
            (let ((name (buffer-name chosen)))
              (kill-buffer chosen)
              (if (fboundp 'bufferline-ui-refresh)
                  (bufferline-ui-refresh)
                (force-mode-line-update t))
              (message "Closed buffer: %s" name))
          (message "Pick close cancelled"))))))

(provide 'bufferline-pick)
;;; bufferline-pick.el ends here
