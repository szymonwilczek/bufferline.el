;;; bufferline-commands.el --- Interactive navigation and manipulation commands -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Szymon Wilczek
;; Author: Szymon Wilczek <swilczek.lx@gmail.com>
;; URL: https://github.com/szymonwilczek/bufferline.el
;; Licensed under GPL-3.0.

;;; Code:

(require 'cl-lib)
(require 'bufferline-buffers)
(require 'bufferline-state)
(require 'bufferline-pick)
(require 'bufferline-ui)

;;;###autoload
(defun bufferline-next-tab ()
  "Switch cyclically to the next bufferline tab."
  (interactive)
  (let* ((tabs (bufferline-buffers-all))
         (pos (seq-position tabs (current-buffer))))
    (if pos
        (switch-to-buffer (nth (if (= pos (1- (length tabs))) 0 (1+ pos)) tabs))
      (when tabs (switch-to-buffer (car tabs))))))

;;;###autoload
(defun bufferline-prev-tab ()
  "Switch cyclically to the previous bufferline tab."
  (interactive)
  (let* ((tabs (bufferline-buffers-all))
         (pos (seq-position tabs (current-buffer))))
    (if pos
        (switch-to-buffer (nth (if (= pos 0) (1- (length tabs)) (1- pos)) tabs))
      (when tabs (switch-to-buffer (car (last tabs)))))))

;;;###autoload
(defun bufferline-close-tab (&optional buffer)
  "Close the tab of BUFFER in the selected window.
BUFFER defaults to the current buffer.  When the window shows it, the
tab to its right takes its place, or the one to its left when it was
the last tab.  A buffer that is no tab, like a terminal, makes way for
the tab the window showed most recently.

When no other tab is left, the window is closed with it, provided
`window-deletable-p' allows that.  Otherwise the buffer is killed and
Emacs decides what the window shows next.

The buffer is killed only when no other window shows it or has it as a
tab; otherwise only its tab in the selected window goes.  When killing
it is refused, for example by declining to discard unsaved changes,
the window shows it again."
  (interactive)
  (let* ((buf (or buffer (current-buffer)))
         (win (selected-window))
         (shown (eq buf (window-buffer win)))
         (next (bufferline-commands--next-tab buf win))
         (kept (bufferline-commands--tab-elsewhere-p buf win)))
    (cond
     ((and next (not shown))
      (if kept
          (bufferline-buffers-forget buf win)
        (kill-buffer buf)))
     (next
      (let ((start (window-start win))
            (point (window-point win)))
        (switch-to-buffer next nil t)
        (if kept
            (bufferline-buffers-forget buf win)
          (unless (kill-buffer buf)
            (set-window-buffer-start-and-point win buf start point)))))
     ((eq (window-deletable-p win) t)
      (if kept
          (delete-window win)
        (bufferline-commands--kill-with-window buf win)))
     (t
      (kill-buffer buf)))
    (if (fboundp 'bufferline-ui-refresh)
        (bufferline-ui-refresh)
      (force-mode-line-update t))))

(defun bufferline-commands--next-tab (buffer window)
  "Return the tab WINDOW shows once the tab of BUFFER is closed, or nil.
That is the tab right of BUFFER, else the one left of it.  When BUFFER
is no tab, it is the tab WINDOW showed most recently."
  (let* ((tabs (with-selected-window window (bufferline-buffers-all)))
         (pos (seq-position tabs buffer)))
    (if pos
        (or (nth (1+ pos) tabs)
            (and (> pos 0) (nth (1- pos) tabs)))
      (seq-find (lambda (prev) (memq prev tabs))
                (mapcar #'car (window-prev-buffers window))))))

(defun bufferline-commands--tab-elsewhere-p (buffer window)
  "Return non-nil if a window other than WINDOW shows BUFFER or has its tab."
  (seq-some (lambda (other)
              (and (not (eq other window))
                   (or (eq (window-buffer other) buffer)
                       (assq buffer (window-prev-buffers other))
                       (memq buffer (window-next-buffers other)))))
            (window-list-1 nil 'nomini t)))

(defun bufferline-commands--kill-with-window (buffer window)
  "Kill BUFFER and close WINDOW, which shows it and can be deleted.
WINDOW is dedicated to BUFFER while it is killed, so `kill-buffer'
deletes it, and only when the killing goes through.  Any question that
killing asks is thus asked while WINDOW still shows BUFFER."
  (let ((dedicated (window-dedicated-p window)))
    (set-window-dedicated-p window t)
    (unwind-protect
        (kill-buffer buffer)
      (when (window-live-p window)
        (set-window-dedicated-p window dedicated)))))

(defun bufferline-commands--posn-tab (posn)
  "Return the buffer of the tab at mouse position POSN.
Return nil when POSN is not over a tab."
  (let* ((clicked (posn-string posn))
         (tab (and clicked
                   (get-text-property (or (cdr clicked) 0) 'tab (car clicked)))))
    (if (bufferp tab) tab (cdr (assq 'buffer tab)))))

(defun bufferline-commands--in-clicked-window (event command)
  "Call COMMAND in the window whose tab line mouse EVENT clicked.
That window is made selected only while COMMAND runs."
  (let ((window (posn-window (event-start event))))
    (when (window-live-p window)
      (with-selected-window window
        (funcall command)))))

(defun bufferline-prev-tab-at-click (event)
  "Switch to the previous tab in the window whose tab line EVENT clicked.
Bound to mouse-1 on the button drawn by
`bufferline-show-navigation-buttons'."
  (interactive "e")
  (bufferline-commands--in-clicked-window event #'bufferline-prev-tab))

(defun bufferline-next-tab-at-click (event)
  "Switch to the next tab in the window whose tab line EVENT clicked.
Bound to mouse-1 on the button drawn by
`bufferline-show-navigation-buttons'."
  (interactive "e")
  (bufferline-commands--in-clicked-window event #'bufferline-next-tab))

(defun bufferline-close-tab-at-click (event)
  "Close the tab whose close button was clicked with mouse EVENT.
The tab is closed in the window whose tab line was clicked, which stays
as selected as it was."
  (interactive "e")
  (let* ((posn (event-start event))
         (window (posn-window posn))
         (buffer (bufferline-commands--posn-tab posn)))
    (when (and (buffer-live-p buffer) (window-live-p window))
      (with-selected-window window
        (bufferline-close-tab buffer)))))

;;;###autoload
(defun bufferline-new-tab ()
  "Open a new empty buffer in the selected window, giving it a tab.
The buffer is named untitled, numbered when that name is taken, and
starts in the default `major-mode'."
  (interactive)
  (switch-to-buffer (generate-new-buffer-name "untitled"))
  (if (fboundp 'bufferline-ui-refresh)
      (bufferline-ui-refresh)
    (force-mode-line-update t)))

(defun bufferline-new-tab-at-click (event)
  "Open a new tab in the window whose new tab button mouse EVENT clicked.
That window is selected and `bufferline-new-tab-function' called there."
  (interactive "e")
  (let ((window (posn-window (event-start event))))
    (when (window-live-p window)
      (select-window window)
      (if (commandp bufferline-new-tab-function)
          (call-interactively bufferline-new-tab-function)
        (funcall bufferline-new-tab-function)))))

(defun bufferline-commands--close-buffers (buffers)
  "Kill BUFFERS, redraw the bufferline and return how many were closed.
Pinned buffers are left open while `bufferline-close-keep-pinned' is
non-nil.  A buffer whose killing is refused, for example by declining
to discard its unsaved changes, stays open and is not counted."
  (let ((closed 0))
    (dolist (buf buffers)
      (when (and (buffer-live-p buf)
                 (not (and bufferline-close-keep-pinned
                           (bufferline-state-pinned-p buf)))
                 (kill-buffer buf))
        (setq closed (1+ closed))))
    (if (fboundp 'bufferline-ui-refresh)
        (bufferline-ui-refresh)
      (force-mode-line-update t))
    (if (= closed 0)
        (message "No tabs to close")
      (message "Closed %d tab%s" closed (if (= closed 1) "" "s")))
    closed))

(defun bufferline-commands--tabs-beside (side)
  "Return the tabs on SIDE of the current one, `left' or `right'."
  (let* ((tabs (bufferline-buffers-all))
         (pos (or (seq-position tabs (current-buffer))
                  (user-error "Current buffer is not a tab"))))
    (if (eq side 'left)
        (seq-take tabs pos)
      (seq-drop tabs (1+ pos)))))

;;;###autoload
(defun bufferline-close-other-tabs ()
  "Close every tab of the selected window except the current one.
Pinned tabs stay open while `bufferline-close-keep-pinned' is non-nil."
  (interactive)
  (bufferline-commands--close-buffers
   (delq (current-buffer) (bufferline-buffers-all))))

;;;###autoload
(defun bufferline-close-tabs-to-right ()
  "Close every tab to the right of the current one.
Pinned tabs stay open while `bufferline-close-keep-pinned' is non-nil."
  (interactive)
  (bufferline-commands--close-buffers (bufferline-commands--tabs-beside 'right)))

;;;###autoload
(defun bufferline-close-tabs-to-left ()
  "Close every tab to the left of the current one.
Pinned tabs stay open while `bufferline-close-keep-pinned' is non-nil."
  (interactive)
  (bufferline-commands--close-buffers (bufferline-commands--tabs-beside 'left)))

(defun bufferline-commands--check-reorder (a b)
  "Signal a `user-error' unless tab A may take the place of tab B."
  (unless (eq bufferline-sort-by 'fifo)
    (user-error "Tabs can only be reordered when `bufferline-sort-by' is fifo"))
  (unless (eq (bufferline-state-pinned-p a) (bufferline-state-pinned-p b))
    (user-error "Pinned tabs stay ahead of unpinned ones")))

(defun bufferline-commands--swap-order (a b)
  "Swap the positions of tabs A and B, then redraw the bufferline."
  (bufferline-commands--check-reorder a b)
  (let ((id (buffer-local-value 'bufferline-state--tab-order-id a)))
    (with-current-buffer a
      (setq bufferline-state--tab-order-id
            (buffer-local-value 'bufferline-state--tab-order-id b)))
    (with-current-buffer b
      (setq bufferline-state--tab-order-id id)))
  (if (fboundp 'bufferline-ui-refresh)
      (bufferline-ui-refresh)
    (force-mode-line-update t)))

(defun bufferline-commands--move-tab (step)
  "Swap the current tab with its neighbour STEP positions away (1 or -1)."
  (let* ((buf (current-buffer))
         (tabs (bufferline-buffers-all))
         (pos (or (seq-position tabs buf)
                  (user-error "Current buffer is not a tab")))
         (target (+ pos step)))
    (when (or (< target 0) (>= target (length tabs)))
      (user-error "Tab is already the %s one" (if (< step 0) "first" "last")))
    (bufferline-commands--swap-order buf (nth target tabs))))

;;;###autoload
(defun bufferline-move-tab-right ()
  "Move the current tab one position to the right."
  (interactive)
  (bufferline-commands--move-tab 1))

;;;###autoload
(defun bufferline-move-tab-left ()
  "Move the current tab one position to the left."
  (interactive)
  (bufferline-commands--move-tab -1))

(defun bufferline-commands--move-tab-to (buffer target)
  "Move the tab of BUFFER into the place of the tab of TARGET.
The tabs in between shift by one toward the place BUFFER left, so
BUFFER lands right after TARGET when moved rightward and right before
it when moved leftward.  Only the tabs of the selected window are
renumbered, keeping the order numbers they already held."
  (bufferline-commands--check-reorder buffer target)
  (let* ((tabs (bufferline-buffers-all))
         (pos (seq-position tabs target))
         (rest (remq buffer tabs))
         (order (append (seq-take rest pos) (list buffer) (seq-drop rest pos)))
         (ids (sort (mapcar (lambda (buf)
                              (buffer-local-value 'bufferline-state--tab-order-id buf))
                            tabs)
                    #'<)))
    (cl-mapc (lambda (buf id)
               (with-current-buffer buf
                 (setq bufferline-state--tab-order-id id)))
             order ids))
  (if (fboundp 'bufferline-ui-refresh)
      (bufferline-ui-refresh)
    (force-mode-line-update t)))

(defun bufferline-drag-tab (event)
  "Move the tab dragged with mouse EVENT to where it was dropped.
A tab dropped on another tab of the same tab line takes its place, as
with `bufferline-commands--move-tab-to'.  A tab dropped anywhere in another
window of the same frame moves to that window as with
`bufferline-move-tab-to-window', and focus follows it.  Dropped on one
of its tabs, it takes the place of that tab, unless the tabs may not be
reordered there, and dropped elsewhere in it, it joins the end of its
tabs.  A tab dropped anywhere else stays where it was."
  (interactive "e")
  (let* ((start (event-start event))
         (end (event-end event))
         (window (posn-window start))
         (drop (posn-window end))
         (buffer (bufferline-commands--posn-tab start))
         (target (bufferline-commands--posn-tab end)))
    (when (and (buffer-live-p buffer)
               (window-live-p window))
      (cond
       ((eq window drop)
        (when (and (buffer-live-p target)
                   (not (eq buffer target)))
          (with-selected-window window
            (when (and (memq buffer (bufferline-buffers-all))
                       (memq target (bufferline-buffers-all)))
              (bufferline-commands--move-tab-to buffer target)))))
       ((and (windowp drop)
             (window-live-p drop)
             (not (window-minibuffer-p drop))
             (eq (window-frame drop) (window-frame window)))
        (select-window window)
        (when (memq buffer (bufferline-buffers-all))
          (bufferline-commands--move-to-window drop buffer)
          (when (and (buffer-live-p target)
                     (not (eq buffer target))
                     (memq target (bufferline-buffers-all)))
            (condition-case nil
                (bufferline-commands--move-tab-to buffer target)
              (user-error nil)))))))))

(defun bufferline-swap-tab ()
  "Swap the current tab with another one picked by its letter."
  (interactive)
  (let ((buf (current-buffer)))
    (unless (memq buf (bufferline-buffers-all))
      (user-error "Current buffer is not a tab"))
    (let ((other (bufferline-pick-read-buffer
                  (format "Swap %s with: " (buffer-name buf)))))
      (cond
       ((null other) (message "Swap cancelled"))
       ((eq other buf) (message "That is the current tab"))
       (t (bufferline-commands--swap-order buf other))))))

(defun bufferline-commands--move-to-window (target &optional buffer)
  "Move the tab of BUFFER to window TARGET and follow it there.
BUFFER defaults to the current buffer and must be a tab of the selected
window.  The tab joins the end of TARGET's tabs.  When it was the last
tab of its window, that window is closed once the tab has moved."
  (let* ((buf (or buffer (current-buffer)))
         (source (selected-window))
         (tabs (bufferline-buffers-all)))
    (unless (memq buf tabs)
      (user-error (if buffer "Buffer is not a tab here" "Current buffer is not a tab")))
    (when (eq target source)
      (user-error "The tab is already in that window"))
    (when (window-dedicated-p target)
      (user-error "That window is dedicated to its buffer"))
    (let ((rest (delq buf tabs)))
      (when (and (null rest) (not (eq (window-deletable-p source) t)))
        (user-error "Cannot close this window after moving its last tab"))
      (when rest
        (when (eq (window-buffer source) buf)
          (switch-to-buffer (car rest) nil t))
        (bufferline-buffers-forget buf source))
      (bufferline-state-move-to-end buf)
      (select-window target)
      (switch-to-buffer buf nil t)
      (unless rest
        (delete-window source)))
    (if (fboundp 'bufferline-ui-refresh)
        (bufferline-ui-refresh)
      (force-mode-line-update t))))

(defun bufferline-commands--move-in-direction (direction)
  "Move the current tab to the window in DIRECTION and follow it there.
DIRECTION is one of `left', `right', `above' or `below'.  See
`bufferline-commands--move-to-window'."
  (let ((target (window-in-direction direction)))
    (unless target
      (user-error "No window %s" (if (memq direction '(left right))
                                     (format "to the %s" direction)
                                   direction)))
    (when (window-dedicated-p target)
      (user-error "Window %s is dedicated to its buffer" direction))
    (bufferline-commands--move-to-window target)))

;;;###autoload
(defun bufferline-move-tab-to-window-left ()
  "Move the current tab to the window on the left."
  (interactive)
  (bufferline-commands--move-in-direction 'left))

;;;###autoload
(defun bufferline-move-tab-to-window-right ()
  "Move the current tab to the window on the right."
  (interactive)
  (bufferline-commands--move-in-direction 'right))

;;;###autoload
(defun bufferline-move-tab-to-window-up ()
  "Move the current tab to the window above."
  (interactive)
  (bufferline-commands--move-in-direction 'above))

;;;###autoload
(defun bufferline-move-tab-to-window-down ()
  "Move the current tab to the window below."
  (interactive)
  (bufferline-commands--move-in-direction 'below))

;;;###autoload
(defun bufferline-move-tab-to-window (&optional pick)
  "Move the current tab to a window picked by its letter and follow it.
Every other window of the frame that is not dedicated to its buffer gets
a letter, as `bufferline-pick-window-style' draws it, and the keys of
`bufferline-move-tab-split-keys' move the tab to a new window split off
the selected one instead.  When there is only one choice and
`bufferline-pick-window-auto-select' is non-nil, the tab moves there
without asking.

With a prefix argument PICK, first pick the tab to move by its letter,
as `bufferline-pick' does, instead of moving the current one."
  (interactive "P")
  (let ((buf (if pick
                 (bufferline-pick-read-buffer "Move tab: ")
               (current-buffer))))
    (if buf
        (bufferline-commands--move-to-picked-window buf)
      (message "Move cancelled"))))

(defun bufferline-commands--move-to-picked-window (buf)
  "Move the tab of BUF to a window picked by its letter and follow it.
See `bufferline-move-tab-to-window'."
  (let* ((tabs (bufferline-buffers-all))
         (windows (bufferline-pick--windows))
         (splits (when (cdr tabs)
                   (mapcar (lambda (pair)
                             (cons (car pair) (format "split %s" (cdr pair))))
                           bufferline-move-tab-split-keys))))
    (unless (memq buf tabs)
      (user-error "Current buffer is not a tab"))
    (unless (or windows splits)
      (user-error "No other window to move the tab to"))
    (let ((choice (cond ((not (and bufferline-pick-window-auto-select
                                   (= (+ (length windows) (length splits)) 1)))
                         (bufferline-pick-read-window
                          (format "Move %s to window: " (buffer-name buf))
                          windows splits))
                        (windows (car windows))
                        (t (caar splits)))))
      (cond ((windowp choice)
             (bufferline-commands--move-to-window choice buf))
            (choice
             (bufferline-commands--move-to-window
              (split-window nil nil (cdr (assq choice bufferline-move-tab-split-keys)))
              buf))
            (t (message "Move cancelled"))))))

;;;###autoload
(defun bufferline-toggle-pin (&optional buffer)
  "Toggle pinned status of current or specified BUFFER."
  (interactive)
  (let ((buf (or buffer (current-buffer))))
    (bufferline-state-toggle-pin buf)
    (if (fboundp 'bufferline-ui-refresh)
        (bufferline-ui-refresh)
      (force-mode-line-update t))
    (message "Buffer %s is now %s"
             (buffer-name buf)
             (if (bufferline-state-pinned-p buf) "pinned" "unpinned"))))

(provide 'bufferline-commands)
;;; bufferline-commands.el ends here
