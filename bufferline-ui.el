;;; bufferline-ui.el --- Rendering engine and viewport scroll management -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Szymon Wilczek
;; Author: Szymon Wilczek <swilczek.lx@gmail.com>
;; Version: 0.1.0
;; Package-Requires: ((emacs "28.1") (nerd-icons "0.1.0"))
;; URL: https://github.com/szymonwilczek/bufferline.el
;; Licensed under GPL-3.0.

;;; Code:

(require 'tab-line)
(require 'nerd-icons nil t)
(require 'ef-themes nil t)
(require 'bufferline-constants)
(require 'bufferline-config)
(require 'bufferline-colors)
(require 'bufferline-highlights)
(require 'bufferline-duplicates)
(require 'bufferline-diagnostics)
(require 'bufferline-numbers)
(require 'bufferline-buffers)

(defun bufferline-ui-tab-name-format (tab tabs)
  "Format single TAB buffer with icons, indicators, disambiguation, and edge truncation markers."
  (let* ((buffer (if (bufferp tab) tab (cdr (assq 'buffer tab))))
         (active (if (bufferp tab) (eq tab (current-buffer)) (cdr (assq 'selected tab))))
         (bg-face (if active 'tab-line-tab-current 'tab-line-tab-inactive))
         (bg-color (bufferline-colors-safe (face-background bg-face nil t) "#111111"))
         (bar-bg (bufferline-colors-safe (face-background 'tab-line nil t) "#111111"))
         (theme-comment (ignore-errors (ef-themes-with-colors comment)))
         (keyword-color (bufferline-colors-safe (face-foreground 'font-lock-keyword-face nil t) "#ef7f00"))
         (fg-default-raw (face-foreground 'default nil t))
         (fg-default (bufferline-colors-safe fg-default-raw "#ffffff"))
         (fg-main (if active fg-default "#ffffff"))
         (fg-comment (bufferline-colors-safe theme-comment (bufferline-colors-safe (face-foreground 'font-lock-comment-face nil t) "#888888")))
         (sep-color keyword-color)

         ;; disambiguate and truncate name
         (full-name (if bufferline-show-duplicate-prefix
                        (bufferline-duplicates-format-name buffer tabs)
                      (buffer-name buffer)))
         (display-name (if (> (length full-name) bufferline-max-name-length)
                           (concat (substring full-name 0 (1- bufferline-max-name-length)) bufferline-constants-ellipsis)
                         full-name))

         ;; separator / indicator
         (sep-pair (or (cdr (assq bufferline-separator-style bufferline-constants-separators)) '("┃" " ")))
         (sep (propertize (car sep-pair) 'face `(:foreground ,sep-color :background ,bg-color :weight semi-bold)))
         (empty-sep (propertize (cadr sep-pair) 'face `(:background ,bg-color)))

         ;; file icon
         (file-or-name (or (buffer-file-name buffer) (buffer-name buffer)))
         (icon-raw (when (and bufferline-show-buffer-icons (fboundp 'nerd-icons-icon-for-file))
                     (let ((nerd-icons-color-icons t))
                       (nerd-icons-icon-for-file file-or-name :v-adjust -0.05 :height bufferline-icon-size))))
         (icon-hex (if icon-raw (bufferline-colors-get-icon-hex icon-raw (if active fg-main fg-comment)) fg-comment))
         (icon-str (if icon-raw (substring-no-properties icon-raw) " "))
         (icon (propertize icon-str 'face `(:foreground ,icon-hex :background ,bg-color)))

         ;; number prefix and diagnostics
         (index (seq-position tabs buffer))
         (num-prefix (if index (bufferline-numbers-format buffer index) ""))
         (diag-badge (if bufferline-show-diagnostics (bufferline-diagnostics-badge buffer) ""))

         ;; text label
         (text-face (if active
                        `(:foreground ,fg-main :weight demi-bold :slant italic :background ,bg-color)
                      `(:foreground ,fg-comment :weight normal :slant normal :background ,bg-color)))
         (name (propertize (concat num-prefix display-name diag-badge) 'face text-face))
         (pad (propertize "  " 'face `(:background ,bg-color)))
         (mid-pad (propertize " " 'face `(:background ,bg-color)))

         (tab-str (concat (if active sep empty-sep) pad icon mid-pad name pad))

         ;; truncation markers rendered on outer edges of first/last tab
         (is-first (eq buffer (car tabs)))
         (is-last (eq buffer (car (last tabs))))
         (left-marker (when (and is-first (> (or bufferline-buffers--left-count 0) 0))
                        (let* ((arrow-face `(:foreground ,keyword-color :weight bold :background ,bar-bg))
                               (count-face `(:foreground ,fg-comment :weight normal :background ,bar-bg))
                               (mstr (concat (propertize " " 'face `(:background ,bar-bg))
                                             (propertize (format "%d" bufferline-buffers--left-count) 'face count-face)
                                             (propertize (format " %s  " bufferline-left-trunc-marker) 'face arrow-face))))
                          (propertize mstr
                                      'help-echo "Previous hidden buffers"
                                      'mouse-face 'highlight
                                      'keymap (let ((km (make-sparse-keymap)))
                                                (define-key km [tab-line mouse-1] #'bufferline-prev-tab)
                                                km)))))
         (right-marker (when (and is-last (> (or bufferline-buffers--right-count 0) 0))
                         (let* ((arrow-face `(:foreground ,keyword-color :weight bold :background ,bar-bg))
                                (count-face `(:foreground ,fg-comment :weight normal :background ,bar-bg))
                                (mstr (concat (propertize (format "  %s " bufferline-right-trunc-marker) 'face arrow-face)
                                              (propertize (format "%d" bufferline-buffers--right-count) 'face count-face)
                                              (propertize " " 'face `(:background ,bar-bg)))))
                           (propertize mstr
                                       'help-echo "Next hidden buffers"
                                       'mouse-face 'highlight
                                       'keymap (let ((km (make-sparse-keymap)))
                                                 (define-key km [tab-line mouse-1] #'bufferline-next-tab)
                                                 km))))))

    (concat left-marker
            (propertize tab-str
                        'tab tab
                        'theme-version bufferline-highlights--theme-version
                        'help-echo nil
                        'mouse-face nil
                        'keymap tab-line-tab-map)
            right-marker)))

(defun bufferline-ui-follow-active (&rest _)
  "Update window tab cache to recompute visible buffer window."
  (let ((win (selected-window)))
    (when win
      (set-window-parameter win 'tab-line-cache nil)
      (force-mode-line-update t))))

(provide 'bufferline-ui)
;;; bufferline-ui.el ends here
