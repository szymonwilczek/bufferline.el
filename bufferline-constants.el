;;; bufferline-constants.el --- Constants and glyph definitions -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Szymon Wilczek
;; Author: Szymon Wilczek <swilczek.lx@gmail.com>
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

(defconst bufferline-constants-pinned-icon " "
  "Default pinned buffer glyph.")

(defconst bufferline-constants-read-only-icon ""
  "Default read-only lock glyph.")

(defconst bufferline-constants-left-trunc-marker ""
  "Default left truncation marker glyph.")

(defconst bufferline-constants-right-trunc-marker ""
  "Default right truncation marker glyph.")

(defconst bufferline-constants-new-tab-icon "󰐕"
  "Default new tab button glyph.")

(defconst bufferline-constants-prev-tab-icon "󰅁"
  "Default glyph of the previous tab navigation button.")

(defconst bufferline-constants-next-tab-icon "󰅂"
  "Default glyph of the next tab navigation button.")

(defconst bufferline-constants-separators
  '((vertical     . ("▎" " "))
    (bar          . ("│" " "))
    (thick_bar    . ("┃" " "))
    (thin         . ("▏" " "))
    (thick        . ("▌" " "))
    (slant        . ("" ""))
    (slope        . ("" ""))
    (padded_slant . (" " " "))
    (padded_slope . (" " " "))
    (none         . (" " " ")))
  "Alist mapping separator style keys to left/right glyph pairs.")

(provide 'bufferline-constants)
;;; bufferline-constants.el ends here
