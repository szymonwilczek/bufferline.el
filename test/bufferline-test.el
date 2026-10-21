;;; bufferline-test.el --- ERT tests for bufferline.el -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Szymon Wilczek
;; Author: Szymon Wilczek <swilczek.lx@gmail.com>
;; URL: https://github.com/szymonwilczek/bufferline.el
;; Licensed under GPL-3.0.

;;; Commentary:

;; Run with `make test' from the repository root.

;;; Code:

(require 'ert)
(require 'bufferline)

(defvar bufferline-test--buffers nil
  "Buffers created by the running test, killed when it ends.")

(defun bufferline-test--buffer (name)
  "Return a fresh buffer called NAME, killed when the test ends."
  (let ((buf (generate-new-buffer name)))
    (push buf bufferline-test--buffers)
    buf))

(defun bufferline-test--show (window &rest buffers)
  "Display BUFFERS in WINDOW one after another, opening them as its tabs.
Leave WINDOW selected, showing the last of BUFFERS.  List the tabs after
each switch, as redisplay does, so they get their order in opening order."
  (select-window window)
  (dolist (buf buffers)
    (switch-to-buffer buf nil t)
    (bufferline-buffers-all)))

(defun bufferline-test--tabs (window)
  "Return the tabs bufferline lists for WINDOW."
  (with-selected-window window
    (bufferline-buffers-all)))

(defface bufferline-test-pick '((t :foreground "#ff0000"))
  "Face with a color batch Emacs can resolve, for in-place pick letters.")

(defmacro bufferline-test-with-frame (&rest body)
  "Run BODY in a single-window frame with fresh tab state."
  (declare (indent 0) (debug t))
  `(let ((bufferline-state--tab-order-counter 0)
         (bufferline-sort-by 'fifo)
         (bufferline-pick-face 'bufferline-test-pick)
         (bufferline-test--buffers nil))
     (save-window-excursion
       (delete-other-windows)
       (switch-to-buffer (get-buffer-create " *bufferline-test-blank*"))
       (set-window-prev-buffers nil nil)
       (set-window-next-buffers nil nil)
       (unwind-protect
           (progn ,@body)
         (mapc #'kill-buffer bufferline-test--buffers)))))

(defvar bufferline-test--prompts nil
  "Prompts passed to `read-key' while `bufferline-test-with-keys' runs.")

(defmacro bufferline-test-with-keys (keys &rest body)
  "Run BODY with `read-key' answering KEYS one after another.
Each prompt it is called with is recorded in `bufferline-test--prompts'.
An element of KEYS that is a function is called instead, with the
prompt, and its value is the key."
  (declare (indent 1) (debug t))
  `(let ((pending ,keys)
         (bufferline-test--prompts nil))
     (cl-letf (((symbol-function 'read-key)
                (lambda (&optional prompt &rest _)
                  (push prompt bufferline-test--prompts)
                  (let ((key (pop pending)))
                    (if (functionp key) (funcall key prompt) key)))))
       ,@body)))

;;; Tab order state

(ert-deftest bufferline-test-state-move-to-end ()
  (bufferline-test-with-frame
   (let ((a (bufferline-test--buffer "a"))
         (b (bufferline-test--buffer "b"))
         (c (bufferline-test--buffer "c")))
     (bufferline-test--show (selected-window) a b c)
     (bufferline-state-move-to-end a)
     (should (equal (bufferline-test--tabs (selected-window)) (list b c a))))))

(ert-deftest bufferline-test-state-move-to-end-keeps-pinned-first ()
  (bufferline-test-with-frame
   (let ((a (bufferline-test--buffer "a"))
         (b (bufferline-test--buffer "b")))
     (bufferline-test--show (selected-window) a b)
     (bufferline-state-toggle-pin b)
     (bufferline-state-move-to-end a)
     (should (equal (bufferline-test--tabs (selected-window)) (list b a))))))

;;; Window tab lists

(ert-deftest bufferline-test-tabs-isolated-per-window ()
  (bufferline-test-with-frame
   (let* ((left (selected-window))
          (right (split-window-right))
          (a (bufferline-test--buffer "a"))
          (b (bufferline-test--buffer "b"))
          (c (bufferline-test--buffer "c")))
     (bufferline-test--show left a b)
     (bufferline-test--show right c a)
     (should (equal (bufferline-test--tabs left) (list b)))
     (should (equal (bufferline-test--tabs right) (list a c))))))

(ert-deftest bufferline-test-forget-drops-tab-from-window ()
  (bufferline-test-with-frame
   (let ((a (bufferline-test--buffer "a"))
         (b (bufferline-test--buffer "b")))
     (bufferline-test--show (selected-window) a b)
     (bufferline-buffers-forget a (selected-window))
     (should (equal (bufferline-test--tabs (selected-window)) (list b))))))

;;; Tab filters

(ert-deftest bufferline-test-filter-hides-space-prefixed-buffers ()
  (bufferline-test-with-frame
   (let ((a (bufferline-test--buffer "a"))
         (hidden (bufferline-test--buffer " hidden")))
     (bufferline-test--show (selected-window) hidden a)
     (should-not (bufferline-buffers-candidate-p hidden))
     (should (equal (bufferline-test--tabs (selected-window)) (list a))))))

(ert-deftest bufferline-test-filter-special-buffers ()
  (bufferline-test-with-frame
   (let ((a (bufferline-test--buffer "a"))
         (special (bufferline-test--buffer "*special*")))
     (bufferline-test--show (selected-window) special a)
     (let ((bufferline-show-special-buffers t))
       (should (equal (bufferline-test--tabs (selected-window)) (list special a))))
     (let ((bufferline-show-special-buffers nil))
       (should (equal (bufferline-test--tabs (selected-window)) (list a)))))))

(ert-deftest bufferline-test-filter-excluded-modes ()
  (bufferline-test-with-frame
   (let ((a (bufferline-test--buffer "a"))
         (b (bufferline-test--buffer "b")))
     (with-current-buffer b (special-mode))
     (bufferline-test--show (selected-window) b a)
     (let ((bufferline-exclude-modes '(special-mode)))
       (should-not (bufferline-buffers-candidate-p b))
       (should (equal (bufferline-test--tabs (selected-window)) (list a))))
     (let ((bufferline-exclude-modes nil))
       (should (equal (bufferline-test--tabs (selected-window)) (list b a)))))))

(ert-deftest bufferline-test-custom-filter-rejects-buffers ()
  (bufferline-test-with-frame
   (let ((a (bufferline-test--buffer "a"))
         (b (bufferline-test--buffer "b"))
         (c (bufferline-test--buffer "c")))
     (bufferline-test--show (selected-window) a b c)
     (let ((bufferline-custom-filter
            (lambda (buf) (not (equal (buffer-name buf) "b")))))
       (should-not (bufferline-buffers-candidate-p b))
       (should (equal (bufferline-test--tabs (selected-window)) (list a c)))))))

(ert-deftest bufferline-test-custom-filter-receives-each-buffer ()
  (bufferline-test-with-frame
   (let ((a (bufferline-test--buffer "a"))
         (b (bufferline-test--buffer "b"))
         seen)
     (bufferline-test--show (selected-window) a b)
     (let ((bufferline-custom-filter (lambda (buf) (push buf seen) t)))
       (should (equal (bufferline-test--tabs (selected-window)) (list a b))))
     (should (memq a seen))
     (should (memq b seen))
     (should (seq-every-p #'bufferp seen)))))

(ert-deftest bufferline-test-custom-filter-runs-after-built-in-filters ()
  (bufferline-test-with-frame
   (let ((a (bufferline-test--buffer "a"))
         (hidden (bufferline-test--buffer " hidden"))
         seen)
     (bufferline-test--show (selected-window) hidden a)
     (let ((bufferline-custom-filter (lambda (buf) (push buf seen) t)))
       (bufferline-test--tabs (selected-window)))
     (should-not (memq hidden seen)))))

(ert-deftest bufferline-test-custom-filter-can-hide-current-buffer ()
  (bufferline-test-with-frame
   (let ((a (bufferline-test--buffer "a"))
         (b (bufferline-test--buffer "b")))
     (bufferline-test--show (selected-window) a b)
     (let ((bufferline-custom-filter (lambda (buf) (not (eq buf b)))))
       (should (equal (bufferline-test--tabs (selected-window)) (list a)))))))

(ert-deftest bufferline-test-custom-filter-error-keeps-buffer ()
  (bufferline-test-with-frame
   (let ((a (bufferline-test--buffer "a"))
         (b (bufferline-test--buffer "b")))
     (bufferline-test--show (selected-window) a b)
     (let ((bufferline-custom-filter (lambda (_buf) (error "Broken filter"))))
       (should (equal (bufferline-test--tabs (selected-window)) (list a b)))))))

(ert-deftest bufferline-test-custom-filter-nil-keeps-everything ()
  (bufferline-test-with-frame
   (let ((a (bufferline-test--buffer "a"))
         (b (bufferline-test--buffer "b")))
     (bufferline-test--show (selected-window) a b)
     (let ((bufferline-custom-filter nil))
       (should (equal (bufferline-test--tabs (selected-window)) (list a b)))))))

(ert-deftest bufferline-test-filter-dead-buffer ()
  (let ((buf (generate-new-buffer "dead")))
    (kill-buffer buf)
    (should-not (bufferline-buffers-candidate-p buf))))

;;; Reordering within a window

(ert-deftest bufferline-test-move-tab-right ()
  (bufferline-test-with-frame
   (let ((a (bufferline-test--buffer "a"))
         (b (bufferline-test--buffer "b"))
         (c (bufferline-test--buffer "c")))
     (bufferline-test--show (selected-window) a b c a)
     (bufferline-move-tab-right)
     (should (equal (bufferline-test--tabs (selected-window)) (list b a c))))))

(ert-deftest bufferline-test-move-tab-left-at-edge ()
  (bufferline-test-with-frame
   (let ((a (bufferline-test--buffer "a"))
         (b (bufferline-test--buffer "b")))
     (bufferline-test--show (selected-window) a b a)
     (should-error (bufferline-move-tab-left) :type 'user-error))))

;;; Bulk close

(ert-deftest bufferline-test-close-other-tabs ()
  (bufferline-test-with-frame
   (let ((a (bufferline-test--buffer "a"))
         (b (bufferline-test--buffer "b"))
         (c (bufferline-test--buffer "c")))
     (bufferline-test--show (selected-window) a b c b)
     (should (= (bufferline-close-other-tabs) 2))
     (should-not (buffer-live-p a))
     (should-not (buffer-live-p c))
     (should (eq (window-buffer) b))
     (should (equal (bufferline-test--tabs (selected-window)) (list b))))))

(ert-deftest bufferline-test-close-other-tabs-keeps-pinned ()
  (bufferline-test-with-frame
   (let ((a (bufferline-test--buffer "a"))
         (b (bufferline-test--buffer "b"))
         (c (bufferline-test--buffer "c")))
     (bufferline-test--show (selected-window) a b c)
     (bufferline-state-toggle-pin a)
     (let ((bufferline-close-keep-pinned t))
       (should (= (bufferline-close-other-tabs) 1)))
     (should (buffer-live-p a))
     (should-not (buffer-live-p b))
     (should (equal (bufferline-test--tabs (selected-window)) (list a c))))))

(ert-deftest bufferline-test-close-other-tabs-closes-pinned-when-asked ()
  (bufferline-test-with-frame
   (let ((a (bufferline-test--buffer "a"))
         (b (bufferline-test--buffer "b")))
     (bufferline-test--show (selected-window) a b)
     (bufferline-state-toggle-pin a)
     (let ((bufferline-close-keep-pinned nil))
       (should (= (bufferline-close-other-tabs) 1)))
     (should-not (buffer-live-p a))
     (should (equal (bufferline-test--tabs (selected-window)) (list b))))))

(ert-deftest bufferline-test-close-other-tabs-keeps-current-when-pinned ()
  (bufferline-test-with-frame
   (let ((a (bufferline-test--buffer "a"))
         (b (bufferline-test--buffer "b")))
     (bufferline-test--show (selected-window) a b)
     (bufferline-state-toggle-pin b)
     (let ((bufferline-close-keep-pinned nil))
       (bufferline-close-other-tabs))
     (should (buffer-live-p b))
     (should (eq (window-buffer) b)))))

(ert-deftest bufferline-test-close-other-tabs-spares-other-windows ()
  (bufferline-test-with-frame
   (let* ((left (selected-window))
          (right (split-window-right))
          (a (bufferline-test--buffer "a"))
          (b (bufferline-test--buffer "b"))
          (c (bufferline-test--buffer "c"))
          (d (bufferline-test--buffer "d")))
     (bufferline-test--show right c d)
     (bufferline-test--show left a b)
     (bufferline-close-other-tabs)
     (should-not (buffer-live-p a))
     (should (buffer-live-p c))
     (should (buffer-live-p d))
     (should (equal (bufferline-test--tabs right) (list c d))))))

(ert-deftest bufferline-test-close-other-tabs-with-single-tab ()
  (bufferline-test-with-frame
   (let ((a (bufferline-test--buffer "a")))
     (bufferline-test--show (selected-window) a)
     (should (= (bufferline-close-other-tabs) 0))
     (should (buffer-live-p a)))))

(ert-deftest bufferline-test-close-other-tabs-counts-refused-kills ()
  (bufferline-test-with-frame
   (let* ((a (bufferline-test--buffer "a"))
          (b (bufferline-test--buffer "b"))
          (c (bufferline-test--buffer "c"))
          (kill-buffer-query-functions
           (list (lambda () (not (eq (current-buffer) a))))))
     (bufferline-test--show (selected-window) a b c)
     (should (= (bufferline-close-other-tabs) 1))
     (should (buffer-live-p a))
     (should-not (buffer-live-p b))
     (should (equal (bufferline-test--tabs (selected-window)) (list a c))))))

(ert-deftest bufferline-test-close-other-tabs-from-non-tab-buffer ()
  (bufferline-test-with-frame
   (let ((a (bufferline-test--buffer "a"))
         (b (bufferline-test--buffer "b"))
         (other (bufferline-test--buffer "other"))
         (bufferline-exclude-modes '(special-mode)))
     (with-current-buffer other (special-mode))
     (bufferline-test--show (selected-window) a b other)
     (should (= (bufferline-close-other-tabs) 2))
     (should (buffer-live-p other))
     (should (eq (window-buffer) other)))))

(ert-deftest bufferline-test-close-tabs-to-right ()
  (bufferline-test-with-frame
   (let ((a (bufferline-test--buffer "a"))
         (b (bufferline-test--buffer "b"))
         (c (bufferline-test--buffer "c"))
         (d (bufferline-test--buffer "d")))
     (bufferline-test--show (selected-window) a b c d b)
     (should (= (bufferline-close-tabs-to-right) 2))
     (should (eq (window-buffer) b))
     (should (equal (bufferline-test--tabs (selected-window)) (list a b))))))

(ert-deftest bufferline-test-close-tabs-to-left ()
  (bufferline-test-with-frame
   (let ((a (bufferline-test--buffer "a"))
         (b (bufferline-test--buffer "b"))
         (c (bufferline-test--buffer "c"))
         (d (bufferline-test--buffer "d")))
     (bufferline-test--show (selected-window) a b c d c)
     (should (= (bufferline-close-tabs-to-left) 2))
     (should (eq (window-buffer) c))
     (should (equal (bufferline-test--tabs (selected-window)) (list c d))))))

(ert-deftest bufferline-test-close-tabs-to-left-keeps-pinned ()
  (bufferline-test-with-frame
   (let ((a (bufferline-test--buffer "a"))
         (b (bufferline-test--buffer "b"))
         (c (bufferline-test--buffer "c")))
     (bufferline-test--show (selected-window) a b c)
     (bufferline-state-toggle-pin a)
     (let ((bufferline-close-keep-pinned t))
       (should (= (bufferline-close-tabs-to-left) 1)))
     (should (equal (bufferline-test--tabs (selected-window)) (list a c)))
     (let ((bufferline-close-keep-pinned nil))
       (should (= (bufferline-close-tabs-to-left) 1)))
     (should (equal (bufferline-test--tabs (selected-window)) (list c))))))

(ert-deftest bufferline-test-close-tabs-to-right-follows-sort-order ()
  (bufferline-test-with-frame
   (let ((c (bufferline-test--buffer "c"))
         (a (bufferline-test--buffer "a"))
         (b (bufferline-test--buffer "b"))
         (bufferline-sort-by 'name))
     (bufferline-test--show (selected-window) c a b a)
     (should (= (bufferline-close-tabs-to-right) 2))
     (should-not (buffer-live-p b))
     (should-not (buffer-live-p c)))))

(ert-deftest bufferline-test-close-tabs-at-edges ()
  (bufferline-test-with-frame
   (let ((a (bufferline-test--buffer "a"))
         (b (bufferline-test--buffer "b")))
     (bufferline-test--show (selected-window) a b)
     (should (= (bufferline-close-tabs-to-right) 0))
     (bufferline-test--show (selected-window) a)
     (should (= (bufferline-close-tabs-to-left) 0))
     (should (buffer-live-p a))
     (should (buffer-live-p b)))))

(ert-deftest bufferline-test-close-tabs-beside-non-tab-buffer ()
  (bufferline-test-with-frame
   (let ((a (bufferline-test--buffer "a"))
         (other (bufferline-test--buffer "other"))
         (bufferline-exclude-modes '(special-mode)))
     (with-current-buffer other (special-mode))
     (bufferline-test--show (selected-window) a other)
     (should-error (bufferline-close-tabs-to-right) :type 'user-error)
     (should-error (bufferline-close-tabs-to-left) :type 'user-error)
     (should (buffer-live-p a)))))

;;; Picking tabs by letter

(ert-deftest bufferline-test-pick-assigns-letters-in-order ()
  (bufferline-test-with-frame
   (let ((a (bufferline-test--buffer "a"))
         (b (bufferline-test--buffer "b"))
         (bufferline-pick-alphabet "xyz"))
     (should (equal (bufferline-pick--assign (list a b))
                    (list (cons ?x a) (cons ?y b)))))))

(ert-deftest bufferline-test-pick-assign-stops-at-alphabet-end ()
  (bufferline-test-with-frame
   (let ((a (bufferline-test--buffer "a"))
         (b (bufferline-test--buffer "b"))
         (c (bufferline-test--buffer "c"))
         (bufferline-pick-alphabet "xy"))
     (should (equal (bufferline-pick--assign (list a b c))
                    (list (cons ?x a) (cons ?y b)))))))

(ert-deftest bufferline-test-pick-switches-to-chosen-tab ()
  (bufferline-test-with-frame
   (let ((a (bufferline-test--buffer "a"))
         (b (bufferline-test--buffer "b"))
         (c (bufferline-test--buffer "c"))
         (bufferline-pick-alphabet "asd"))
     (bufferline-test--show (selected-window) a b c)
     (bufferline-test-with-keys '(?s)
                                (bufferline-pick)
                                (should (equal bufferline-test--prompts
                                               '("Pick buffer: [a] a  [s] b  [d] c "))))
     (should (eq (window-buffer) b)))))

(ert-deftest bufferline-test-pick-cancelled-by-unknown-key ()
  (bufferline-test-with-frame
   (let ((a (bufferline-test--buffer "a"))
         (b (bufferline-test--buffer "b"))
         (bufferline-pick-alphabet "as"))
     (bufferline-test--show (selected-window) a b)
     (bufferline-test-with-keys '(?q)
                                (should (equal (bufferline-pick) "Pick cancelled")))
     (should (eq (window-buffer) b)))))

(ert-deftest bufferline-test-pick-without-tabs ()
  (bufferline-test-with-frame
   (bufferline-test-with-keys '(?a)
                              (should (equal (bufferline-pick) "No buffers to pick"))
                              (should-not bufferline-test--prompts))))

(ert-deftest bufferline-test-pick-close-kills-chosen-tab ()
  (bufferline-test-with-frame
   (let ((a (bufferline-test--buffer "a"))
         (b (bufferline-test--buffer "b"))
         (bufferline-pick-alphabet "as"))
     (bufferline-test--show (selected-window) a b)
     (bufferline-test-with-keys '(?a)
                                (should (equal (bufferline-pick-close) "Closed buffer: a"))
                                (should (equal bufferline-test--prompts
                                               '("Close buffer: [a] a  [s] b "))))
     (should-not (buffer-live-p a))
     (should (eq (window-buffer) b)))))

(ert-deftest bufferline-test-pick-close-cancelled ()
  (bufferline-test-with-frame
   (let ((a (bufferline-test--buffer "a"))
         (bufferline-pick-alphabet "a"))
     (bufferline-test--show (selected-window) a)
     (bufferline-test-with-keys '(?z)
                                (should (equal (bufferline-pick-close) "Pick close cancelled")))
     (should (buffer-live-p a)))))

(ert-deftest bufferline-test-pick-read-buffer-ignores-killed-choice ()
  (bufferline-test-with-frame
   (let ((a (bufferline-test--buffer "a"))
         (b (bufferline-test--buffer "b"))
         (bufferline-pick-alphabet "as"))
     (bufferline-test--show (selected-window) a b)
     (bufferline-test-with-keys (list (lambda (_prompt) (kill-buffer a) ?a))
                                (should-not (bufferline-pick-read-buffer "Pick: "))))))

(ert-deftest bufferline-test-swap-tab-by-letter ()
  (bufferline-test-with-frame
   (let ((a (bufferline-test--buffer "a"))
         (b (bufferline-test--buffer "b"))
         (c (bufferline-test--buffer "c"))
         (bufferline-pick-alphabet "asd"))
     (bufferline-test--show (selected-window) a b c a)
     (bufferline-test-with-keys '(?d)
                                (bufferline-swap-tab)
                                (should (equal bufferline-test--prompts
                                               '("Swap a with: [a] a  [s] b  [d] c "))))
     (should (equal (bufferline-test--tabs (selected-window)) (list c b a))))))

;;; Picking tabs in place

(defun bufferline-test--render (window buffer)
  "Return the tab of BUFFER as WINDOW's tab line draws it."
  (with-selected-window window
    (with-current-buffer (window-buffer window)
      (bufferline-ui-tab-name-format buffer (bufferline-buffers-get)))))

(defun bufferline-test--pick-letter (string)
  "Return the in-place pick letter drawn in STRING, or nil.
The letter is the only character drawn in the color of `bufferline-pick-face'."
  (let ((fg (face-foreground bufferline-pick-face nil t))
        found)
    (dotimes (i (length string))
      (let ((face (get-text-property i 'face string)))
        (when (and (consp face)
                   (eq (plist-get face :weight) 'bold)
                   (equal (plist-get face :foreground) fg))
          (setq found (aref string i)))))
    found))

(ert-deftest bufferline-test-pick-in-place-off-by-default ()
  (should-not (default-value 'bufferline-pick-in-place)))

(ert-deftest bufferline-test-pick-in-place-draws-letters-on-tabs ()
  (bufferline-test-with-frame
   (let ((a (bufferline-test--buffer "a"))
         (b (bufferline-test--buffer "b"))
         (bufferline-pick-alphabet "as")
         (bufferline-pick-in-place t)
         letters)
     (bufferline-test--show (selected-window) a b)
     (bufferline-test-with-keys
      (list (lambda (_prompt)
              (setq letters
                    (list (bufferline-test--pick-letter
                           (bufferline-test--render (selected-window) a))
                          (bufferline-test--pick-letter
                           (bufferline-test--render (selected-window) b))))
              ?a))
      (bufferline-pick)
      ;; the letters live on the tabs, so the prompt only names the pick
      (should (equal bufferline-test--prompts '("Pick buffer: "))))
     (should (equal letters '(?a ?s)))
     (should (eq (window-buffer) a)))))

(ert-deftest bufferline-test-pick-in-place-letters-go-away ()
  (bufferline-test-with-frame
   (let ((a (bufferline-test--buffer "a"))
         (b (bufferline-test--buffer "b"))
         (bufferline-pick-alphabet "as")
         (bufferline-pick-in-place t))
     (bufferline-test--show (selected-window) a b)
     (bufferline-test-with-keys '(?s)
                                (bufferline-pick))
     (should-not bufferline-pick--labels)
     (should-not bufferline-pick--window)
     (should-not (bufferline-test--pick-letter
                  (bufferline-test--render (selected-window) a))))))

(ert-deftest bufferline-test-pick-in-place-letters-go-away-on-quit ()
  (bufferline-test-with-frame
   (let ((a (bufferline-test--buffer "a"))
         (b (bufferline-test--buffer "b"))
         (bufferline-pick-in-place t))
     (bufferline-test--show (selected-window) a b)
     (bufferline-test-with-keys (list (lambda (_prompt) (signal 'quit nil)))
                                ;; `should-error' only catches errors, and quit is not one
                                (should (eq (condition-case nil
                                                (progn (bufferline-pick) 'returned)
                                              (quit 'quit))
                                            'quit)))
     (should-not bufferline-pick--labels)
     (should-not (bufferline-pick-label a))
     (should (eq (window-buffer) b)))))

(ert-deftest bufferline-test-pick-in-place-redraws-tab-lines ()
  (bufferline-test-with-frame
   (let ((a (bufferline-test--buffer "a"))
         (b (bufferline-test--buffer "b"))
         (bufferline-pick-alphabet "as")
         (bufferline-pick-in-place t)
         cache-during)
     (bufferline-test--show (selected-window) a b)
     (set-window-parameter nil 'tab-line-cache 'stale)
     (bufferline-test-with-keys
      (list (lambda (_prompt)
              (setq cache-during (window-parameter nil 'tab-line-cache))
              (set-window-parameter nil 'tab-line-cache 'stale)
              ?q))
      (bufferline-pick))
     ;; the cached tab line is dropped when the letters appear
     ;; and again when they go away
     (should-not cache-during)
     (should-not (window-parameter nil 'tab-line-cache)))))

(ert-deftest bufferline-test-pick-in-place-only-in-picking-window ()
  (bufferline-test-with-frame
   (let* ((left (selected-window))
          (right (split-window-right))
          (a (bufferline-test--buffer "a"))
          (b (bufferline-test--buffer "b"))
          (c (bufferline-test--buffer "c"))
          (bufferline-pick-in-place t)
          labels-left labels-right)
     (bufferline-test--show right c)
     (bufferline-test--show left a b)
     ;; a is in no window, so it is a tab of both windows
     (bufferline-test-with-keys
      (list (lambda (_prompt)
              (setq labels-left (with-selected-window left (bufferline-pick-label a))
                    labels-right (with-selected-window right (bufferline-pick-label a)))
              ?q))
      (bufferline-pick))
     (should labels-left)
     (should-not labels-right))))

(ert-deftest bufferline-test-pick-in-place-keeps-other-tabs-unlabelled ()
  (bufferline-test-with-frame
   (let ((a (bufferline-test--buffer "a"))
         (b (bufferline-test--buffer "b"))
         (c (bufferline-test--buffer "c"))
         (bufferline-pick-alphabet "as")
         (bufferline-pick-in-place t)
         label-c)
     (bufferline-test--show (selected-window) a b c)
     ;; the alphabet covers only two tabs, so c gets no letter
     (bufferline-test-with-keys
      (list (lambda (_prompt)
              (setq label-c (bufferline-test--pick-letter
                             (bufferline-test--render (selected-window) c)))
              ?q))
      (bufferline-pick))
     (should-not label-c))))

(ert-deftest bufferline-test-pick-close-in-place ()
  (bufferline-test-with-frame
   (let ((a (bufferline-test--buffer "a"))
         (b (bufferline-test--buffer "b"))
         (bufferline-pick-alphabet "as")
         (bufferline-pick-in-place t))
     (bufferline-test--show (selected-window) a b)
     (bufferline-test-with-keys '(?a)
                                (bufferline-pick-close)
                                (should (equal bufferline-test--prompts '("Close buffer: "))))
     (should-not (buffer-live-p a)))))

(ert-deftest bufferline-test-swap-tab-in-place ()
  (bufferline-test-with-frame
   (let ((a (bufferline-test--buffer "a"))
         (b (bufferline-test--buffer "b"))
         (bufferline-pick-alphabet "as")
         (bufferline-pick-in-place t))
     (bufferline-test--show (selected-window) a b a)
     (bufferline-test-with-keys '(?s)
                                (bufferline-swap-tab)
                                (should (equal bufferline-test--prompts '("Swap a with: "))))
     (should (equal (bufferline-test--tabs (selected-window)) (list b a))))))

(ert-deftest bufferline-test-pick-minibuffer-draws-no-letters ()
  (bufferline-test-with-frame
   (let ((a (bufferline-test--buffer "a"))
         (b (bufferline-test--buffer "b"))
         (bufferline-pick-alphabet "as")
         (bufferline-pick-in-place nil)
         letter)
     (bufferline-test--show (selected-window) a b)
     (bufferline-test-with-keys
      (list (lambda (_prompt)
              (setq letter (bufferline-test--pick-letter
                            (bufferline-test--render (selected-window) a)))
              ?q))
      (bufferline-pick))
     (should-not letter))))

;;; Moving tabs between windows

(ert-deftest bufferline-test-move-to-window-right ()
  (bufferline-test-with-frame
   (let* ((left (selected-window))
          (right (split-window-right))
          (a (bufferline-test--buffer "a"))
          (b (bufferline-test--buffer "b"))
          (c (bufferline-test--buffer "c"))
          (d (bufferline-test--buffer "d")))
     (bufferline-test--show right c d)
     (bufferline-test--show left a b a)
     (bufferline-move-tab-to-window-right)
     ;; focus follows the tab, which joins the end of the target's tabs
     (should (eq (selected-window) right))
     (should (eq (window-buffer right) a))
     (should (equal (bufferline-test--tabs right) (list c d a)))
     ;; the source window falls back to one of its remaining tabs
     (should (eq (window-buffer left) b))
     (should (equal (bufferline-test--tabs left) (list b))))))

(ert-deftest bufferline-test-move-to-window-does-not-come-back ()
  (bufferline-test-with-frame
   (let* ((left (selected-window))
          (right (split-window-right))
          (a (bufferline-test--buffer "a"))
          (b (bufferline-test--buffer "b"))
          (c (bufferline-test--buffer "c")))
     (bufferline-test--show right c)
     (bufferline-test--show left a b a)
     (bufferline-move-tab-to-window-right)
     (bufferline-test--show right c)
     (should (equal (bufferline-test--tabs left) (list b))))))

(ert-deftest bufferline-test-move-to-window-each-direction ()
  (dolist (spec '((bufferline-move-tab-to-window-left left)
                  (bufferline-move-tab-to-window-right right)
                  (bufferline-move-tab-to-window-up above)
                  (bufferline-move-tab-to-window-down below)))
    (bufferline-test-with-frame
     (let* ((source (selected-window))
            (target (split-window nil nil (nth 1 spec)))
            (a (bufferline-test--buffer "a"))
            (b (bufferline-test--buffer "b"))
            (c (bufferline-test--buffer "c")))
       (bufferline-test--show target c)
       (bufferline-test--show source b a)
       (funcall (nth 0 spec))
       (should (eq (selected-window) target))
       (should (equal (bufferline-test--tabs target) (list c a)))
       (should (equal (bufferline-test--tabs source) (list b)))))))

(ert-deftest bufferline-test-move-to-window-keeps-pinned-first ()
  (bufferline-test-with-frame
   (let* ((left (selected-window))
          (right (split-window-right))
          (a (bufferline-test--buffer "a"))
          (b (bufferline-test--buffer "b"))
          (c (bufferline-test--buffer "c")))
     (bufferline-test--show right c)
     (bufferline-state-toggle-pin c)
     (bufferline-test--show left b a)
     (bufferline-state-toggle-pin a)
     (bufferline-move-tab-to-window-right)
     (should (equal (bufferline-test--tabs right) (list c a))))))

(ert-deftest bufferline-test-move-last-tab-closes-split ()
  (bufferline-test-with-frame
   (let* ((left (selected-window))
          (right (split-window-right))
          (a (bufferline-test--buffer "a"))
          (c (bufferline-test--buffer "c")))
     (bufferline-test--show right c)
     (bufferline-test--show left a)
     (bufferline-move-tab-to-window-right)
     
     ;; the emptied split closes, after the tab has landed in the target
     (should-not (window-live-p left))
     (should (eq (selected-window) right))
     (should (eq (window-buffer right) a))
     (should (equal (bufferline-test--tabs right) (list c a))))))

(ert-deftest bufferline-test-move-last-tab-closes-split-in-three ()
  (bufferline-test-with-frame
   (let* ((top (selected-window))
          (middle (split-window-below))
          (bottom (with-selected-window middle (split-window-below)))
          (a (bufferline-test--buffer "a"))
          (b (bufferline-test--buffer "b"))
          (c (bufferline-test--buffer "c")))
     (bufferline-test--show top b)
     (bufferline-test--show bottom c)
     (bufferline-test--show middle a)
     (bufferline-move-tab-to-window-up)
     (should-not (window-live-p middle))
     (should (eq (selected-window) top))
     (should (equal (bufferline-test--tabs top) (list b a)))
     (should (eq (window-buffer bottom) c)))))

(ert-deftest bufferline-test-move-last-tab-from-undeletable-window ()
  (bufferline-test-with-frame
   (let* ((main (selected-window))
          (a (bufferline-test--buffer "a"))
          (c (bufferline-test--buffer "c"))
          (side (display-buffer-in-side-window c '((side . right)))))
     (set-window-dedicated-p side nil)
     (bufferline-test--show main a)
     (should (equal (cadr (should-error (bufferline-move-tab-to-window-right)
                                        :type 'user-error))
                    "Cannot close this window after moving its last tab"))
     (should (window-live-p main))
     (should (eq (window-buffer main) a))
     (should (eq (window-buffer side) c)))))

(ert-deftest bufferline-test-move-to-window-without-neighbour ()
  (bufferline-test-with-frame
   (let* ((left (selected-window))
          (right (split-window-right))
          (a (bufferline-test--buffer "a"))
          (b (bufferline-test--buffer "b")))
     (bufferline-test--show left b a)
     (should-error (bufferline-move-tab-to-window-left) :type 'user-error)
     (should-error (bufferline-move-tab-to-window-up) :type 'user-error)
     (should (eq (selected-window) left))
     (should (eq (window-buffer left) a))
     (should (equal (bufferline-test--tabs left) (list b a))))))

(ert-deftest bufferline-test-move-to-dedicated-window ()
  (bufferline-test-with-frame
   (let* ((left (selected-window))
          (right (split-window-right))
          (a (bufferline-test--buffer "a"))
          (b (bufferline-test--buffer "b"))
          (c (bufferline-test--buffer "c")))
     (bufferline-test--show right c)
     (set-window-dedicated-p right t)
     (bufferline-test--show left b a)
     (should-error (bufferline-move-tab-to-window-right) :type 'user-error)
     (should (eq (window-buffer right) c))
     (should (eq (window-buffer left) a)))))

(provide 'bufferline-test)
;;; bufferline-test.el ends here
