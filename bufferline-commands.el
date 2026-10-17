;;; bufferline-commands.el --- Interactive navigation and manipulation commands -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Szymon Wilczek
;; Author: Szymon Wilczek <swilczek.lx@gmail.com>
;; Version: 0.1.0
;; Package-Requires: ((emacs "28.1") (nerd-icons "0.1.0"))
;; URL: https://github.com/szymonwilczek/bufferline.el
;; Licensed under GPL-3.0.

;;; Code:

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
  "Close current or specified BUFFER without disturbing window layout."
  (interactive)
  (let* ((buf (or buffer (current-buffer)))
         (win (selected-window))
         (tabs (delq buf (bufferline-buffers-all))))
    (when (eq buf (window-buffer win))
      (if tabs
          (switch-to-buffer (car tabs))
        (previous-buffer)))
    (kill-buffer buf)
    (if (fboundp 'bufferline-ui-refresh)
        (bufferline-ui-refresh)
      (force-mode-line-update t))))

(defun bufferline-commands--swap-order (a b)
  "Swap the positions of tabs A and B, then redraw the bufferline."
  (unless (eq bufferline-sort-by 'fifo)
    (user-error "Tabs can only be reordered when `bufferline-sort-by' is fifo"))
  (unless (eq (bufferline-state-pinned-p a) (bufferline-state-pinned-p b))
    (user-error "Pinned tabs stay ahead of unpinned ones"))
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

;;;###autoload
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
