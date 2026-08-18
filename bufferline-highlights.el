;;; bufferline-highlights.el --- Face definitions and dynamic theme highlights -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Szymon Wilczek
;; Author: Szymon Wilczek <swilczek.lx@gmail.com>
;; Version: 0.1.0
;; Package-Requires: ((emacs "28.1") (nerd-icons "0.1.0"))
;; URL: https://github.com/szymonwilczek/bufferline.el
;; Licensed under GPL-3.0.

;;; Code:

(require 'bufferline-colors)
(require 'ef-themes nil t)

(defvar bufferline-highlights--theme-version 0
  "Cache-busting counter for tab-line rendering.")

(defun bufferline-highlights-apply (&optional frame)
  "Update bufferline faces according to current theme colors."
  (interactive)
  (setq bufferline-highlights--theme-version (1+ bufferline-highlights--theme-version))
  (with-selected-frame (or frame (selected-frame))
    (let* ((bg-raw (face-background 'default nil t))
           (bg (bufferline-colors-safe bg-raw "#111111"))
           (dark-p (eq (frame-parameter nil 'background-mode) 'dark))
           (bg-dim (or (ignore-errors (ef-themes-with-colors bg-dim))
                       (if dark-p
                           (bufferline-colors-darken bg 5)
                         (bufferline-colors-lighten bg 5))))
           (bg-alt (or (ignore-errors (ef-themes-with-colors bg-alt))
                       (if dark-p
                           (bufferline-colors-darken bg 10)
                         (bufferline-colors-lighten bg 10)))))

      (set-face-attribute 'tab-line nil :background bg-alt :height 1.0 :box nil)
      (set-face-attribute 'tab-line-tab nil :background bg-dim :box `(:line-width (-1 . 4) :color ,bg-dim))
      (set-face-attribute 'tab-line-tab-inactive nil :background bg-dim :box `(:line-width (-1 . 4) :color ,bg-dim))
      (set-face-attribute 'tab-line-tab-current nil :background bg :box `(:line-width (-1 . 4) :color ,bg))))

  (dolist (f (frame-list))
    (dolist (w (window-list f))
      (with-selected-window w
        (set-window-parameter w 'tab-line-cache nil)
        (force-mode-line-update t)))))

(provide 'bufferline-highlights)
;;; bufferline-highlights.el ends here
