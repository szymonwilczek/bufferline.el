;;; bufferline-colors.el --- Color manipulation and hex utilities -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Szymon Wilczek
;; Author: Szymon Wilczek <swilczek.lx@gmail.com>
;; Version: 0.1.0
;; Package-Requires: ((emacs "28.1") (nerd-icons "0.1.0"))
;; URL: https://github.com/szymonwilczek/bufferline.el
;; Licensed under GPL-3.0.

;;; Code:

(require 'color)

(defun bufferline-colors-safe (color fallback)
  "Return COLOR if it represents a valid non-empty string, otherwise return FALLBACK."
  (if (or (null color)
          (eq color 'unspecified)
          (equal color "unspecified")
          (equal color "unspecified-bg")
          (equal color "unspecified-fg"))
      fallback
    color))

(defun bufferline-colors-darken (hex percent)
  "Safely darken HEX by PERCENT."
  (or (ignore-errors (color-darken-name (bufferline-colors-safe hex "#111111") percent))
      hex))

(defun bufferline-colors-lighten (hex percent)
  "Safely lighten HEX by PERCENT."
  (or (ignore-errors (color-lighten-name (bufferline-colors-safe hex "#111111") percent))
      hex))

(defun bufferline-colors-get-icon-hex (icon-str fallback)
  "Extract the foreground hex color from an icon string produced by nerd-icons."
  (let* ((face (or (get-text-property 0 'face icon-str)
                   (get-text-property 0 'font-lock-face icon-str)))
         (hex (cond
               ((symbolp face) (face-foreground face nil t))
               ((listp face)
                (let ((fg (plist-get face :foreground))
                      (inh (plist-get face :inherit)))
                  (cond
                   (fg (cond ((stringp fg) fg)
                             ((symbolp fg) (face-foreground fg nil t))
                             (t nil)))
                   (inh (let ((inh-face (if (listp inh) (car inh) inh)))
                          (if (symbolp inh-face)
                              (face-foreground inh-face nil t)
                            nil)))
                   (t nil))))
               (t nil))))
    (bufferline-colors-safe hex fallback)))

(provide 'bufferline-colors)
;;; bufferline-colors.el ends here
