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
Allowed values: 'vertical ('▎'), 'bar ('│'), 'thick_bar ('┃'), 'thin ('▏'), 'thick ('▌'), 'slant, 'slope, 'padded_slant, 'none."
  :type '(choice (const :tag "Vertical Block (▎)" vertical)
                 (const :tag "Thin Box Line (│)" bar)
                 (const :tag "Thick Box Line (┃)" thick_bar)
                 (const :tag "Thin Block (▏)" thin)
                 (const :tag "Thick Block (▌)" thick)
                 (const :tag "Slant ()" slant)
                 (const :tag "Slope ()" slope)
                 (const :tag "Padded Slant" padded_slant)
                 (const :tag "None" none))
  :group 'bufferline)

(defcustom bufferline-indicator bufferline-constants-indicator
  "Indicator string prepended to the active buffer tab."
  :type 'string
  :group 'bufferline)

(defcustom bufferline-indicator-face 'default
  "Face used to resolve the active indicator foreground color (matching TabLineSel)."
  :type 'face
  :group 'bufferline)

(defcustom bufferline-indicator-width nil
  "Explicit pixel width for the active tab indicator bar.
When nil, width is derived from `bufferline-separator-style`
(2px for 'thin, 3px for 'vertical, 5px for 'thick)."
  :type '(choice (const :tag "Auto from style" nil)
                 (integer :tag "Pixels"))
  :group 'bufferline)

(defcustom bufferline-left-margin 8
  "Margin before the first tab on the left edge.
Can be an integer (width in pixels, e.g. 8), a string (e.g. \" \"), or nil for no margin."
  :type '(choice (integer :tag "Pixels" 8)
                 (string :tag "String" " ")
                 (const :tag "None" nil))
  :group 'bufferline)

(defcustom bufferline-top-padding 0
  "Top/bottom padding in pixels for the entire buffer line bar."
  :type 'integer
  :group 'bufferline)

(defcustom bufferline-tab-padding-vertical 4
  "Vertical padding in pixels for individual buffer tabs."
  :type 'integer
  :group 'bufferline)

(defcustom bufferline-tab-padding-horizontal 2
  "Horizontal padding (number of spaces or custom string) at the end of each tab."
  :type '(choice (integer :tag "Spaces" 2)
                 (string :tag "String" "  "))
  :group 'bufferline)

(defcustom bufferline-icon-spacing 1
  "Spacing (number of spaces or custom string) between file icon and buffer name."
  :type '(choice (integer :tag "Spaces" 1)
                 (string :tag "String" " "))
  :group 'bufferline)

(defcustom bufferline-sort-by 'fifo
  "Strategy used to sort tabs on the buffer line.
Allowed values: 'fifo (visit order), 'name (alphabetical), 'extension, 'directory."
  :type '(choice (const :tag "FIFO (Visit Order)" fifo)
                 (const :tag "Alphabetical (Name)" name)
                 (const :tag "File Extension" extension)
                 (const :tag "Directory Path" directory))
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

(defcustom bufferline-pinned-icon bufferline-constants-pinned-icon
  "Icon displayed on pinned buffer tabs."
  :type 'string
  :group 'bufferline)

(defcustom bufferline-show-pinned t
  "Whether to display the pinned icon on pinned tabs."
  :type 'boolean
  :group 'bufferline)

(defcustom bufferline-show-diagnostics nil
  "Whether to display Flymake/LSP error count badges in tabs."
  :type 'boolean
  :group 'bufferline)

(defcustom bufferline-diagnostics-error-icon ""
  "Icon displayed for Flymake/LSP error diagnostics."
  :type 'string
  :group 'bufferline)

(defcustom bufferline-diagnostics-warning-icon ""
  "Icon displayed for Flymake/LSP warning diagnostics."
  :type 'string
  :group 'bufferline)

(defcustom bufferline-diagnostics-info-icon ""
  "Icon displayed for Flymake/LSP note/info diagnostics."
  :type 'string
  :group 'bufferline)

(defcustom bufferline-diagnostics-indicator nil
  "Custom function to format diagnostics badge: (count level diags-alist buffer).
When nil, standard icon and count badge is rendered."
  :type '(choice (const :tag "Default Icon Badge" nil)
                 (function :tag "Custom Function"))
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
