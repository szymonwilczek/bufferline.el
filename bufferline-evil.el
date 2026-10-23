;;; bufferline-evil.el --- Vim tab keys and Ex commands for Evil users -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Szymon Wilczek
;; Author: Szymon Wilczek <swilczek.lx@gmail.com>
;; URL: https://github.com/szymonwilczek/bufferline.el
;; Licensed under GPL-3.0.

;;; Commentary:

;; `bufferline-evil-mode' points the Vim tab page keys and Ex commands
;; of Evil at bufferline tabs instead of `tab-bar' tabs: gt and gT, and
;; :tabnext, :tabprevious, :tabfirst, :tablast, :tabclose, :tabonly,
;; :tabmove, :tabnew and :tabedit with their abbreviations.
;; Evil is loaded when the mode is turned on, so bufferline does not
;; depend on it.

;;; Code:

(require 'seq)
(require 'subr-x)
(require 'bufferline-buffers)
(require 'bufferline-commands)

(defvar evil-motion-state-map)
(defvar evil-ex-commands)
(defvar evil-ex-argument)

(declare-function evil-ex-define-cmd "evil-ex" (cmd function))

(defconst bufferline-evil--keys
  '(("gt" . bufferline-evil-tab-next)
    ("gT" . bufferline-evil-tab-previous))
  "Motion state keys `bufferline-evil-mode' binds.")

(defconst bufferline-evil--ex-commands
  '(("tabn[ext]" . bufferline-evil-tab-next)
    ("tabp[revious]" . bufferline-evil-tab-previous)
    ("tabN[ext]" . bufferline-evil-tab-previous)
    ("tabfir[st]" . bufferline-evil-tab-first)
    ("tabr[ewind]" . bufferline-evil-tab-first)
    ("tabl[ast]" . bufferline-evil-tab-last)
    ("tabc[lose]" . bufferline-evil-tab-close)
    ("tabo[nly]" . bufferline-evil-tab-only)
    ("tabm[ove]" . bufferline-evil-tab-move)
    ("tabnew" . bufferline-evil-tab-new)
    ("tabe[dit]" . bufferline-evil-tab-new))
  "Ex commands `bufferline-evil-mode' defines, as `evil-ex-define-cmd' takes them.")

(defvar bufferline-evil--saved nil
  "Bindings `bufferline-evil-mode' replaced, restored when it is turned off.
Each element is (KIND NAME . PREVIOUS), where KIND is `key' or `ex',
NAME the key or Ex command name and PREVIOUS the list of what it was
bound to before, empty when it was unbound.")

(defun bufferline-evil--argument ()
  "Return the argument given to the running Ex command, or nil."
  (let ((arg (and (boundp 'evil-ex-argument) evil-ex-argument)))
    (and (stringp arg)
         (not (string-empty-p (string-trim arg)))
         (string-trim arg))))

(defun bufferline-evil--count (count)
  "Return COUNT, or the number given to the running Ex command, or nil.
COUNT is a raw prefix argument, as with Vim's count before gt or a
range before :tabnext."
  (let ((arg (bufferline-evil--argument)))
    (cond (count (prefix-numeric-value count))
          ((and arg (string-match-p "\\`[0-9]+\\'" arg)) (string-to-number arg)))))

(defun bufferline-evil--tabs ()
  "Return the tabs of the selected window, signaling when there are none."
  (or (bufferline-buffers-all)
      (user-error "No tabs")))

(defun bufferline-evil--go-to (n)
  "Switch to tab N of the selected window, counting from 1."
  (let ((tabs (bufferline-evil--tabs)))
    (unless (<= 1 n (length tabs))
      (user-error "No tab %d" n))
    (switch-to-buffer (nth (1- n) tabs))))

(defun bufferline-evil-tab-next (&optional count)
  "Go to the next tab, or to tab COUNT when given, as Vim's gt does.
From the Ex line, :tabnext N and :Ntabnext also go to tab N."
  (interactive "P")
  (let ((n (bufferline-evil--count count)))
    (if n
        (bufferline-evil--go-to n)
      (bufferline-next-tab))))

(defun bufferline-evil-tab-previous (&optional count)
  "Go COUNT tabs back, cyclically, as Vim's gT does.
From the Ex line, :tabprevious N goes N tabs back."
  (interactive "P")
  (dotimes (_ (max 1 (or (bufferline-evil--count count) 1)))
    (bufferline-prev-tab)))

(defun bufferline-evil-tab-first ()
  "Go to the first tab."
  (interactive)
  (bufferline-evil--go-to 1))

(defun bufferline-evil-tab-last ()
  "Go to the last tab."
  (interactive)
  (bufferline-evil--go-to (length (bufferline-evil--tabs))))

(defun bufferline-evil-tab-close ()
  "Close the current tab."
  (interactive)
  (bufferline-close-tab))

(defun bufferline-evil-tab-only ()
  "Close every tab except the current one.
Pinned tabs stay open while `bufferline-close-keep-pinned' is non-nil."
  (interactive)
  (bufferline-close-other-tabs))

(defun bufferline-evil--move-index (arg pos tabs)
  "Return where :tabmove ARG puts the tab at POS among TABS.
The result is an index into TABS without the moved tab.  ARG is nil to
move the tab last, \"0\" first, \"N\" after the Nth tab, \"+N\" or
\"-N\" N places right or left, and \"$\" last."
  (let ((last (1- (length tabs))))
    (cond ((or (null arg) (equal arg "$")) last)
          ((string-match "\\`\\([-+]\\)\\([0-9]*\\)\\'" arg)
           (let ((n (if (string-empty-p (match-string 2 arg))
                        1
                      (string-to-number (match-string 2 arg)))))
             (max 0 (min last (if (equal (match-string 1 arg) "+") (+ pos n) (- pos n))))))
          ((string-match-p "\\`[0-9]+\\'" arg)
           (let ((n (min (string-to-number arg) (length tabs))))
             (max 0 (if (< pos n) (1- n) n))))
          (t (user-error "Invalid argument: %s" arg)))))

(defun bufferline-evil-tab-move (&optional arg)
  "Move the current tab as Vim's :tabmove ARG does.
Without ARG the tab moves last, with 0 first, with N after the Nth tab
and with +N or -N by N places.  The rules of
`bufferline-commands--move-tab-to' apply."
  (interactive (list (bufferline-evil--argument)))
  (let* ((buf (current-buffer))
         (tabs (bufferline-evil--tabs))
         (pos (or (seq-position tabs buf)
                  (user-error "Current buffer is not a tab")))
         (target (nth (bufferline-evil--move-index arg pos tabs) tabs)))
    (unless (eq target buf)
      (bufferline-commands--move-tab-to buf target))))

(defun bufferline-evil-tab-new (&optional file)
  "Open FILE as a new tab, or an empty buffer when FILE is nil.
The empty buffer comes from `bufferline-new-tab'."
  (interactive (list (bufferline-evil--argument)))
  (if file
      (find-file file)
    (bufferline-new-tab)))

(defun bufferline-evil--ex-names (spec)
  "Return the Ex command names `evil-ex-define-cmd' makes of SPEC."
  (if (string-match "\\`\\(.*\\)\\[\\(.*\\)\\]\\'" spec)
      (let ((mandatory (match-string 1 spec))
            (optional (match-string 2 spec)))
        (mapcar (lambda (n) (concat mandatory (substring optional 0 n)))
                (number-sequence 0 (length optional))))
    (list spec)))

(defun bufferline-evil--enable ()
  "Bind the Evil tab keys and Ex commands to bufferline tabs."
  ;; turning the mode on again must not save its own bindings
  (bufferline-evil--disable)
  (pcase-dolist (`(,key . ,command) bufferline-evil--keys)
    (let ((previous (lookup-key evil-motion-state-map key)))
      (push (cons 'key (cons key (and previous (not (numberp previous)) (list previous))))
            bufferline-evil--saved))
    (define-key evil-motion-state-map key command))
  (pcase-dolist (`(,spec . ,command) bufferline-evil--ex-commands)
    (dolist (name (bufferline-evil--ex-names spec))
      (let ((previous (assoc name evil-ex-commands)))
        (push (cons 'ex (cons name (and previous (list (cdr previous)))))
              bufferline-evil--saved)))
    (evil-ex-define-cmd spec command)))

(defun bufferline-evil--ours-p (definition)
  "Return non-nil if DEFINITION is one `bufferline-evil-mode' binds."
  (and (symbolp definition)
       (or (rassq definition bufferline-evil--keys)
           (rassq definition bufferline-evil--ex-commands))))

(defun bufferline-evil--disable ()
  "Restore the Evil tab keys and Ex commands `bufferline-evil--enable' took.
A key or command rebound since then is left as it is."
  (pcase-dolist (`(,kind ,name . ,previous) bufferline-evil--saved)
    (pcase kind
      ('key
       (when (bufferline-evil--ours-p (lookup-key evil-motion-state-map name))
         (define-key evil-motion-state-map name (car previous))))
      ('ex
       (when (bufferline-evil--ours-p (cdr (assoc name evil-ex-commands)))
         (if previous
             (setcdr (assoc name evil-ex-commands) (car previous))
           (setq evil-ex-commands (assoc-delete-all name evil-ex-commands)))))))
  (setq bufferline-evil--saved nil))

;;;###autoload
(define-minor-mode bufferline-evil-mode
  "Point Evil's Vim tab page keys and Ex commands at bufferline tabs.
When on, gt goes to the next tab or, with a count, to that tab, gT goes
back by the count, and these Ex commands act on the tabs of the selected
window:

  :tabn[ext] [N]      next tab, or tab N
  :tabp[revious] [N]  N tabs back, also :tabN[ext]
  :tabfir[st]         first tab, also :tabr[ewind]
  :tabl[ast]          last tab
  :tabc[lose]         close the current tab
  :tabo[nly]          close the other tabs
  :tabm[ove] [N]      move the tab: last, first (0), after tab N, +N, -N
  :tabnew [FILE]      new tab, also :tabe[dit]

Turning it off brings back what those keys and commands did before.
Evil is loaded when the mode is turned on."
  :global t
  :group 'bufferline
  (if bufferline-evil-mode
      (if (require 'evil nil t)
          (bufferline-evil--enable)
        (setq bufferline-evil-mode nil)
        (user-error "Evil is not installed"))
    (bufferline-evil--disable)))

(provide 'bufferline-evil)
;;; bufferline-evil.el ends here
