;;; bufferline-ui.el --- Rendering engine and viewport scroll management -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Szymon Wilczek
;; Author: Szymon Wilczek <swilczek.lx@gmail.com>
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
(require 'bufferline-pick)

(defun bufferline-ui-tab-name-format (tab tabs)
  "Format single TAB buffer with icons, indicators, disambiguation, and edge truncation markers."
  (let* ((buffer (if (bufferp tab) tab (cdr (assq 'buffer tab))))
         (active (if (bufferp tab) (eq tab (current-buffer)) (cdr (assq 'selected tab))))
         (bg-face (if active 'tab-line-tab-current 'tab-line-tab-inactive))
         (def-bg (face-background 'default nil t))
         (def-fg (face-foreground 'default nil t))
         (bg-color (bufferline-colors-safe (face-background bg-face nil t) def-bg))
         (bar-bg (bufferline-colors-safe (face-background 'tab-line nil t) bg-color))
         (fg-main (bufferline-colors-safe (face-foreground (if active 'tab-line-tab-current 'default) nil t) def-fg))
         (fg-comment (bufferline-colors-safe
                      (when (fboundp 'ef-themes-get-color-value)
                        (ignore-errors (ef-themes-get-color-value 'fg-dim)))
                      (bufferline-colors-safe (face-foreground 'font-lock-comment-face nil t)
                                              (bufferline-colors-safe (face-foreground 'shadow nil t) def-fg))))
         (keyword-color (bufferline-colors-safe (face-foreground 'font-lock-keyword-face nil t)
                                                (bufferline-colors-safe (face-foreground 'font-lock-builtin-face nil t) fg-main)))
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
         (graphic (display-graphic-p))
         (sep-pair (or (cdr (assq bufferline-separator-style bufferline-constants-separators)) '("▎" " ")))
         (sep-pixel-width (when graphic
                            (or bufferline-indicator-width
                                (cond ((eq bufferline-separator-style 'thin) 2)
                                      ((eq bufferline-separator-style 'thick) 5)
                                      ((eq bufferline-separator-style 'vertical) 3)
                                      (t nil)))))
         (sep (if sep-pixel-width
                  (propertize " " 'display `(space :width (,sep-pixel-width)) 'face `(:background ,indicator-color))
                (propertize (car sep-pair) 'face `(:foreground ,indicator-color :background ,bg-color :weight normal))))
         (empty-sep (if graphic
                        (if sep-pixel-width
                            (propertize " " 'display `(space :width (,sep-pixel-width)) 'face `(:background ,bg-color))
                          (propertize (cadr sep-pair) 'face `(:background ,bg-color)))
                      (if (memq bufferline-separator-style '(slant slope padded_slant padded_slope))
                          (propertize (cadr sep-pair) 'face `(:background ,bg-color))
                        "")))

         ;; file icon
         (file-or-name (or (buffer-file-name buffer) (buffer-name buffer)))
         (icon-raw (when (and bufferline-show-buffer-icons (fboundp 'nerd-icons-icon-for-file))
                     (let ((nerd-icons-color-icons t))
                       (nerd-icons-icon-for-file file-or-name :v-adjust -0.05 :height bufferline-icon-size))))
         (icon-hex (if icon-raw (bufferline-colors-get-icon-hex icon-raw (if active fg-main fg-comment)) fg-comment))
         (icon-str (if icon-raw (substring-no-properties icon-raw) " "))
         (pick-char (bufferline-pick-label buffer))
         (icon (if pick-char
                   (let ((pick-fg (bufferline-colors-safe (face-foreground bufferline-pick-face nil t)
                                                          keyword-color)))
                     (propertize (string pick-char) 'face `(:foreground ,pick-fg :weight bold :background ,bg-color)))
                 (propertize icon-str 'face `(:foreground ,icon-hex :background ,bg-color))))

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
                      (let ((ro-fg (bufferline-colors-safe (face-foreground 'font-lock-doc-face nil t) fg-comment)))
                        (propertize (format " %s" bufferline-read-only-icon) 'face `(:foreground ,ro-fg :background ,bg-color)))
                    ""))

         ;; modified indicator
         (mod-icon (if (and bufferline-show-modified (buffer-modified-p buffer))
                       (let ((mod-fg (bufferline-colors-safe (face-foreground 'font-lock-warning-face nil t)
                                                             (bufferline-colors-safe (face-foreground 'warning nil t) keyword-color))))
                         (propertize (format " %s" bufferline-modified-icon) 'face `(:foreground ,mod-fg :background ,bg-color :weight bold)))
                     ""))

         ;; pin indicator
         (pin-icon (if (and bufferline-show-pinned (buffer-local-value 'bufferline-state--pinned buffer))
                       (let ((pin-fg (bufferline-colors-safe (face-foreground 'font-lock-keyword-face nil t) keyword-color)))
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

         ;; close button, set apart from the indicators by one space
         (close-icon (if (bufferline-buffers-close-icon-p buffer)
                         (concat (propertize " " 'face `(:background ,bg-color))
                                 (propertize bufferline-close-icon 'face `(:foreground ,fg-comment :background ,bg-color)))
                       ""))

         (tab-head (concat (if active sep empty-sep) pre-pad pin-icon icon mid-pad name ro-icon mod-icon))
         (tab-str (concat tab-head close-icon post-pad))
         (tab-map (let ((km (make-sparse-keymap)))
                    (define-key km [tab-line mouse-1] #'tab-line-select-tab)
                    (define-key km [tab-line mouse-2] #'tab-line-close-tab)
                    (define-key km [tab-line down-mouse-3] #'tab-line-tab-context-menu)
                    (define-key km [tab-line touchscreen-begin] #'tab-line-select-tab)
                    (define-key km (kbd "RET") #'tab-line-select-tab)
                    km))

         ;; truncation markers rendered on outer edges of first/last tab
         (is-first (eq buffer (car tabs)))
         (is-last (eq buffer (car (last tabs))))
         (left-gap (when (and is-first (not (and (> (or bufferline-buffers--left-count 0) 0))) bufferline-left-margin)
                     (cond
                      ((and (integerp bufferline-left-margin) (> bufferline-left-margin 0))
                       (if graphic
                           (propertize " " 'display `(space :width (,bufferline-left-margin)) 'face `(:background ,bar-bg))
                         ""))
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

    (setq tab-str (propertize tab-str
                              'tab tab
                              'theme-version bufferline-highlights--theme-version
                              'help-echo nil
                              'mouse-face nil
                              'keymap tab-map))
    ;; the close button keeps the tab properties but answers mouse-1 itself
    (unless (equal close-icon "")
      (let ((start (1+ (length tab-head)))
            (close-map (make-sparse-keymap))
            (hover-fg (bufferline-colors-safe (face-foreground bufferline-close-icon-hover-face nil t)
                                              keyword-color)))
        (set-keymap-parent close-map tab-map)
        (define-key close-map [tab-line mouse-1] #'bufferline-close-tab-at-click)
        (add-text-properties start (+ start (length bufferline-close-icon))
                             (list 'keymap close-map
                                   'help-echo "Close tab"
                                   'mouse-face `(:foreground ,hover-fg :background ,bg-color :weight bold))
                             tab-str)))

    (concat left-gap
            left-marker
            tab-str
            right-marker)))

(defun bufferline-ui-follow-active (&rest _)
  "Update window tab cache to recompute visible buffer window."
  (let ((win (selected-window)))
    (when win
      (set-window-parameter win 'tab-line-cache nil)
      (force-mode-line-update t))))

(defun bufferline-ui--excluded-p (buffer)
  "Return non-nil if `bufferline-hide-in-excluded-buffers' covers BUFFER."
  (let ((modes bufferline-hide-in-excluded-buffers))
    (cond ((null modes) nil)
          ((listp modes)
           (let ((mode (buffer-local-value 'major-mode buffer)))
             (seq-some (lambda (m) (provided-mode-derived-p mode m)) modes)))
          (t (not (bufferline-buffers-candidate-p buffer))))))

(defun bufferline-ui--hide-tab-line-p (window)
  "Return non-nil if the hiding options call for hiding WINDOW's tab line."
  (and (or (bufferline-ui--excluded-p (window-buffer window))
           (and bufferline-hide-single-tab
                (<= (length (with-selected-window window
                              (bufferline-buffers-all)))
                    1)))
       t))

(defun bufferline-ui-update-visibility (&rest _)
  "Hide or show the tab line of every window as the hiding options say.
A tab line is hidden through the `tab-line-format' window parameter, and
only one hidden here is shown again, so a window whose tab line was set
up by something else is left alone.  See `bufferline-hide-single-tab'
and `bufferline-hide-in-excluded-buffers'."
  (walk-windows
   (lambda (win)
     (let* ((format (window-parameter win 'tab-line-format))
            (ours (and (window-parameter win 'bufferline-hidden)
                       (eq format 'none))))
       (if (not (or ours (null format)))
           (set-window-parameter win 'bufferline-hidden nil)
         (let ((hide (bufferline-ui--hide-tab-line-p win)))
           (unless (eq hide ours)
             (set-window-parameter win 'tab-line-format (and hide 'none))
             (set-window-parameter win 'bufferline-hidden hide))))))
   nil t))

(defun bufferline-ui-restore-visibility ()
  "Show again every tab line `bufferline-ui-update-visibility' hid."
  (walk-windows
   (lambda (win)
     (when (window-parameter win 'bufferline-hidden)
       (when (eq (window-parameter win 'tab-line-format) 'none)
         (set-window-parameter win 'tab-line-format nil))
       (set-window-parameter win 'bufferline-hidden nil)))
   nil t))

(defun bufferline-ui-refresh ()
  "Invalidate tab-line cache across windows and force immediate redisplay."
  (walk-windows
   (lambda (win)
     (set-window-parameter win 'tab-line-cache nil)
     (force-window-update win))
   nil t)
  (force-mode-line-update t))

(provide 'bufferline-ui)
;;; bufferline-ui.el ends here
