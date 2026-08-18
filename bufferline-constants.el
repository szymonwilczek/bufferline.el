;;; bufferline-constants.el --- Constants and glyph definitions -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Szymon Wilczek
;; Author: Szymon Wilczek <swilczek.lx@gmail.com>
;; Version: 0.1.0
;; Package-Requires: ((emacs "28.1") (nerd-icons "0.1.0"))
;; URL: https://github.com/szymonwilczek/bufferline.el
;; Licensed under GPL-3.0.

;;; Code:

(defconst bufferline-constants-padding " "
  "Default padding string.")

(defconst bufferline-constants-indicator "▎"
  "Default vertical indicator glyph.")

(defconst bufferline-constants-ellipsis "…"
  "Truncation ellipsis glyph.")

(defconst bufferline-constants-folder-icon ""
  "Default folder icon.")

(defconst bufferline-constants-left-trunc-marker ""
  "Default left truncation marker glyph.")

(defconst bufferline-constants-right-trunc-marker ""
  "Default right truncation marker glyph.")

(defconst bufferline-constants-separators
  '((thin         . ("▏" "▕"))
    (thick        . ("▌" "▐"))
    (vertical     . ("┃" " "))
    (slant        . ("" ""))
    (slope        . ("" ""))
    (padded_slant . (" " " "))
    (padded_slope . (" " " "))
    (none         . (" " " ")))
  "Alist mapping separator style keys to left/right glyph pairs.")

(provide 'bufferline-constants)
;;; bufferline-constants.el ends here
