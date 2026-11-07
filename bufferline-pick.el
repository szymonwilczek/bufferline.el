;;; bufferline-pick.el --- Quick letter buffer jump picker -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Szymon Wilczek
;; Author: Szymon Wilczek <swilczek.lx@gmail.com>
;; URL: https://github.com/szymonwilczek/bufferline.el
;; Licensed under GPL-3.0.

;;; Code:

(require 'bufferline-config)
(require 'bufferline-buffers)

(declare-function bufferline-close-tab "bufferline-commands" (&optional buffer))

(defun bufferline-pick--assign (buffers)
  "Pair BUFFERS with the letters of `bufferline-pick-alphabet' in order.
Return an alist of (CHAR . BUFFER).  Buffers beyond the length of the
alphabet get no letter and are left out.  BUFFERS may as well be
windows, giving an alist of (CHAR . WINDOW)."
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

(defvar bufferline-pick--window-labels nil
  "Alist of (WINDOW . CHAR) drawn on the windows during a window pick.")

(defun bufferline-pick-window-label (window)
  "Return the letter to draw on the tab line of WINDOW, or nil.
A letter is returned only during an in-place window pick, and only when
`bufferline-pick-window-style' draws letters on tab lines."
  (and (memq bufferline-pick-window-style '(tab-line both))
       (cdr (assq window bufferline-pick--window-labels))))

(defun bufferline-pick--tab-line-drawn-p (window)
  "Return non-nil if bufferline draws a tab line with tabs in WINDOW.
That is not so when the tab line is hidden or replaced through the
`tab-line-format' window parameter, when the buffer of WINDOW has no
tab line, or when WINDOW has no tabs to draw."
  (and (null (window-parameter window 'tab-line-format))
       (buffer-local-value 'tab-line-format (window-buffer window))
       (with-selected-window window
         (bufferline-buffers-all))
       t))

(defun bufferline-pick--overlay-p (window)
  "Return non-nil if the window pick letter of WINDOW goes in an overlay."
  (or (memq bufferline-pick-window-style '(overlay both))
      (not (bufferline-pick-window-label window))
      (not (bufferline-pick--tab-line-drawn-p window))))

(defun bufferline-pick--window-overlay (window char)
  "Return an overlay drawing CHAR large at the top of WINDOW.
The overlay shows only in WINDOW, even when its buffer is shown in other
windows as well, and pushes the text down while it lasts."
  (let* ((start (window-start window))
         (ov (make-overlay start start (window-buffer window)))
         (bar-bg (or (face-background 'tab-line nil t)
                     (face-background 'default nil t)
                     "black"))
         (pick-bg (or (face-foreground bufferline-pick-face nil t)
                      (face-foreground 'default nil t)
                      "white")))
    (overlay-put ov 'window window)
    (overlay-put ov 'priority 1000)
    (overlay-put ov 'bufferline-pick-window window)
    (overlay-put ov 'before-string
                 (concat "\n"
                         (propertize " " 'display '(space :align-to (- center 3)))
                         (propertize (format " %c " char)
                                     'face `(:foreground ,bar-bg :background ,pick-bg
                                                         :weight bold :height 3.0))
                         "\n\n"))
    ov))

(defun bufferline-pick--windows ()
  "Return the windows of the selected frame a tab can be moved to.
They come in frame order, from the top left one, and leave out the
selected window and every window dedicated to its buffer."
  (seq-remove (lambda (win)
                (or (eq win (selected-window))
                    (window-dedicated-p win)))
              (window-list nil 'no-minibuf (frame-first-window))))

(defun bufferline-pick--extra-hint (extra)
  "Return the prompt text listing the keys of EXTRA with their labels.
EXTRA is an alist of (CHAR . LABEL)."
  (mapconcat (lambda (pair) (format "[%c] %s" (car pair) (cdr pair)))
             extra
             "  "))

(defun bufferline-pick--read-window-key (prompt items &optional extra)
  "Read a key with PROMPT, showing the letters of ITEMS and keys of EXTRA.
ITEMS is an alist of (CHAR . WINDOW) and EXTRA one of (CHAR . LABEL).
The letters go into the prompt, naming the buffer each window shows,
or, when `bufferline-pick-in-place' is non-nil, onto the windows
themselves, where `bufferline-pick-window-style' says.  The keys of
EXTRA always go into the prompt, with their labels."
  (if (not bufferline-pick-in-place)
      (read-key (concat prompt
                        (mapconcat #'identity
                                   (delete ""
                                           (list
                                            (mapconcat (lambda (pair)
                                                         (format "[%c] %s" (car pair)
                                                                 (buffer-name (window-buffer (cdr pair)))))
                                                       items
                                                       "  ")
                                            (bufferline-pick--extra-hint extra)))
                                   "  ")
                        " "))
    (let (overlays)
      (unwind-protect
          (let ((bufferline-pick--window-labels
                 (mapcar (lambda (pair) (cons (cdr pair) (car pair))) items)))
            (dolist (pair items)
              (when (bufferline-pick--overlay-p (cdr pair))
                (push (bufferline-pick--window-overlay (cdr pair) (car pair)) overlays)))
            (bufferline-pick--redraw)
            (read-key (if extra
                          (concat prompt (bufferline-pick--extra-hint extra) " ")
                        prompt)))
        (mapc #'delete-overlay overlays)
        (bufferline-pick--redraw)))))

(defun bufferline-pick-read-window (prompt &optional windows extra)
  "Ask for one of WINDOWS by its assigned letter with PROMPT.
WINDOWS defaults to `bufferline-pick--windows'.  Return the chosen live
window, or nil when there is nothing to choose or the key matches no
window.  EXTRA is an alist of (CHAR . LABEL) of further keys to offer,
listed in the prompt with their labels; pressing one of them returns
its CHAR.  A window letter takes precedence over an EXTRA key."
  (let ((items (bufferline-pick--assign (or windows (bufferline-pick--windows)))))
    (when (or items extra)
      (let* ((key (bufferline-pick--read-window-key prompt items extra))
             (chosen (cdr (assoc key items))))
        (cond (chosen (and (window-live-p chosen) chosen))
              ((assoc key extra) key))))))

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
              (bufferline-close-tab chosen)
              (message "Closed buffer: %s" name))
          (message "Pick close cancelled"))))))

(provide 'bufferline-pick)
;;; bufferline-pick.el ends here
