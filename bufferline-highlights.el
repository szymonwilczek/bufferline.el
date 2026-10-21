;;; bufferline-highlights.el --- Face definitions and dynamic theme highlights -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Szymon Wilczek
;; Author: Szymon Wilczek <swilczek.lx@gmail.com>
;; Package-Requires: ((emacs "28.1") (nerd-icons "0.1.0"))
;; URL: https://github.com/szymonwilczek/bufferline.el
;; Licensed under GPL-3.0.

;;; Code:

(require 'bufferline-colors)
(require 'bufferline-config)
(require 'ef-themes nil t)

(defvar bufferline-highlights--theme-version 0
  "Cache-busting counter for tab-line rendering.")

(defun bufferline-highlights-apply (&optional frame)
  "Update bufferline faces according to current theme colors."
  (interactive)
  (setq bufferline-highlights--theme-version (1+ bufferline-highlights--theme-version))
  (let ((frames (if frame (list frame) (frame-list))))
    (dolist (f frames)
      (when (frame-live-p f)
        (with-selected-frame f
          (let* ((graphic (display-graphic-p f))
                 (dark-p (eq (frame-parameter f 'background-mode) 'dark))
                 (theme-bg (face-background 'default f t))
                 (theme-dim (when (fboundp 'ef-themes-get-color-value)
                              (ignore-errors (ef-themes-get-color-value 'bg-dim))))
                 (theme-alt (when (fboundp 'ef-themes-get-color-value)
                              (ignore-errors (ef-themes-get-color-value 'bg-alt))))
                 (bg (bufferline-colors-safe theme-bg (if dark-p "#111111" "#ffffff")))
                 (bg-dim (bufferline-colors-safe
                          theme-dim
                          (if dark-p
                              (bufferline-colors-lighten bg 6)
                            (bufferline-colors-darken bg 6))))
                 (bg-alt (bufferline-colors-safe
                          theme-alt
                          (if dark-p
                              (bufferline-colors-lighten bg 12)
                            (bufferline-colors-darken bg 12))))
                 (bar-box (when (and graphic (> (or bufferline-top-padding 0) 0))
                            `(:line-width (0 . ,bufferline-top-padding) :color ,bg-alt)))
                 (v-pad (or bufferline-tab-padding-vertical 4))
                 (tab-box (when graphic `(:line-width (-1 . ,v-pad) :color ,bg-dim)))
                 (cur-box (when graphic `(:line-width (-1 . ,v-pad) :color ,bg))))

            (set-face-attribute 'tab-line f :background bg-alt :height 1.0 :box bar-box)
            (set-face-attribute 'tab-line-tab f :background bg-dim :box tab-box)
            (set-face-attribute 'tab-line-tab-inactive f :background bg-dim :box tab-box)
            (set-face-attribute 'tab-line-tab-current f :background bg :box cur-box))))))

  (dolist (f (frame-list))
    (dolist (w (window-list f))
      (with-selected-window w
        (set-window-parameter w 'tab-line-cache nil)
        (force-mode-line-update t)))))

(provide 'bufferline-highlights)
;;; bufferline-highlights.el ends here
