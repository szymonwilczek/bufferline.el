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
         (indicator-color (bufferline-colors-safe (face-foreground bufferline-indicator-face nil t) fg-main))

         ;; disambiguate and format duplicate directory prefix
         (name-pair (bufferline-duplicates-resolve buffer tabs))
         (dir-prefix (car name-pair))
         (base-name (cdr name-pair))
         (display-base (if (> (length base-name) bufferline-max-name-length)
                           (concat (substring base-name 0 (1- bufferline-max-name-length)) bufferline-constants-ellipsis)
                         base-name))

         ;; directory prefix face: italic, light weight, comment color
         (dir-face `(:foreground ,fg-comment :weight light :slant italic :background ,bg-color))
         (dir-str (if dir-prefix (propertize dir-prefix 'face dir-face) ""))

         ;; separator / indicator
         (sep-pair (or (cdr (assq bufferline-separator-style bufferline-constants-separators)) '("▎" " ")))
         (sep-pixel-width (or bufferline-indicator-width
                              (cond ((eq bufferline-separator-style 'thin) 2)
                                    ((eq bufferline-separator-style 'thick) 5)
                                    ((eq bufferline-separator-style 'vertical) 3)
                                    (t nil))))
         (sep (if sep-pixel-width
                  (propertize " " 'display `(space :width (,sep-pixel-width)) 'face `(:background ,indicator-color))
                (propertize (car sep-pair) 'face `(:foreground ,indicator-color :background ,bg-color :weight normal))))
         (empty-sep (if sep-pixel-width
                        (propertize " " 'display `(space :width (,sep-pixel-width)) 'face `(:background ,bg-color))
                      (propertize (cadr sep-pair) 'face `(:background ,bg-color))))

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
         (name (concat (propertize num-prefix 'face text-face)
                       dir-str
                       (propertize (concat display-base diag-badge) 'face text-face)))

         ;; read-only indicator
         (ro-icon (if (and bufferline-show-read-only (buffer-local-value 'buffer-read-only buffer))
                      (let ((ro-fg (bufferline-colors-safe (face-foreground 'font-lock-doc-face nil t) "#888888")))
                        (propertize (format " %s" bufferline-read-only-icon) 'face `(:foreground ,ro-fg :background ,bg-color)))
                    ""))

         ;; modified indicator
         (mod-icon (if (and bufferline-show-modified (buffer-modified-p buffer))
                       (let ((mod-fg (bufferline-colors-safe (face-foreground 'font-lock-warning-face nil t) "#ff9e3b")))
                         (propertize (format " %s" bufferline-modified-icon) 'face `(:foreground ,mod-fg :background ,bg-color :weight bold)))
                     ""))

         ;; pin indicator
         (pin-icon (if (and bufferline-show-pinned (buffer-local-value 'bufferline-state--pinned buffer))
                       (let ((pin-fg (bufferline-colors-safe (face-foreground 'font-lock-keyword-face nil t) "#ef7f00")))
                         (propertize (format "%s " bufferline-pinned-icon) 'face `(:foreground ,pin-fg :background ,bg-color :weight bold)))
                     ""))

         (post-pad-str (if (integerp bufferline-tab-padding-horizontal)
                           (make-string (max 0 bufferline-tab-padding-horizontal) ?\s)
                         (or bufferline-tab-padding-horizontal "  ")))
         (mid-pad-str (if (integerp bufferline-icon-spacing)
                          (make-string (max 0 bufferline-icon-spacing) ?\s)
                        (or bufferline-icon-spacing " ")))
         (pre-pad (propertize " " 'face `(:background ,bg-color)))
         (mid-pad (propertize mid-pad-str 'face `(:background ,bg-color)))
         (post-pad (propertize post-pad-str 'face `(:background ,bg-color)))

         (tab-str (concat (if active sep empty-sep) pre-pad pin-icon icon mid-pad name ro-icon mod-icon post-pad))

         ;; truncation markers rendered on outer edges of first/last tab
         (is-first (eq buffer (car tabs)))
         (is-last (eq buffer (car (last tabs))))
         (left-gap (when (and is-first (not (and (> (or bufferline-buffers--left-count 0) 0))) bufferline-left-margin)
                     (cond
                      ((and (integerp bufferline-left-margin) (> bufferline-left-margin 0))
                       (propertize " " 'display `(space :width (,bufferline-left-margin)) 'face `(:background ,bar-bg)))
                      ((stringp bufferline-left-margin)
                       (propertize bufferline-left-margin 'face `(:background ,bar-bg)))
                      (t nil))))
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

    (concat left-gap
            left-marker
            (propertize tab-str
                        'tab tab
                        'theme-version bufferline-highlights--theme-version
                        'help-echo nil
                        'mouse-face nil
                        'keymap (let ((km (make-sparse-keymap)))
                                  (define-key km [tab-line mouse-1] #'tab-line-select-tab)
                                  (define-key km [tab-line mouse-2] #'tab-line-close-tab)
                                  (define-key km [tab-line down-mouse-3] #'tab-line-tab-context-menu)
                                  (define-key km [tab-line touchscreen-begin] #'tab-line-select-tab)
                                  (define-key km (kbd "RET") #'tab-line-select-tab)
                                  km))
            right-marker)))

(defun bufferline-ui-follow-active (&rest _)
  "Update window tab cache to recompute visible buffer window."
  (let ((win (selected-window)))
    (when win
      (set-window-parameter win 'tab-line-cache nil)
      (force-mode-line-update t))))

(provide 'bufferline-ui)
;;; bufferline-ui.el ends here
