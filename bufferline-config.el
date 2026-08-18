;;; bufferline-config.el --- User configuration and defcustom definitions -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Szymon Wilczek
;; Author: Szymon Wilczek <swilczek.lx@gmail.com>
;; Version: 0.1.0
;; Package-Requires: ((emacs "28.1") (nerd-icons "0.1.0"))
;; URL: https://github.com/szymonwilczek/bufferline.el
;; Licensed under GPL-3.0.

;;; Code:

(require 'bufferline-constants)

(defgroup bufferline nil
  "Modern, modular tab-line buffer tabs for Emacs (port of bufferline.nvim)."
  :group 'convenience
  :prefix "bufferline-")

(defcustom bufferline-separator-style 'vertical
  "Separator style between buffer tabs.
Allowed values: 'vertical ('┃'), 'thin ('▏'), 'thick ('▌'), 'slant, 'slope, 'padded_slant, 'none."
  :type '(choice (const :tag "Vertical Bar (┃)" vertical)
                 (const :tag "Thin (▏)" thin)
                 (const :tag "Thick (▌)" thick)
                 (const :tag "Slant ()" slant)
                 (const :tag "Slope ()" slope)
                 (const :tag "Padded Slant" padded_slant)
                 (const :tag "None" none))
  :group 'bufferline)

(defcustom bufferline-indicator "┃"
  "Indicator string prepended to the active buffer tab."
  :type 'string
  :group 'bufferline)

(defcustom bufferline-max-name-length 18
  "Maximum character length of buffer names before truncation with ellipsis."
  :type 'integer
  :group 'bufferline)

(defcustom bufferline-show-buffer-icons t
  "Whether to show filetype icons via nerd-icons."
  :type 'boolean
  :group 'bufferline)

(defcustom bufferline-icon-size 0.85
  "Height scaling factor for nerd-icons in buffer tabs."
  :type 'float
  :group 'bufferline)

(defcustom bufferline-show-duplicate-prefix t
  "Disambiguate buffers with identical basenames by prepending parent dir."
  :type 'boolean
  :group 'bufferline)

(defcustom bufferline-modified-icon "●"
  "Icon displayed when buffer has unsaved modifications."
  :type 'string
  :group 'bufferline)

(defcustom bufferline-show-modified t
  "Whether to display the modified indicator icon."
  :type 'boolean
  :group 'bufferline)

(defcustom bufferline-read-only-icon bufferline-constants-read-only-icon
  "Icon displayed when buffer is read-only."
  :type 'string
  :group 'bufferline)

(defcustom bufferline-show-read-only t
  "Whether to display the read-only lock icon."
  :type 'boolean
  :group 'bufferline)

(defcustom bufferline-show-diagnostics nil
  "Whether to display Flymake/LSP error count badges in tabs."
  :type 'boolean
  :group 'bufferline)

(defcustom bufferline-left-trunc-marker bufferline-constants-left-trunc-marker
  "Glyph displayed on the left when buffers are truncated."
  :type 'string
  :group 'bufferline)

(defcustom bufferline-right-trunc-marker bufferline-constants-right-trunc-marker
  "Glyph displayed on the right when buffers are truncated."
  :type 'string
  :group 'bufferline)

(defcustom bufferline-show-trunc-markers t
  "Whether to show truncation count and arrows on left/right edges."
  :type 'boolean
  :group 'bufferline)

(defcustom bufferline-exclude-modes
  '(treemacs-mode
    which-key-mode
    dashboard-mode
    help-mode
    messages-buffer-mode
    ghostel-mode)
  "List of major modes excluded from the bufferline."
  :type '(repeat symbol)
  :group 'bufferline)

(defcustom bufferline-tab-fixed-width 23
  "Average tab width estimation used for viewport scrolling."
  :type 'integer
  :group 'bufferline)

(defcustom bufferline-pick-alphabet "asdfghjklqwertyuiopzxcvbnm"
  "Alphabet string used for bufferline-pick quick jumping keys."
  :type 'string
  :group 'bufferline)

(provide 'bufferline-config)
;;; bufferline-config.el ends here
