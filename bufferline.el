;;; bufferline.el --- Snappy, configurable buffer line for GNU Emacs -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Szymon Wilczek
;; Author: Szymon Wilczek <swilczek.lx@gmail.com>
;; Version: 0.1.0
;; Package-Requires: ((emacs "28.1") (nerd-icons "0.1.0"))
;; URL: https://github.com/szymonwilczek/bufferline.el
;; Licensed under GPL-3.0.

;;; Commentary:

;; bufferline.el is a direct, modular port of akinsho/bufferline.nvim to GNU Emacs,
;; built on top of native `tab-line-mode`.

;;; Code:

(require 'tab-line)
(require 'bufferline-constants)
(require 'bufferline-config)
(require 'bufferline-colors)
(require 'bufferline-highlights)
(require 'bufferline-duplicates)
(require 'bufferline-diagnostics)
(require 'bufferline-sorters)
(require 'bufferline-state)
(require 'bufferline-buffers)
(require 'bufferline-numbers)
(require 'bufferline-pick)
(require 'bufferline-commands)
(require 'bufferline-ui)

;;;###autoload
(defalias 'bufferline-apply-theme #'bufferline-highlights-apply)

;;;###autoload
(define-minor-mode global-bufferline-mode
  "Toggle modern bufferline across all Emacs windows."
  :global t
  :group 'bufferline
  (if global-bufferline-mode
      (progn
        (setq tab-line-separator ""
              tab-line-new-button-show nil
              tab-line-close-button-show nil
              tab-line-left-button nil
              tab-line-right-button nil
              tab-line-auto-hscroll t
              tab-line-tabs-scroll-offset 1
              tab-line-tabs-function #'bufferline-buffers-get
              tab-line-tab-name-format-function #'bufferline-ui-tab-name-format)

        (global-tab-line-mode 1)
        (bufferline-highlights-apply)

        (add-hook 'after-make-frame-functions #'bufferline-highlights-apply)
        (add-hook 'buffer-list-update-hook #'bufferline-ui-follow-active)
        (advice-add 'load-theme :after
                    (lambda (&rest _)
                      (run-at-time 0 nil #'bufferline-highlights-apply)))
        (advice-add 'tab-line-switch-to-next-tab :override #'bufferline-next-tab)
        (advice-add 'tab-line-switch-to-prev-tab :override #'bufferline-prev-tab)
        (advice-add 'tab-line-switch-to-next-tab :after #'bufferline-ui-follow-active)
        (advice-add 'tab-line-switch-to-prev-tab :after #'bufferline-ui-follow-active))

    (global-tab-line-mode -1)
    (remove-hook 'after-make-frame-functions #'bufferline-highlights-apply)
    (remove-hook 'buffer-list-update-hook #'bufferline-ui-follow-active)
    (advice-remove 'tab-line-switch-to-next-tab #'bufferline-next-tab)
    (advice-remove 'tab-line-switch-to-prev-tab #'bufferline-prev-tab)))

(provide 'bufferline)
;;; bufferline.el ends here
