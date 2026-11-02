;;; bufferline-test.el --- ERT tests for bufferline.el -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Szymon Wilczek
;; Author: Szymon Wilczek <swilczek.lx@gmail.com>
;; URL: https://github.com/szymonwilczek/bufferline.el
;; Licensed under GPL-3.0.

;;; Commentary:

;; Run with `make test' from the repository root.

;;; Code:

(require 'ert)
(require 'flymake)
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
         (bufferline-hide-single-tab nil)
         (bufferline-hide-in-excluded-buffers nil)
         (bufferline-pick-face 'bufferline-test-pick)
         (bufferline-test--buffers nil))
     (save-window-excursion
       (delete-other-windows)
       (switch-to-buffer (get-buffer-create " *bufferline-test-blank*"))
       (set-window-prev-buffers nil nil)
       (set-window-next-buffers nil nil)
       (set-window-parameter nil 'tab-line-format nil)
       (set-window-parameter nil 'bufferline-hidden nil)
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
         (bufferline-pick-alphabet "asd")
         (bufferline-pick-in-place nil))
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
         (bufferline-pick-alphabet "as")
         (bufferline-pick-in-place nil))
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
         (bufferline-pick-alphabet "asd")
         (bufferline-pick-in-place nil))
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

(ert-deftest bufferline-test-pick-in-place-on-by-default ()
  (should (eq (default-value 'bufferline-pick-in-place) t)))

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

;;; Picking windows by letter

(ert-deftest bufferline-test-pick-windows-in-frame-order ()
  (bufferline-test-with-frame
   (let* ((top-left (selected-window))
          (bottom (split-window-below))
          (top-right (split-window-right)))
     ;; the selected window is left out, wherever it is
     (select-window bottom)
     (should (equal (bufferline-pick--windows) (list top-left top-right)))
     (select-window top-right)
     (should (equal (bufferline-pick--windows) (list top-left bottom))))))

(ert-deftest bufferline-test-pick-windows-skip-dedicated ()
  (bufferline-test-with-frame
   (let* ((left (selected-window))
          (middle (split-window-right))
          (right (split-window middle nil 'right)))
     (set-window-dedicated-p middle t)
     (should (equal (bufferline-pick--windows) (list right))))))

(ert-deftest bufferline-test-pick-read-window-in-minibuffer ()
  (bufferline-test-with-frame
   (let* ((left (selected-window))
          (right (split-window-right))
          (below (split-window right nil 'below))
          (a (bufferline-test--buffer "a"))
          (b (bufferline-test--buffer "b"))
          (c (bufferline-test--buffer "c"))
          (bufferline-pick-alphabet "as")
          (bufferline-pick-in-place nil))
     (bufferline-test--show right b)
     (bufferline-test--show below c)
     (bufferline-test--show left a)
     (bufferline-test-with-keys '(?s)
                                (should (eq (bufferline-pick-read-window "To window: ") below))
                                ;; each letter names the buffer its window shows
                                (should (equal bufferline-test--prompts '("To window: [a] b  [s] c ")))))))

(ert-deftest bufferline-test-pick-read-window-cancelled ()
  (bufferline-test-with-frame
   (let ((right (split-window-right))
         (bufferline-pick-alphabet "a"))
     (ignore right)
     (bufferline-test-with-keys '(?q)
                                (should-not (bufferline-pick-read-window "To window: "))))))

(ert-deftest bufferline-test-pick-read-window-without-windows ()
  (bufferline-test-with-frame
   (bufferline-test-with-keys '(?a)
                              (should-not (bufferline-pick-read-window "To window: "))
                              (should-not bufferline-test--prompts))))

(ert-deftest bufferline-test-pick-read-window-ignores-deleted-choice ()
  (bufferline-test-with-frame
   (let ((right (split-window-right))
         (bufferline-pick-alphabet "a"))
     (bufferline-test-with-keys (list (lambda (_prompt) (delete-window right) ?a))
                                (should-not (bufferline-pick-read-window "To window: "))))))

(ert-deftest bufferline-test-pick-read-window-from-given-windows ()
  (bufferline-test-with-frame
   (let* ((left (selected-window))
          (middle (split-window-right))
          (right (split-window middle nil 'right))
          (bufferline-pick-alphabet "as"))
     (ignore middle)
     (bufferline-test-with-keys '(?s)
                                (should (eq (bufferline-pick-read-window "To window: " (list right left))
                                            left))))))

(ert-deftest bufferline-test-pick-window-in-place-labels ()
  (bufferline-test-with-frame
   (let* ((left (selected-window))
          (right (split-window-right))
          (below (split-window right nil 'below))
          (bufferline-pick-alphabet "as")
          (bufferline-pick-in-place t)
          labels)
     (bufferline-test-with-keys
      (list (lambda (_prompt)
              (setq labels (mapcar #'bufferline-pick-window-label
                                   (list left right below)))
              ?a))
      (should (eq (bufferline-pick-read-window "To window: ") right))
      ;; the letters live on the windows, so the prompt only names the pick
      (should (equal bufferline-test--prompts '("To window: "))))
     (should (equal labels '(nil ?a ?s)))
     (should-not bufferline-pick--window-labels)
     (should-not (bufferline-pick-window-label right)))))

(ert-deftest bufferline-test-pick-window-in-place-labels-go-away-on-quit ()
  (bufferline-test-with-frame
   (let ((right (split-window-right))
         (bufferline-pick-in-place t))
     (bufferline-test-with-keys (list (lambda (_prompt) (signal 'quit nil)))
                                (should (eq (condition-case nil
                                                (progn (bufferline-pick-read-window "To window: ") 'returned)
                                              (quit 'quit))
                                            'quit)))
     (should-not (bufferline-pick-window-label right)))))

(defun bufferline-test--window-badge (string)
  "Return the window pick letter drawn as a badge in STRING, or nil.
The badge is the only text drawn on the color of `bufferline-pick-face'."
  (let ((bg (face-foreground bufferline-pick-face nil t))
        found)
    (dotimes (i (length string))
      (let ((face (get-text-property i 'face string)))
        (when (and (not found)
                   (consp face)
                   (equal (plist-get face :background) bg)
                   (not (eq (aref string i) ?\s)))
          (setq found (aref string i)))))
    found))

(ert-deftest bufferline-test-pick-window-badge-on-first-tab ()
  (bufferline-test-with-frame
   (let* ((left (selected-window))
          (right (split-window-right))
          (a (bufferline-test--buffer "a"))
          (b (bufferline-test--buffer "b"))
          (c (bufferline-test--buffer "c"))
          (bufferline-pick-alphabet "s")
          (bufferline-pick-in-place t)
          badges)
     (bufferline-test--show right b c)
     (bufferline-test--show left a)
     (bufferline-test-with-keys
      (list (lambda (_prompt)
              (setq badges
                    (list (bufferline-test--window-badge (bufferline-test--render right b))
                          (bufferline-test--window-badge (bufferline-test--render right c))
                          (bufferline-test--window-badge (bufferline-test--render left a))))
              ?q))
      (bufferline-pick-read-window "To window: "))
     ;; only the first tab of the labelled window carries the letter
     (should (equal badges '(?s nil nil)))
     ;; and it goes away with the pick
     (should-not (bufferline-test--window-badge (bufferline-test--render right b))))))

(ert-deftest bufferline-test-pick-window-badge-leads-the-tab-line ()
  (bufferline-test-with-frame
   (let* ((right (split-window-right))
          (b (bufferline-test--buffer "b"))
          (bufferline-pick-alphabet "s")
          (bufferline-left-margin "<margin>")
          string)
     (bufferline-test--show right b)
     (let ((bufferline-pick--window-labels (list (cons right ?s))))
       (setq string (bufferline-test--render right b)))
     (should (string-prefix-p " s " string))
     (should (string-match-p "<margin>" string))
     (should (< (string-match " s " string) (string-match "<margin>" string)))
     (should (eq (plist-get (get-text-property 1 'face string) :weight) 'bold)))))

(ert-deftest bufferline-test-pick-window-badge-is-not-a-tab-letter ()
  (bufferline-test-with-frame
   (let* ((right (split-window-right))
          (b (bufferline-test--buffer "b"))
          letter)
     (bufferline-test--show right b)
     (let ((bufferline-pick--window-labels (list (cons right ?s))))
       (setq letter (bufferline-test--pick-letter (bufferline-test--render right b))))
     ;; the tab keeps its icon, the letter belongs to the window
     (should-not letter))))

(defun bufferline-test--window-overlays (window)
  "Return the window pick letters drawn in overlays in WINDOW's buffer."
  (with-current-buffer (window-buffer window)
    (delq nil
          (mapcar (lambda (ov)
                    (when (eq (overlay-get ov 'bufferline-pick-window) window)
                      (should (eq (overlay-get ov 'window) window))
                      (let ((string (overlay-get ov 'before-string)))
                        (string-match "\\S-" (substring-no-properties string 1))
                        (aref string (1+ (match-beginning 0))))))
                  (overlays-in (point-min) (point-max))))))

(defmacro bufferline-test-with-tab-lines (&rest body)
  "Run BODY as if bufferline drew a tab line in every window."
  (declare (indent 0) (debug t))
  `(cl-letf (((symbol-function 'bufferline-pick--tab-line-drawn-p) #'always))
     ,@body))

(ert-deftest bufferline-test-pick-window-style-default ()
  (should (eq (default-value 'bufferline-pick-window-style) 'both)))

(ert-deftest bufferline-test-pick-window-style-both ()
  (bufferline-test-with-frame
   (let* ((left (selected-window))
          (right (split-window-right))
          (b (bufferline-test--buffer "b"))
          (bufferline-pick-alphabet "s")
          (bufferline-pick-window-style 'both)
          overlays badge)
     (bufferline-test--show right b)
     (select-window left)
     (bufferline-test-with-tab-lines
      (bufferline-test-with-keys
       (list (lambda (_prompt)
               (setq overlays (bufferline-test--window-overlays right)
                     badge (bufferline-test--window-badge (bufferline-test--render right b)))
               ?q))
       (bufferline-pick-read-window "To window: ")))
     (should (equal overlays '(?s)))
     (should (eq badge ?s))
     (should-not (bufferline-test--window-overlays right)))))

(ert-deftest bufferline-test-pick-window-style-tab-line ()
  (bufferline-test-with-frame
   (let* ((left (selected-window))
          (right (split-window-right))
          (b (bufferline-test--buffer "b"))
          (bufferline-pick-alphabet "s")
          (bufferline-pick-window-style 'tab-line)
          overlays badge)
     (bufferline-test--show right b)
     (select-window left)
     (bufferline-test-with-tab-lines
      (bufferline-test-with-keys
       (list (lambda (_prompt)
               (setq overlays (bufferline-test--window-overlays right)
                     badge (bufferline-test--window-badge (bufferline-test--render right b)))
               ?q))
       (bufferline-pick-read-window "To window: ")))
     (should-not overlays)
     (should (eq badge ?s)))))

(ert-deftest bufferline-test-pick-window-style-overlay ()
  (bufferline-test-with-frame
   (let* ((left (selected-window))
          (right (split-window-right))
          (b (bufferline-test--buffer "b"))
          (bufferline-pick-alphabet "s")
          (bufferline-pick-window-style 'overlay)
          overlays badge)
     (bufferline-test--show right b)
     (select-window left)
     (bufferline-test-with-tab-lines
      (bufferline-test-with-keys
       (list (lambda (_prompt)
               (setq overlays (bufferline-test--window-overlays right)
                     badge (bufferline-test--window-badge (bufferline-test--render right b)))
               ?q))
       (bufferline-pick-read-window "To window: ")))
     (should (equal overlays '(?s)))
     (should-not badge))))

(ert-deftest bufferline-test-pick-window-overlay-without-tab-line ()
  (bufferline-test-with-frame
   (let* ((left (selected-window))
          (right (split-window-right))
          (b (bufferline-test--buffer "b"))
          (bufferline-pick-alphabet "s")
          (bufferline-pick-window-style 'tab-line)
          overlays)
     (bufferline-test--show right b)
     (set-window-parameter right 'tab-line-format 'none)
     (select-window left)
     (bufferline-test-with-keys
      (list (lambda (_prompt)
              (setq overlays (bufferline-test--window-overlays right))
              ?q))
      (bufferline-pick-read-window "To window: "))
     ;; the tab line cannot show the letter, so the window does
     (should (equal overlays '(?s))))))

(ert-deftest bufferline-test-pick-window-overlay-only-in-its-window ()
  (bufferline-test-with-frame
   (let* ((left (selected-window))
          (middle (split-window-right))
          (right (split-window middle nil 'right))
          (b (bufferline-test--buffer "b"))
          (bufferline-pick-alphabet "as")
          (bufferline-pick-window-style 'overlay)
          overlays)
     ;; both windows show the same buffer, each with its own letter
     (bufferline-test--show middle b)
     (bufferline-test--show right b)
     (select-window left)
     (bufferline-test-with-keys
      (list (lambda (_prompt)
              (setq overlays (list (bufferline-test--window-overlays middle)
                                   (bufferline-test--window-overlays right)))
              ?q))
      (bufferline-pick-read-window "To window: "))
     (should (equal overlays '((?a) (?s)))))))

(ert-deftest bufferline-test-pick-window-overlay-goes-away-on-quit ()
  (bufferline-test-with-frame
   (let* ((right (split-window-right))
          (b (bufferline-test--buffer "b"))
          (bufferline-pick-window-style 'overlay))
     (bufferline-test--show right b)
     (select-window (frame-first-window))
     (bufferline-test-with-keys (list (lambda (_prompt) (signal 'quit nil)))
                                (condition-case nil
                                    (bufferline-pick-read-window "To window: ")
                                  (quit nil)))
     (should-not (bufferline-test--window-overlays right)))))

(ert-deftest bufferline-test-pick-window-no-overlay-in-minibuffer-pick ()
  (bufferline-test-with-frame
   (let* ((right (split-window-right))
          (b (bufferline-test--buffer "b"))
          (bufferline-pick-in-place nil)
          overlays)
     (bufferline-test--show right b)
     (select-window (frame-first-window))
     (bufferline-test-with-keys
      (list (lambda (_prompt)
              (setq overlays (bufferline-test--window-overlays right))
              ?q))
      (bufferline-pick-read-window "To window: "))
     (should-not overlays))))

;;; Hiding the tab line

(define-derived-mode bufferline-test-tool-mode special-mode "Tool"
  "Major mode standing in for a helper buffer such as Dired or Magit.")

(define-derived-mode bufferline-test-tool-child-mode bufferline-test-tool-mode "Tool Child"
  "Major mode deriving from `bufferline-test-tool-mode'.")

(defun bufferline-test--tool-buffer (name &optional mode)
  "Return a fresh buffer called NAME in MODE or `bufferline-test-tool-mode'."
  (let ((buf (bufferline-test--buffer name)))
    (with-current-buffer buf
      (funcall (or mode #'bufferline-test-tool-mode)))
    buf))

(defun bufferline-test--hidden-p (window)
  "Return non-nil if bufferline has hidden the tab line of WINDOW."
  (and (eq (window-parameter window 'tab-line-format) 'none)
       (window-parameter window 'bufferline-hidden)))

(ert-deftest bufferline-test-hide-off-by-default ()
  (should-not (default-value 'bufferline-hide-single-tab))
  (should-not (default-value 'bufferline-hide-in-excluded-buffers))
  (bufferline-test-with-frame
   (let ((tool (bufferline-test--tool-buffer "tool"))
         (bufferline-exclude-modes '(bufferline-test-tool-mode)))
     (bufferline-test--show (selected-window) tool)
     (bufferline-ui-update-visibility)
     (should-not (window-parameter nil 'tab-line-format))
     (should-not (window-parameter nil 'bufferline-hidden)))))

(ert-deftest bufferline-test-hide-single-tab ()
  (bufferline-test-with-frame
   (let ((a (bufferline-test--buffer "a"))
         (b (bufferline-test--buffer "b"))
         (bufferline-hide-single-tab t))
     (bufferline-test--show (selected-window) a)
     (bufferline-ui-update-visibility)
     (should (bufferline-test--hidden-p (selected-window)))
     ;; a second tab brings the tab line back
     (bufferline-test--show (selected-window) b)
     (bufferline-ui-update-visibility)
     (should-not (window-parameter nil 'tab-line-format))
     (should-not (window-parameter nil 'bufferline-hidden))
     ;; and losing it hides the tab line again
     (bufferline-close-tab b)
     (bufferline-ui-update-visibility)
     (should (bufferline-test--hidden-p (selected-window))))))

(ert-deftest bufferline-test-hide-single-tab-without-tabs ()
  (bufferline-test-with-frame
   (let ((bufferline-hide-single-tab t))
     ;; the blank internal buffer gets no tab, leaving the window none
     (should-not (bufferline-test--tabs (selected-window)))
     (bufferline-ui-update-visibility)
     (should (bufferline-test--hidden-p (selected-window))))))

(ert-deftest bufferline-test-hide-single-tab-per-window ()
  (bufferline-test-with-frame
   (let* ((left (selected-window))
          (right (split-window-right))
          (a (bufferline-test--buffer "a"))
          (b (bufferline-test--buffer "b"))
          (c (bufferline-test--buffer "c"))
          (bufferline-hide-single-tab t))
     (bufferline-test--show right c)
     (bufferline-test--show left a b)
     (bufferline-ui-update-visibility)
     (should-not (bufferline-test--hidden-p left))
     (should (bufferline-test--hidden-p right)))))

(ert-deftest bufferline-test-hide-single-tab-turned-off ()
  (bufferline-test-with-frame
   (let ((a (bufferline-test--buffer "a")))
     (bufferline-test--show (selected-window) a)
     (let ((bufferline-hide-single-tab t))
       (bufferline-ui-update-visibility))
     (should (bufferline-test--hidden-p (selected-window)))
     (bufferline-ui-update-visibility)
     (should-not (window-parameter nil 'tab-line-format))
     (should-not (window-parameter nil 'bufferline-hidden)))))

(ert-deftest bufferline-test-hide-in-excluded-mode ()
  (bufferline-test-with-frame
   (let ((a (bufferline-test--buffer "a"))
         (b (bufferline-test--buffer "b"))
         (tool (bufferline-test--tool-buffer "tool"))
         (bufferline-exclude-modes '(bufferline-test-tool-mode))
         (bufferline-hide-in-excluded-buffers t))
     (bufferline-test--show (selected-window) a b)
     (bufferline-ui-update-visibility)
     (should-not (bufferline-test--hidden-p (selected-window)))
     ;; hidden over the excluded buffer although the window has tabs
     (bufferline-test--show (selected-window) tool)
     (should (equal (bufferline-test--tabs (selected-window)) (list a b)))
     (bufferline-ui-update-visibility)
     (should (bufferline-test--hidden-p (selected-window)))
     (bufferline-test--show (selected-window) a)
     (bufferline-ui-update-visibility)
     (should-not (window-parameter nil 'tab-line-format)))))

(ert-deftest bufferline-test-hide-in-excluded-follows-every-filter ()
  (bufferline-test-with-frame
   (let ((star (bufferline-test--buffer "*star*"))
         (rejected (bufferline-test--buffer "rejected"))
         (kept (bufferline-test--buffer "kept"))
         (bufferline-show-special-buffers nil)
         (bufferline-custom-filter
          (lambda (buf) (not (equal (buffer-name buf) "rejected"))))
         (bufferline-hide-in-excluded-buffers t))
     (dolist (spec `((,star . t) (,rejected . t) (,kept . nil)))
       (bufferline-test--show (selected-window) (car spec))
       (bufferline-ui-update-visibility)
       (should (eq (and (bufferline-test--hidden-p (selected-window)) t)
                   (cdr spec)))))))

(ert-deftest bufferline-test-hide-in-listed-modes ()
  (bufferline-test-with-frame
   (let ((a (bufferline-test--buffer "a"))
         (tool (bufferline-test--tool-buffer "tool"))
         (child (bufferline-test--tool-buffer "child" #'bufferline-test-tool-child-mode))
         (bufferline-hide-in-excluded-buffers '(bufferline-test-tool-mode)))
     ;; listed modes hide the tab line even over buffers that get a tab
     (bufferline-test--show (selected-window) a tool)
     (should (memq tool (bufferline-test--tabs (selected-window))))
     (bufferline-ui-update-visibility)
     (should (bufferline-test--hidden-p (selected-window)))
     ;; and so do modes deriving from them
     (bufferline-test--show (selected-window) child)
     (bufferline-ui-update-visibility)
     (should (bufferline-test--hidden-p (selected-window)))
     (bufferline-test--show (selected-window) a)
     (bufferline-ui-update-visibility)
     (should-not (window-parameter nil 'tab-line-format)))))

(ert-deftest bufferline-test-hide-in-listed-modes-only ()
  (bufferline-test-with-frame
   (let ((tool (bufferline-test--tool-buffer "tool"))
         (bufferline-exclude-modes '(bufferline-test-tool-mode))
         (bufferline-hide-in-excluded-buffers '(dired-mode)))
     ;; an excluded mode that is not listed keeps the tab line
     (bufferline-test--show (selected-window) tool)
     (bufferline-ui-update-visibility)
     (should-not (window-parameter nil 'tab-line-format)))))

(ert-deftest bufferline-test-hide-in-excluded-per-window ()
  (bufferline-test-with-frame
   (let* ((left (selected-window))
          (right (split-window-right))
          (a (bufferline-test--buffer "a"))
          (tool (bufferline-test--tool-buffer "tool"))
          (bufferline-exclude-modes '(bufferline-test-tool-mode))
          (bufferline-hide-in-excluded-buffers t))
     (bufferline-test--show right tool)
     (bufferline-test--show left a)
     (bufferline-ui-update-visibility)
     (should-not (bufferline-test--hidden-p left))
     (should (bufferline-test--hidden-p right)))))

(ert-deftest bufferline-test-hide-leaves-foreign-tab-line-format ()
  (bufferline-test-with-frame
   (let ((a (bufferline-test--buffer "a"))
         (bufferline-hide-single-tab t))
     (bufferline-test--show (selected-window) a)
     ;; a format set by someone else is neither replaced nor cleared
     (set-window-parameter nil 'tab-line-format "custom")
     (bufferline-ui-update-visibility)
     (should (equal (window-parameter nil 'tab-line-format) "custom"))
     (set-window-parameter nil 'tab-line-format 'none)
     (let ((bufferline-hide-single-tab nil))
       (bufferline-ui-update-visibility))
     (should (eq (window-parameter nil 'tab-line-format) 'none))
     (should-not (window-parameter nil 'bufferline-hidden))
     (bufferline-ui-restore-visibility)
     (should (eq (window-parameter nil 'tab-line-format) 'none)))))

(ert-deftest bufferline-test-hide-stops-owning-replaced-format ()
  (bufferline-test-with-frame
   (let ((a (bufferline-test--buffer "a"))
         (b (bufferline-test--buffer "b"))
         (bufferline-hide-single-tab t))
     (bufferline-test--show (selected-window) a)
     (bufferline-ui-update-visibility)
     (should (bufferline-test--hidden-p (selected-window)))
     ;; someone else takes over the parameter while it is hidden
     (set-window-parameter nil 'tab-line-format "custom")
     (bufferline-test--show (selected-window) b)
     (bufferline-ui-update-visibility)
     (should (equal (window-parameter nil 'tab-line-format) "custom"))
     (should-not (window-parameter nil 'bufferline-hidden)))))

(ert-deftest bufferline-test-hide-restore ()
  (bufferline-test-with-frame
   (let* ((left (selected-window))
          (right (split-window-right))
          (a (bufferline-test--buffer "a"))
          (b (bufferline-test--buffer "b"))
          (bufferline-hide-single-tab t))
     (bufferline-test--show right b)
     (bufferline-test--show left a)
     (bufferline-ui-update-visibility (selected-frame))
     (should (bufferline-test--hidden-p left))
     (should (bufferline-test--hidden-p right))
     (bufferline-ui-restore-visibility)
     (dolist (win (list left right))
       (should-not (window-parameter win 'tab-line-format))
       (should-not (window-parameter win 'bufferline-hidden))))))

(ert-deftest bufferline-test-hide-keeps-selection ()
  (bufferline-test-with-frame
   (let* ((left (selected-window))
          (right (split-window-right))
          (a (bufferline-test--buffer "a"))
          (b (bufferline-test--buffer "b"))
          (bufferline-hide-single-tab t))
     (bufferline-test--show right b)
     (bufferline-test--show left a)
     (with-current-buffer b
       (bufferline-ui-update-visibility)
       (should (eq (current-buffer) b)))
     (should (eq (selected-window) left)))))

;;; Close button on tabs

(defun bufferline-test--close-start (string)
  "Return the index where the close button starts in STRING, or nil."
  (seq-position (number-sequence 0 (1- (length string)))
                nil
                (lambda (i _) (equal (get-text-property i 'help-echo string) "Close tab"))))

(defun bufferline-test--click-close (window buffer)
  "Click the close button of BUFFER's tab in WINDOW's tab line."
  (let* ((string (bufferline-test--render window buffer))
         (index (bufferline-test--close-start string)))
    (bufferline-close-tab-at-click
     (list 'mouse-1 (list window 'tab-line '(0 . 0) 0 (cons string index)
                          nil '(0 . 0) nil '(0 . 0) '(0 . 0))))))

(ert-deftest bufferline-test-close-icon-off-by-default ()
  (should-not (default-value 'bufferline-show-tab-close-icon))
  (bufferline-test-with-frame
   (let ((a (bufferline-test--buffer "a"))
         (b (bufferline-test--buffer "b")))
     (bufferline-test--show (selected-window) a b)
     (dolist (buf (list a b))
       (let ((string (bufferline-test--render (selected-window) buf)))
         (should-not (bufferline-test--close-start string))
         (should-not (string-search bufferline-close-icon string)))))))

(ert-deftest bufferline-test-close-icon-on-every-tab ()
  (bufferline-test-with-frame
   (let ((a (bufferline-test--buffer "a"))
         (b (bufferline-test--buffer "b"))
         (bufferline-show-tab-close-icon t)
         (bufferline-tab-padding-horizontal 2))
     (bufferline-test--show (selected-window) a b)
     (dolist (buf (list a b))
       (let ((string (bufferline-test--render (selected-window) buf)))
         ;; one space before the icon, the tab padding after it
         (should (string-suffix-p (concat (buffer-name buf) " " bufferline-close-icon "  ")
                                  (substring-no-properties string)))
         (should (= (bufferline-test--close-start string)
                    (- (length string) 2 (length bufferline-close-icon)))))))))

(ert-deftest bufferline-test-close-icon-after-indicators ()
  (bufferline-test-with-frame
   (let ((a (bufferline-test--buffer "a"))
         (bufferline-show-tab-close-icon t)
         (bufferline-show-modified t))
     (bufferline-test--show (selected-window) a)
     (with-current-buffer a (insert "change"))
     (should (string-search (concat bufferline-modified-icon " " bufferline-close-icon)
                            (substring-no-properties
                             (bufferline-test--render (selected-window) a)))))))

(ert-deftest bufferline-test-close-icon-active-only ()
  (bufferline-test-with-frame
   (let ((a (bufferline-test--buffer "a"))
         (b (bufferline-test--buffer "b"))
         (bufferline-show-tab-close-icon 'active))
     (bufferline-test--show (selected-window) a b)
     (should (bufferline-test--close-start (bufferline-test--render (selected-window) b)))
     (should-not (bufferline-test--close-start (bufferline-test--render (selected-window) a)))
     (bufferline-test--show (selected-window) a)
     (should (bufferline-test--close-start (bufferline-test--render (selected-window) a)))
     (should-not (bufferline-test--close-start (bufferline-test--render (selected-window) b))))))

(ert-deftest bufferline-test-close-icon-properties ()
  (bufferline-test-with-frame
   (let* ((a (bufferline-test--buffer "a"))
          (b (bufferline-test--buffer "b"))
          (bufferline-show-tab-close-icon t)
          (bufferline-close-icon-hover-face 'bufferline-test-pick)
          (_ (bufferline-test--show (selected-window) a b))
          (string (bufferline-test--render (selected-window) a))
          (start (bufferline-test--close-start string))
          (icon-map (get-text-property start 'keymap string))
          (space-map (get-text-property (1- start) 'keymap string)))
     (should (eq (lookup-key icon-map [tab-line mouse-1]) #'bufferline-close-tab-at-click))
     ;; the rest of the tab bindings still work on the icon
     (should (eq (lookup-key icon-map [tab-line mouse-2]) #'tab-line-close-tab))
     (should (eq (get-text-property start 'tab string) a))
     (should (equal (plist-get (get-text-property start 'mouse-face string) :foreground)
                    "#ff0000"))
     ;; the space before it belongs to the tab
     (should (eq (lookup-key space-map [tab-line mouse-1]) #'tab-line-select-tab))
     (should-not (get-text-property (1- start) 'mouse-face string))
     (should-not (get-text-property (1- start) 'help-echo string)))))

(ert-deftest bufferline-test-close-icon-custom-string ()
  (bufferline-test-with-frame
   (let ((a (bufferline-test--buffer "a"))
         (bufferline-show-tab-close-icon t)
         (bufferline-close-icon "[x]"))
     (bufferline-test--show (selected-window) a)
     (let* ((string (bufferline-test--render (selected-window) a))
            (start (bufferline-test--close-start string)))
       (should (equal (substring-no-properties string start (+ start 3)) "[x]"))
       (dotimes (i 3)
         (should (equal (get-text-property (+ start i) 'help-echo string) "Close tab")))
       (should-not (get-text-property (+ start 3) 'help-echo string))))))

(ert-deftest bufferline-test-close-icon-click-inactive-tab ()
  (bufferline-test-with-frame
   (let ((a (bufferline-test--buffer "a"))
         (b (bufferline-test--buffer "b"))
         (c (bufferline-test--buffer "c"))
         (bufferline-show-tab-close-icon t))
     (bufferline-test--show (selected-window) a b c a)
     (bufferline-test--click-close (selected-window) b)
     (should-not (buffer-live-p b))
     (should (eq (window-buffer) a))
     (should (equal (bufferline-test--tabs (selected-window)) (list a c))))))

(ert-deftest bufferline-test-close-icon-click-current-tab ()
  (bufferline-test-with-frame
   (let ((a (bufferline-test--buffer "a"))
         (b (bufferline-test--buffer "b"))
         (bufferline-show-tab-close-icon t))
     (bufferline-test--show (selected-window) a b)
     (bufferline-test--click-close (selected-window) b)
     (should-not (buffer-live-p b))
     (should (eq (window-buffer) a)))))

(ert-deftest bufferline-test-close-icon-click-other-window ()
  (bufferline-test-with-frame
   (let* ((left (selected-window))
          (right (split-window-right))
          (a (bufferline-test--buffer "a"))
          (c (bufferline-test--buffer "c"))
          (d (bufferline-test--buffer "d"))
          (bufferline-show-tab-close-icon t))
     (bufferline-test--show right c d)
     (bufferline-test--show left a)
     (bufferline-test--click-close right d)
     (should-not (buffer-live-p d))
     ;; the clicked window falls back to its other tab, selection stays
     (should (eq (window-buffer right) c))
     (should (eq (window-buffer left) a))
     (should (eq (selected-window) left)))))

(ert-deftest bufferline-test-close-icon-click-without-tab ()
  (bufferline-test-with-frame
   (let ((a (bufferline-test--buffer "a")))
     (bufferline-test--show (selected-window) a)
     (bufferline-close-tab-at-click
      (list 'mouse-1 (list (selected-window) 'tab-line '(0 . 0) 0 (cons "plain" 0)
                           nil '(0 . 0) nil '(0 . 0) '(0 . 0))))
     (should (buffer-live-p a))
     (should (eq (window-buffer) a)))))

(ert-deftest bufferline-test-close-icon-tab-width ()
  (bufferline-test-with-frame
   (let ((a (bufferline-test--buffer "a"))
         (b (bufferline-test--buffer "b")))
     (bufferline-test--show (selected-window) a b)
     (let* ((tabs (bufferline-test--tabs (selected-window)))
            (plain (bufferline-buffers-tab-width a tabs))
            (extra (1+ (string-width bufferline-close-icon))))
       (let ((bufferline-show-tab-close-icon t))
         (should (= (bufferline-buffers-tab-width a tabs) (+ plain extra)))
         (should (= (bufferline-buffers-tab-width b tabs) (+ plain extra))))
       (let ((bufferline-show-tab-close-icon 'active))
         (should (= (bufferline-buffers-tab-width a tabs) plain))
         (should (= (bufferline-buffers-tab-width b tabs) (+ plain extra))))))))

;;; Diagnostics

(defvar bufferline-test--flymake nil
  "Alist of (BUFFER . TYPES) reported by the stubbed `flymake-diagnostics'.")

(defmacro bufferline-test-with-flymake (spec &rest body)
  "Run BODY with Flymake on in the buffers of SPEC, reporting their TYPES.
SPEC is an alist of (BUFFER . TYPES), one diagnostic per type."
  (declare (indent 1) (debug t))
  `(let ((bufferline-test--flymake ,spec))
     (dolist (pair bufferline-test--flymake)
       (with-current-buffer (car pair)
         (setq-local flymake-mode t)))
     (cl-letf (((symbol-function 'flymake-diagnostics)
                (lambda (&rest _)
                  (mapcar (lambda (type)
                            (flymake-make-diagnostic (current-buffer) 1 1 type "msg"))
                          (cdr (assq (current-buffer) bufferline-test--flymake))))))
       ,@body)))

(put 'bufferline-test-lsp-error 'flymake-category 'flymake-error)
(put 'bufferline-test-lsp-warning 'flymake-category 'flymake-warning)

(ert-deftest bufferline-test-diagnostics-without-checker ()
  (bufferline-test-with-frame
   (let ((a (bufferline-test--buffer "a")))
     (should-not (bufferline-diagnostics-counts a))
     (should (equal (bufferline-diagnostics-badge a) "")))))

(ert-deftest bufferline-test-diagnostics-flymake-counts ()
  (bufferline-test-with-frame
   (let ((a (bufferline-test--buffer "a")))
     (bufferline-test-with-flymake `((,a :error :warning :warning :note))
                                   (should (equal (bufferline-diagnostics-counts a)
                                                  '((error . 1) (warning . 2) (note . 1))))))))

(ert-deftest bufferline-test-diagnostics-flymake-clean ()
  (bufferline-test-with-frame
   (let ((a (bufferline-test--buffer "a")))
     (bufferline-test-with-flymake `((,a))
                                   (should (equal (bufferline-diagnostics-counts a)
                                                  '((error . 0) (warning . 0) (note . 0))))
                                   (should-not (bufferline-diagnostics-level (bufferline-diagnostics-counts a)))
                                   (should (equal (bufferline-diagnostics-badge a) ""))))))

(ert-deftest bufferline-test-diagnostics-flymake-backend-types ()
  (bufferline-test-with-frame
   (let ((a (bufferline-test--buffer "a")))
     ;; types inheriting a Flymake category count as that level
     (bufferline-test-with-flymake `((,a bufferline-test-lsp-error
                                         bufferline-test-lsp-warning
                                         bufferline-test-unknown))
                                   (should (equal (bufferline-diagnostics-counts a)
                                                  '((error . 1) (warning . 1) (note . 0))))))))

(ert-deftest bufferline-test-diagnostics-level ()
  (should (eq (bufferline-diagnostics-level '((error . 1) (warning . 3) (note . 2))) 'error))
  (should (eq (bufferline-diagnostics-level '((error . 0) (warning . 3) (note . 2))) 'warning))
  (should (eq (bufferline-diagnostics-level '((error . 0) (warning . 0) (note . 2))) 'note))
  (should-not (bufferline-diagnostics-level '((error . 0) (warning . 0) (note . 0))))
  (should-not (bufferline-diagnostics-level nil)))

(ert-deftest bufferline-test-diagnostics-badge ()
  (bufferline-test-with-frame
   (let ((a (bufferline-test--buffer "a"))
         (b (bufferline-test--buffer "b"))
         (c (bufferline-test--buffer "c"))
         (bufferline-diagnostics-error-icon "E")
         (bufferline-diagnostics-warning-icon "W")
         (bufferline-diagnostics-info-icon "I"))
     (bufferline-test-with-flymake `((,a :error :error :warning)
                                     (,b :warning :note)
                                     (,c :note))
                                   ;; only the most severe level is shown
                                   (should (equal (bufferline-diagnostics-badge a) " E 2"))
                                   (should (equal (bufferline-diagnostics-badge b) " W 1"))
                                   (should (equal (bufferline-diagnostics-badge c) " I 1"))))))

(ert-deftest bufferline-test-diagnostics-custom-indicator ()
  (bufferline-test-with-frame
   (let* ((a (bufferline-test--buffer "a"))
          (seen nil)
          (bufferline-diagnostics-indicator
           (lambda (&rest args) (setq seen args) "!")))
     (bufferline-test-with-flymake `((,a :warning :note))
                                   (should (equal (bufferline-diagnostics-badge a) "!"))
                                   (should (equal seen (list 2 'warning '((error . 0) (warning . 1) (note . 1)) a)))))))

(ert-deftest bufferline-test-diagnostics-badge-on-tab ()
  (bufferline-test-with-frame
   (let ((a (bufferline-test--buffer "a"))
         (bufferline-diagnostics-error-icon "E"))
     (bufferline-test--show (selected-window) a)
     (bufferline-test-with-flymake `((,a :error))
                                   (let ((bufferline-show-diagnostics t))
                                     (should (string-search "a E 1" (bufferline-test--render (selected-window) a))))
                                   (let ((bufferline-show-diagnostics nil))
                                     (should-not (string-search "E 1" (bufferline-test--render (selected-window) a))))))))

(defvar bufferline-test--flycheck nil
  "Alist of (BUFFER . LEVELS) reported by the stubbed Flycheck.")

(defvar-local flycheck-current-errors nil)

(defmacro bufferline-test-with-flycheck (spec &rest body)
  "Run BODY with Flycheck on in the buffers of SPEC, reporting their LEVELS.
SPEC is an alist of (BUFFER . LEVELS), one error per level.  Errors are
stood in for by their level, counted by a stubbed `flycheck-count-errors'."
  (declare (indent 1) (debug t))
  `(let ((bufferline-test--flycheck ,spec))
     (dolist (pair bufferline-test--flycheck)
       (with-current-buffer (car pair)
         (setq-local flycheck-mode t)
         (setq flycheck-current-errors (cdr pair))))
     (cl-letf (((symbol-function 'flycheck-count-errors)
                (lambda (errors)
                  (let (counts)
                    (dolist (level errors)
                      (let ((cell (assq level counts)))
                        (if cell
                            (setcdr cell (1+ (cdr cell)))
                          (push (cons level 1) counts))))
                    counts))))
       ,@body)))

(ert-deftest bufferline-test-diagnostics-flycheck-counts ()
  (bufferline-test-with-frame
   (let ((a (bufferline-test--buffer "a")))
     (bufferline-test-with-flycheck `((,a error warning warning info info info))
                                    (should (equal (bufferline-diagnostics-counts a)
                                                   '((error . 1) (warning . 2) (note . 3))))))))

(ert-deftest bufferline-test-diagnostics-flycheck-clean ()
  (bufferline-test-with-frame
   (let ((a (bufferline-test--buffer "a")))
     (bufferline-test-with-flycheck `((,a))
                                    (should (equal (bufferline-diagnostics-counts a)
                                                   '((error . 0) (warning . 0) (note . 0))))))))

(ert-deftest bufferline-test-diagnostics-flycheck-badge ()
  (bufferline-test-with-frame
   (let ((a (bufferline-test--buffer "a"))
         (bufferline-diagnostics-warning-icon "W"))
     (bufferline-test-with-flycheck `((,a warning warning))
                                    (should (equal (bufferline-diagnostics-badge a) " W 2"))))))

(ert-deftest bufferline-test-diagnostics-flycheck-off ()
  (bufferline-test-with-frame
   (let ((a (bufferline-test--buffer "a")))
     (bufferline-test-with-flycheck nil
                                    (with-current-buffer a
                                      (setq flycheck-current-errors '(error)))
                                    (should-not (bufferline-diagnostics-counts a))))))

(ert-deftest bufferline-test-diagnostics-sources-order ()
  (bufferline-test-with-frame
   (let ((a (bufferline-test--buffer "a"))
         (b (bufferline-test--buffer "b")))
     (bufferline-test-with-flymake `((,a :error))
                                   (bufferline-test-with-flycheck `((,a warning) (,b warning))
                                                                  ;; the first enabled source wins, nothing is counted twice
                                                                  (let ((bufferline-diagnostics-sources '(flymake flycheck)))
                                                                    (should (equal (bufferline-diagnostics-counts a)
                                                                                   '((error . 1) (warning . 0) (note . 0))))
                                                                    (should (equal (bufferline-diagnostics-counts b)
                                                                                   '((error . 0) (warning . 1) (note . 0)))))
                                                                  (let ((bufferline-diagnostics-sources '(flycheck flymake)))
                                                                    (should (equal (bufferline-diagnostics-counts a)
                                                                                   '((error . 0) (warning . 1) (note . 0)))))
                                                                  (let ((bufferline-diagnostics-sources '(flymake)))
                                                                    (should-not (bufferline-diagnostics-counts b)))
                                                                  (let ((bufferline-diagnostics-sources nil))
                                                                    (should-not (bufferline-diagnostics-counts a))))))))

(defface bufferline-test-warning '((t :foreground "#ffaa00"))
  "Face with a color batch Emacs can resolve, for warning highlights.")

(defmacro bufferline-test-with-highlight (mode &rest body)
  "Run BODY with `bufferline-diagnostics-highlight' set to MODE.
Errors and warnings are colored by faces batch Emacs can resolve."
  (declare (indent 1) (debug t))
  `(let ((bufferline-diagnostics-highlight ,mode)
         (bufferline-diagnostics-error-face 'bufferline-test-pick)
         (bufferline-diagnostics-warning-face 'bufferline-test-warning)
         (bufferline-separator-style 'vertical))
     ,@body))

(defun bufferline-test--name-color (string name)
  "Return the foreground NAME is drawn in within the tab STRING."
  (plist-get (get-text-property (string-search name (substring-no-properties string))
                                'face string)
             :foreground))

(defun bufferline-test--separator-color (string)
  "Return the foreground of the separator glyph opening STRING, or nil."
  (let ((sep (car (cdr (assq 'vertical bufferline-constants-separators)))))
    (and (string-prefix-p sep (substring-no-properties string))
         (plist-get (get-text-property 0 'face string) :foreground))))

(ert-deftest bufferline-test-diagnostics-highlight-off-by-default ()
  (should-not (default-value 'bufferline-diagnostics-highlight))
  (bufferline-test-with-frame
   (let ((errs (bufferline-test--buffer "errs")))
     (bufferline-test-with-flymake `((,errs :error))
                                   (should-not (bufferline-diagnostics-highlight-color errs))))))

(ert-deftest bufferline-test-diagnostics-highlight-color ()
  (bufferline-test-with-frame
   (let ((errs (bufferline-test--buffer "errs"))
         (warns (bufferline-test--buffer "warns"))
         (notes (bufferline-test--buffer "notes"))
         (clean (bufferline-test--buffer "clean"))
         (plain (bufferline-test--buffer "plain")))
     (bufferline-test-with-highlight 'name
                                     (bufferline-test-with-flymake `((,errs :warning :error)
                                                                     (,warns :warning :note)
                                                                     (,notes :note)
                                                                     (,clean))
                                                                   (should (equal (bufferline-diagnostics-highlight-color errs) "#ff0000"))
                                                                   (should (equal (bufferline-diagnostics-highlight-color warns) "#ffaa00"))
                                                                   ;; notes and clean or unchecked buffers keep their color
                                                                   (should-not (bufferline-diagnostics-highlight-color notes))
                                                                   (should-not (bufferline-diagnostics-highlight-color clean))
                                                                   (should-not (bufferline-diagnostics-highlight-color plain)))))))

(ert-deftest bufferline-test-diagnostics-highlight-name ()
  (bufferline-test-with-frame
   (let ((errs (bufferline-test--buffer "errs"))
         (warns (bufferline-test--buffer "warns"))
         (clean (bufferline-test--buffer "clean")))
     (bufferline-test--show (selected-window) errs warns clean)
     (bufferline-test-with-highlight 'name
                                     (bufferline-test-with-flymake `((,errs :error) (,warns :warning) (,clean))
                                                                   (let ((plain-color (bufferline-test--name-color
                                                                                       (let ((bufferline-diagnostics-highlight nil))
                                                                                         (bufferline-test--render (selected-window) errs))
                                                                                       "errs")))
                                                                     (should (equal (bufferline-test--name-color
                                                                                     (bufferline-test--render (selected-window) errs) "errs")
                                                                                    "#ff0000"))
                                                                     (should (equal (bufferline-test--name-color
                                                                                     (bufferline-test--render (selected-window) warns) "warns")
                                                                                    "#ffaa00"))
                                                                     (should (equal (bufferline-test--name-color
                                                                                     (bufferline-test--render (selected-window) clean) "clean")
                                                                                    plain-color))
                                                                     ;; the separator is left alone
                                                                     (should-not (bufferline-test--separator-color
                                                                                  (bufferline-test--render (selected-window) errs)))))))))

(ert-deftest bufferline-test-diagnostics-highlight-name-on-current-tab ()
  (bufferline-test-with-frame
   (let ((errs (bufferline-test--buffer "errs")))
     (bufferline-test--show (selected-window) errs)
     (bufferline-test-with-highlight 'name
                                     (bufferline-test-with-flymake `((,errs :error))
                                                                   (let ((string (bufferline-test--render (selected-window) errs)))
                                                                     (should (equal (bufferline-test--name-color string "errs") "#ff0000"))
                                                                     (should-not (equal (bufferline-test--separator-color string) "#ff0000"))))))))

(ert-deftest bufferline-test-diagnostics-highlight-separator ()
  (bufferline-test-with-frame
   (let ((errs (bufferline-test--buffer "errs"))
         (warns (bufferline-test--buffer "warns"))
         (clean (bufferline-test--buffer "clean")))
     (bufferline-test--show (selected-window) errs warns clean)
     (bufferline-test-with-highlight 'separator
                                     (bufferline-test-with-flymake `((,errs :error) (,warns :warning) (,clean :note))
                                                                   ;; tabs that are not current get a separator in the color too
                                                                   (should (equal (bufferline-test--separator-color
                                                                                   (bufferline-test--render (selected-window) errs))
                                                                                  "#ff0000"))
                                                                   (should (equal (bufferline-test--separator-color
                                                                                   (bufferline-test--render (selected-window) warns))
                                                                                  "#ffaa00"))
                                                                   (should-not (equal (bufferline-test--name-color
                                                                                       (bufferline-test--render (selected-window) errs) "errs")
                                                                                      "#ff0000"))
                                                                   ;; the current tab keeps its usual indicator without diagnostics
                                                                   (let ((current (bufferline-test--separator-color
                                                                                   (bufferline-test--render (selected-window) clean))))
                                                                     (should current)
                                                                     (should-not (member current '("#ff0000" "#ffaa00"))))
                                                                   (bufferline-test--show (selected-window) errs)
                                                                   (should (equal (bufferline-test--separator-color
                                                                                   (bufferline-test--render (selected-window) errs))
                                                                                  "#ff0000"))
                                                                   (should-not (bufferline-test--separator-color
                                                                                (bufferline-test--render (selected-window) clean))))))))

(ert-deftest bufferline-test-diagnostics-highlight-both ()
  (bufferline-test-with-frame
   (let ((errs (bufferline-test--buffer "errs"))
         (other (bufferline-test--buffer "other")))
     (bufferline-test--show (selected-window) errs other)
     (bufferline-test-with-highlight 'both
                                     (bufferline-test-with-flymake `((,errs :error))
                                                                   (let ((string (bufferline-test--render (selected-window) errs)))
                                                                     (should (equal (bufferline-test--name-color string "errs") "#ff0000"))
                                                                     (should (equal (bufferline-test--separator-color string) "#ff0000"))))))))

(ert-deftest bufferline-test-diagnostics-highlight-without-badge ()
  (bufferline-test-with-frame
   (let ((errs (bufferline-test--buffer "errs"))
         (bufferline-diagnostics-error-icon "E")
         (bufferline-show-diagnostics nil))
     (bufferline-test--show (selected-window) errs)
     (bufferline-test-with-highlight 'name
                                     (bufferline-test-with-flymake `((,errs :error))
                                                                   (let ((string (bufferline-test--render (selected-window) errs)))
                                                                     (should (equal (bufferline-test--name-color string "errs") "#ff0000"))
                                                                     (should-not (string-search "E 1" string))))))))

(ert-deftest bufferline-test-diagnostics-highlight-flycheck ()
  (bufferline-test-with-frame
   (let ((warns (bufferline-test--buffer "warns")))
     (bufferline-test--show (selected-window) warns)
     (bufferline-test-with-highlight 'name
                                     (bufferline-test-with-flycheck `((,warns warning))
                                                                    (should (equal (bufferline-test--name-color
                                                                                    (bufferline-test--render (selected-window) warns) "warns")
                                                                                   "#ffaa00")))))))

(ert-deftest bufferline-test-diagnostics-cache-key-unchanged-when-off ()
  (bufferline-test-with-frame
   (let* ((a (bufferline-test--buffer "a"))
          (key (list (list a) "a"))
          (bufferline-show-diagnostics nil)
          (bufferline-diagnostics-highlight nil))
     (bufferline-test-with-flymake `((,a :error))
                                   (should (eq (bufferline-ui--cache-key (lambda (_) key) (list a)) key))))))

(ert-deftest bufferline-test-diagnostics-cache-key-follows-counts ()
  (bufferline-test-with-frame
   (let ((a (bufferline-test--buffer "a"))
         (b (bufferline-test--buffer "b"))
         (base (lambda (tabs) (list tabs))))
     (dolist (options '((t . nil) (nil . name)))
       (let ((bufferline-show-diagnostics (car options))
             (bufferline-diagnostics-highlight (cdr options)))
         (let ((clean (bufferline-test-with-flymake `((,a))
                                                    (bufferline-ui--cache-key base (list a b))))
               (broken (bufferline-test-with-flymake `((,a :error))
                                                     (bufferline-ui--cache-key base (list a b)))))
           (should (equal (car clean) (list a b)))
           (should (equal (cadr clean) '(((error . 0) (warning . 0) (note . 0)) nil)))
           (should-not (equal clean broken))))))))

(ert-deftest bufferline-test-diagnostics-cache-key-function ()
  (skip-unless (boundp 'tab-line-cache-key-function))
  (bufferline-test-with-frame
   (let ((a (bufferline-test--buffer "a"))
         (bufferline-show-diagnostics t)
         (tab-line-cache-key-function (lambda (tabs) (list tabs))))
     ;; the let binding takes the advice, so it goes away with it
     (add-function :around tab-line-cache-key-function #'bufferline-ui--cache-key)
     (bufferline-test-with-flymake `((,a :warning))
                                   (should (equal (funcall tab-line-cache-key-function (list a))
                                                  (list (list a) '(((error . 0) (warning . 1) (note . 0))))))))))

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

(ert-deftest bufferline-test-move-other-tab-to-window ()
  (bufferline-test-with-frame
   (let* ((left (selected-window))
          (right (split-window-right))
          (a (bufferline-test--buffer "a"))
          (b (bufferline-test--buffer "b"))
          (c (bufferline-test--buffer "c"))
          (d (bufferline-test--buffer "d")))
     (bufferline-test--show right d)
     (bufferline-test--show left a b c)
     (bufferline-commands--move-to-window right a)
     (should (eq (selected-window) right))
     (should (eq (window-buffer right) a))
     (should (equal (bufferline-test--tabs right) (list d a)))
     ;; the source window keeps showing what it showed
     (should (eq (window-buffer left) c))
     (should (equal (bufferline-test--tabs left) (list b c))))))

(ert-deftest bufferline-test-move-other-tab-to-window-not-a-tab-here ()
  (bufferline-test-with-frame
   (let* ((left (selected-window))
          (right (split-window-right))
          (a (bufferline-test--buffer "a"))
          (d (bufferline-test--buffer "d")))
     (bufferline-test--show right d)
     (bufferline-test--show left a)
     ;; d is the tab of the other window
     (should (equal (cadr (should-error (bufferline-commands--move-to-window right d)
                                        :type 'user-error))
                    "Buffer is not a tab here")))))

(ert-deftest bufferline-test-move-to-picked-window ()
  (bufferline-test-with-frame
   (let* ((left (selected-window))
          (middle (split-window-right))
          (right (split-window middle nil 'right))
          (a (bufferline-test--buffer "a"))
          (b (bufferline-test--buffer "b"))
          (c (bufferline-test--buffer "c"))
          (d (bufferline-test--buffer "d"))
          (bufferline-pick-alphabet "as")
          (bufferline-pick-in-place nil))
     (bufferline-test--show middle c)
     (bufferline-test--show right d)
     (bufferline-test--show left b a)
     ;; the window two to the right, past the one in between
     (bufferline-test-with-keys '(?s)
                                (bufferline-move-tab-to-window)
                                (should (equal bufferline-test--prompts
                                               '("Move a to window: [a] c  [s] d  [|] split right  [-] split below "))))
     (should (eq (selected-window) right))
     (should (equal (bufferline-test--tabs right) (list d a)))
     (should (equal (bufferline-test--tabs middle) (list c)))
     (should (equal (bufferline-test--tabs left) (list b))))))

(ert-deftest bufferline-test-move-to-picked-window-closes-emptied-split ()
  (bufferline-test-with-frame
   (let* ((left (selected-window))
          (middle (split-window-right))
          (right (split-window middle nil 'right))
          (a (bufferline-test--buffer "a"))
          (c (bufferline-test--buffer "c"))
          (d (bufferline-test--buffer "d"))
          (bufferline-pick-alphabet "as"))
     (bufferline-test--show middle c)
     (bufferline-test--show right d)
     (bufferline-test--show left a)
     (bufferline-test-with-keys '(?a)
                                (bufferline-move-tab-to-window))
     (should-not (window-live-p left))
     (should (eq (selected-window) middle))
     (should (equal (bufferline-test--tabs middle) (list c a))))))

(ert-deftest bufferline-test-move-to-picked-window-cancelled ()
  (bufferline-test-with-frame
   (let* ((left (selected-window))
          (middle (split-window-right))
          (right (split-window middle nil 'right))
          (a (bufferline-test--buffer "a"))
          (b (bufferline-test--buffer "b"))
          (bufferline-pick-alphabet "as"))
     (ignore right)
     (bufferline-test--show left b a)
     (bufferline-test-with-keys '(?q)
                                (should (equal (bufferline-move-tab-to-window) "Move cancelled")))
     (should (eq (selected-window) left))
     (should (equal (bufferline-test--tabs left) (list b a))))))

(ert-deftest bufferline-test-move-to-picked-window-auto-select ()
  (bufferline-test-with-frame
   (let* ((left (selected-window))
          (right (split-window-right))
          (a (bufferline-test--buffer "a"))
          (b (bufferline-test--buffer "b"))
          (c (bufferline-test--buffer "c"))
          (bufferline-move-tab-split-keys nil)
          (bufferline-pick-window-auto-select t))
     (bufferline-test--show right c)
     (bufferline-test--show left b a)
     (bufferline-test-with-keys '()
                                (bufferline-move-tab-to-window)
                                (should-not bufferline-test--prompts))
     (should (eq (selected-window) right))
     (should (equal (bufferline-test--tabs right) (list c a))))))

(ert-deftest bufferline-test-move-to-picked-window-auto-select-off ()
  (bufferline-test-with-frame
   (let* ((left (selected-window))
          (right (split-window-right))
          (a (bufferline-test--buffer "a"))
          (b (bufferline-test--buffer "b"))
          (c (bufferline-test--buffer "c"))
          (bufferline-pick-alphabet "a")
          (bufferline-pick-window-auto-select nil))
     (bufferline-test--show right c)
     (bufferline-test--show left b a)
     (bufferline-test-with-keys '(?a)
                                (bufferline-move-tab-to-window)
                                (should (equal (length bufferline-test--prompts) 1)))
     (should (equal (bufferline-test--tabs right) (list c a))))))

(ert-deftest bufferline-test-move-to-picked-window-skips-dedicated ()
  (bufferline-test-with-frame
   (let* ((left (selected-window))
          (middle (split-window-right))
          (right (split-window middle nil 'right))
          (a (bufferline-test--buffer "a"))
          (b (bufferline-test--buffer "b"))
          (c (bufferline-test--buffer "c"))
          (d (bufferline-test--buffer "d"))
          (bufferline-move-tab-split-keys nil))
     (bufferline-test--show middle c)
     (set-window-dedicated-p middle t)
     (bufferline-test--show right d)
     (bufferline-test--show left b a)
     ;; the dedicated window is no choice, which leaves only one
     (bufferline-test-with-keys '()
                                (bufferline-move-tab-to-window))
     (should (eq (selected-window) right))
     (should (equal (bufferline-test--tabs right) (list d a)))
     (should (eq (window-buffer middle) c)))))

(ert-deftest bufferline-test-move-to-picked-window-without-windows ()
  (bufferline-test-with-frame
   (let ((a (bufferline-test--buffer "a")))
     (bufferline-test--show (selected-window) a)
     (should (equal (cadr (should-error (bufferline-move-tab-to-window)
                                        :type 'user-error))
                    "No other window to move the tab to")))))

(ert-deftest bufferline-test-move-to-picked-window-not-a-tab ()
  (bufferline-test-with-frame
   (let ((right (split-window-right)))
     (ignore right)
     (should (equal (cadr (should-error (bufferline-move-tab-to-window)
                                        :type 'user-error))
                    "Current buffer is not a tab")))))

(ert-deftest bufferline-test-move-to-picked-window-split-keys-default ()
  (should (equal (default-value 'bufferline-move-tab-split-keys)
                 '((?| . right) (?- . below)))))

(ert-deftest bufferline-test-move-to-picked-window-split ()
  (dolist (spec '((?| right) (?- below)))
    (bufferline-test-with-frame
     (let* ((source (selected-window))
            (a (bufferline-test--buffer "a"))
            (b (bufferline-test--buffer "b"))
            (bufferline-pick-in-place nil))
       (bufferline-test--show source b a)
       (bufferline-test-with-keys (list (car spec))
                                  (bufferline-move-tab-to-window)
                                  ;; a lone window offers only the splits
                                  (should (equal bufferline-test--prompts
                                                 '("Move a to window: [|] split right  [-] split below "))))
       (let ((target (selected-window)))
         (should-not (eq target source))
         (should (eq (window-in-direction (nth 1 spec) source) target))
         (should (equal (bufferline-test--tabs target) (list a)))
         (should (equal (bufferline-test--tabs source) (list b))))))))

(ert-deftest bufferline-test-move-to-picked-window-split-beside-windows ()
  (bufferline-test-with-frame
   (let* ((left (selected-window))
          (right (split-window-right))
          (a (bufferline-test--buffer "a"))
          (b (bufferline-test--buffer "b"))
          (c (bufferline-test--buffer "c"))
          (bufferline-pick-alphabet "a"))
     (bufferline-test--show right c)
     (bufferline-test--show left b a)
     (bufferline-test-with-keys '(?-)
                                (bufferline-move-tab-to-window)
                                ;; in place, the prompt still lists the splits
                                (should (equal bufferline-test--prompts
                                               '("Move a to window: [|] split right  [-] split below "))))
     (should (eq (window-in-direction 'below left) (selected-window)))
     (should (equal (bufferline-test--tabs (selected-window)) (list a)))
     (should (equal (bufferline-test--tabs right) (list c))))))

(ert-deftest bufferline-test-move-to-picked-window-custom-split-keys ()
  (bufferline-test-with-frame
   (let* ((source (selected-window))
          (a (bufferline-test--buffer "a"))
          (b (bufferline-test--buffer "b"))
          (bufferline-move-tab-split-keys '((?v . left) (?x . above)))
          (bufferline-pick-in-place nil))
     (bufferline-test--show source b a)
     (bufferline-test-with-keys '(?x)
                                (bufferline-move-tab-to-window)
                                (should (equal bufferline-test--prompts
                                               '("Move a to window: [v] split left  [x] split above "))))
     (should (eq (window-in-direction 'above source) (selected-window))))))

(ert-deftest bufferline-test-move-to-picked-window-only-tab-gets-no-split ()
  (bufferline-test-with-frame
   (let* ((left (selected-window))
          (right (split-window-right))
          (a (bufferline-test--buffer "a"))
          (c (bufferline-test--buffer "c"))
          (bufferline-pick-window-auto-select nil)
          (bufferline-pick-in-place nil)
          (bufferline-pick-alphabet "a"))
     (bufferline-test--show right c)
     (bufferline-test--show left a)
     (bufferline-test-with-keys '(?|)
                                (should (equal (bufferline-move-tab-to-window) "Move cancelled"))
                                (should (equal bufferline-test--prompts '("Move a to window: [a] c "))))
     (should (equal (length (window-list)) 2))
     (should (eq (window-buffer left) a)))))

(ert-deftest bufferline-test-move-to-picked-window-only-tab-alone ()
  (bufferline-test-with-frame
   (let ((a (bufferline-test--buffer "a")))
     (bufferline-test--show (selected-window) a)
     (bufferline-test-with-keys '(?|)
                                (should-error (bufferline-move-tab-to-window) :type 'user-error)
                                (should-not bufferline-test--prompts))
     (should (equal (length (window-list)) 1)))))

(ert-deftest bufferline-test-move-to-picked-window-auto-split ()
  (bufferline-test-with-frame
   (let* ((source (selected-window))
          (a (bufferline-test--buffer "a"))
          (b (bufferline-test--buffer "b"))
          (bufferline-move-tab-split-keys '((?| . right))))
     (bufferline-test--show source b a)
     ;; a lone window with a single split key has one choice
     (bufferline-test-with-keys '()
                                (bufferline-move-tab-to-window)
                                (should-not bufferline-test--prompts))
     (should (eq (window-in-direction 'right source) (selected-window)))
     (should (equal (bufferline-test--tabs (selected-window)) (list a))))))

(ert-deftest bufferline-test-pick-read-window-letter-before-extra-key ()
  (bufferline-test-with-frame
   (let ((right (split-window-right))
         (bufferline-pick-alphabet "|"))
     (bufferline-test-with-keys '(?|)
                                (should (eq (bufferline-pick-read-window "To window: " nil '((?| . "split")))
                                            right))))))

(ert-deftest bufferline-test-pick-read-window-extra-key ()
  (bufferline-test-with-frame
   (let ((right (split-window-right))
         (bufferline-pick-alphabet "a"))
     (ignore right)
     (bufferline-test-with-keys '(?x)
                                (should (eq (bufferline-pick-read-window "To window: " nil '((?x . "other")))
                                            ?x))))))

(ert-deftest bufferline-test-move-picked-tab-to-picked-window ()
  (bufferline-test-with-frame
   (let* ((left (selected-window))
          (right (split-window-right))
          (a (bufferline-test--buffer "a"))
          (b (bufferline-test--buffer "b"))
          (c (bufferline-test--buffer "c"))
          (d (bufferline-test--buffer "d"))
          (bufferline-pick-alphabet "asd")
          (bufferline-pick-window-auto-select nil)
          (bufferline-pick-in-place nil))
     (bufferline-test--show right d)
     (bufferline-test--show left a b c)
     ;; first the tab, then the window
     (bufferline-test-with-keys '(?s ?a)
                                (bufferline-move-tab-to-window '(4))
                                (should (equal (reverse bufferline-test--prompts)
                                               '("Move tab: [a] a  [s] b  [d] c "
                                                 "Move b to window: [a] d  [|] split right  [-] split below "))))
     (should (eq (selected-window) right))
     (should (equal (bufferline-test--tabs right) (list d b)))
     (should (eq (window-buffer left) c))
     (should (equal (bufferline-test--tabs left) (list a c))))))

(ert-deftest bufferline-test-move-picked-tab-to-split ()
  (bufferline-test-with-frame
   (let* ((source (selected-window))
          (a (bufferline-test--buffer "a"))
          (b (bufferline-test--buffer "b"))
          (bufferline-pick-alphabet "as"))
     (bufferline-test--show source a b)
     (bufferline-test-with-keys '(?a ?|)
                                (bufferline-move-tab-to-window '(4)))
     (should (eq (window-in-direction 'right source) (selected-window)))
     (should (equal (bufferline-test--tabs (selected-window)) (list a)))
     (should (eq (window-buffer source) b))
     (should (equal (bufferline-test--tabs source) (list b))))))

(ert-deftest bufferline-test-move-picked-tab-cancelled ()
  (bufferline-test-with-frame
   (let* ((left (selected-window))
          (right (split-window-right))
          (a (bufferline-test--buffer "a"))
          (b (bufferline-test--buffer "b"))
          (bufferline-pick-alphabet "as"))
     (ignore right)
     (bufferline-test--show left a b)
     (bufferline-test-with-keys '(?q)
                                (should (equal (bufferline-move-tab-to-window '(4)) "Move cancelled"))
                                ;; no window is asked for
                                (should (equal (length bufferline-test--prompts) 1)))
     (should (eq (selected-window) left))
     (should (equal (bufferline-test--tabs left) (list a b))))))

;;; Dragging tabs

(defun bufferline-test--tab-posn (window buffer)
  "Return a mouse position over the tab of BUFFER in WINDOW's tab line."
  (let* ((string (bufferline-test--render window buffer))
         (index (text-property-not-all 0 (length string) 'tab nil string)))
    (list window 'tab-line '(0 . 0) 0 (cons string index)
          nil '(0 . 0) nil '(0 . 0) '(0 . 0))))

(defun bufferline-test--drag (from to)
  "Drag with the mouse from position FROM and drop at position TO."
  (bufferline-drag-tab (list 'drag-mouse-1 from to)))

(ert-deftest bufferline-test-drag-binding ()
  (bufferline-test-with-frame
   (let ((a (bufferline-test--buffer "a")))
     (bufferline-test--show (selected-window) a)
     (let* ((string (bufferline-test--render (selected-window) a))
            (index (text-property-not-all 0 (length string) 'tab nil string)))
       (should (eq (lookup-key (get-text-property index 'keymap string)
                               [tab-line drag-mouse-1])
                   #'bufferline-drag-tab))))))

(ert-deftest bufferline-test-drag-right ()
  (bufferline-test-with-frame
   (let* ((win (selected-window))
          (a (bufferline-test--buffer "a"))
          (b (bufferline-test--buffer "b"))
          (c (bufferline-test--buffer "c"))
          (d (bufferline-test--buffer "d")))
     (bufferline-test--show win a b c d)
     (bufferline-test--drag (bufferline-test--tab-posn win a)
                            (bufferline-test--tab-posn win c))
     (should (equal (bufferline-test--tabs win) (list b c a d)))
     ;; dragging does not switch tabs
     (should (eq (window-buffer win) d)))))

(ert-deftest bufferline-test-drag-left ()
  (bufferline-test-with-frame
   (let* ((win (selected-window))
          (a (bufferline-test--buffer "a"))
          (b (bufferline-test--buffer "b"))
          (c (bufferline-test--buffer "c"))
          (d (bufferline-test--buffer "d")))
     (bufferline-test--show win a b c d)
     (bufferline-test--drag (bufferline-test--tab-posn win d)
                            (bufferline-test--tab-posn win b))
     (should (equal (bufferline-test--tabs win) (list a d b c))))))

(ert-deftest bufferline-test-drag-to-neighbour ()
  (bufferline-test-with-frame
   (let* ((win (selected-window))
          (a (bufferline-test--buffer "a"))
          (b (bufferline-test--buffer "b"))
          (c (bufferline-test--buffer "c")))
     (bufferline-test--show win a b c)
     (bufferline-test--drag (bufferline-test--tab-posn win b)
                            (bufferline-test--tab-posn win c))
     (should (equal (bufferline-test--tabs win) (list a c b)))
     (bufferline-test--drag (bufferline-test--tab-posn win b)
                            (bufferline-test--tab-posn win c))
     (should (equal (bufferline-test--tabs win) (list a b c))))))

(ert-deftest bufferline-test-drag-keeps-order-numbers ()
  (bufferline-test-with-frame
   (let* ((win (selected-window))
          (a (bufferline-test--buffer "a"))
          (b (bufferline-test--buffer "b"))
          (c (bufferline-test--buffer "c"))
          (ids (lambda ()
                 (sort (mapcar (lambda (buf)
                                 (buffer-local-value 'bufferline-state--tab-order-id buf))
                               (list a b c))
                       #'<))))
     (bufferline-test--show win a b c)
     (let ((before (funcall ids)))
       (bufferline-test--drag (bufferline-test--tab-posn win c)
                              (bufferline-test--tab-posn win a))
       (should (equal (funcall ids) before))
       (should (= bufferline-state--tab-order-counter 3))))))

(ert-deftest bufferline-test-drag-onto-itself ()
  (bufferline-test-with-frame
   (let* ((win (selected-window))
          (a (bufferline-test--buffer "a"))
          (b (bufferline-test--buffer "b")))
     (bufferline-test--show win a b)
     (bufferline-test--drag (bufferline-test--tab-posn win a)
                            (bufferline-test--tab-posn win a))
     (should (equal (bufferline-test--tabs win) (list a b))))))

(ert-deftest bufferline-test-drag-off-the-tabs ()
  (bufferline-test-with-frame
   (let* ((win (selected-window))
          (a (bufferline-test--buffer "a"))
          (b (bufferline-test--buffer "b")))
     (bufferline-test--show win a b)
     ;; dropped on the tab line outside any tab, then in the text area
     (bufferline-test--drag (bufferline-test--tab-posn win a)
                            (list win 'tab-line '(0 . 0) 0 (cons "plain" 0)
                                  nil '(0 . 0) nil '(0 . 0) '(0 . 0)))
     (bufferline-test--drag (bufferline-test--tab-posn win a)
                            (list win 1 '(0 . 0) 0 nil 1 '(0 . 0) nil '(0 . 0) '(0 . 0)))
     (should (equal (bufferline-test--tabs win) (list a b))))))

(ert-deftest bufferline-test-drag-to-other-window ()
  (bufferline-test-with-frame
   (let* ((left (selected-window))
          (right (split-window-right))
          (a (bufferline-test--buffer "a"))
          (b (bufferline-test--buffer "b"))
          (c (bufferline-test--buffer "c"))
          (d (bufferline-test--buffer "d")))
     (bufferline-test--show right c d)
     (bufferline-test--show left a b)
     (bufferline-test--drag (bufferline-test--tab-posn left a)
                            (bufferline-test--tab-posn right d))
     (should (equal (bufferline-test--tabs left) (list b)))
     (should (equal (bufferline-test--tabs right) (list c a d)))
     (should (eq (selected-window) right)))))

(defun bufferline-test--text-posn (window)
  "Return a mouse position in the text area of WINDOW."
  (list window 1 '(0 . 0) 0 nil 1 '(0 . 0) nil '(0 . 0) '(0 . 0)))

(ert-deftest bufferline-test-drag-to-other-window-text ()
  (bufferline-test-with-frame
   (let* ((left (selected-window))
          (right (split-window-right))
          (a (bufferline-test--buffer "a"))
          (b (bufferline-test--buffer "b"))
          (c (bufferline-test--buffer "c")))
     (bufferline-test--show right c)
     (bufferline-test--show left a b)
     ;; a is not the tab shown, so its window keeps showing b
     (bufferline-test--drag (bufferline-test--tab-posn left a)
                            (bufferline-test--text-posn right))
     (should (eq (selected-window) right))
     (should (eq (window-buffer right) a))
     (should (equal (bufferline-test--tabs right) (list c a)))
     (should (eq (window-buffer left) b))
     (should (equal (bufferline-test--tabs left) (list b))))))

(ert-deftest bufferline-test-drag-to-other-window-off-the-tabs ()
  (bufferline-test-with-frame
   (let* ((left (selected-window))
          (right (split-window-right))
          (a (bufferline-test--buffer "a"))
          (b (bufferline-test--buffer "b"))
          (c (bufferline-test--buffer "c")))
     (bufferline-test--show right c)
     (bufferline-test--show left a b)
     (bufferline-test--drag (bufferline-test--tab-posn left b)
                            (list right 'tab-line '(0 . 0) 0 (cons "plain" 0)
                                  nil '(0 . 0) nil '(0 . 0) '(0 . 0)))
     (should (equal (bufferline-test--tabs right) (list c b)))
     (should (eq (window-buffer left) a)))))

(ert-deftest bufferline-test-drag-last-tab-closes-split ()
  (bufferline-test-with-frame
   (let* ((left (selected-window))
          (right (split-window-right))
          (a (bufferline-test--buffer "a"))
          (c (bufferline-test--buffer "c")))
     (bufferline-test--show right c)
     (bufferline-test--show left a)
     (bufferline-test--drag (bufferline-test--tab-posn left a)
                            (bufferline-test--text-posn right))
     (should-not (window-live-p left))
     (should (equal (bufferline-test--tabs right) (list c a))))))

(ert-deftest bufferline-test-drag-from-unselected-window ()
  (bufferline-test-with-frame
   (let* ((left (selected-window))
          (right (split-window-right))
          (a (bufferline-test--buffer "a"))
          (c (bufferline-test--buffer "c"))
          (d (bufferline-test--buffer "d")))
     (bufferline-test--show left a)
     (bufferline-test--show right c d)
     (select-window left)
     (bufferline-test--drag (bufferline-test--tab-posn right c)
                            (bufferline-test--text-posn left))
     (should (eq (selected-window) left))
     (should (eq (window-buffer left) c))
     (should (equal (bufferline-test--tabs left) (list a c)))
     (should (equal (bufferline-test--tabs right) (list d))))))

(ert-deftest bufferline-test-drag-to-dedicated-window ()
  (bufferline-test-with-frame
   (let* ((left (selected-window))
          (right (split-window-right))
          (a (bufferline-test--buffer "a"))
          (b (bufferline-test--buffer "b"))
          (c (bufferline-test--buffer "c")))
     (bufferline-test--show right c)
     (set-window-dedicated-p right t)
     (bufferline-test--show left a b)
     (should-error (bufferline-test--drag (bufferline-test--tab-posn left a)
                                          (bufferline-test--text-posn right))
                   :type 'user-error)
     (should (eq (window-buffer right) c))
     (should (equal (bufferline-test--tabs left) (list a b))))))

(ert-deftest bufferline-test-drag-to-minibuffer ()
  (bufferline-test-with-frame
   (let* ((win (selected-window))
          (a (bufferline-test--buffer "a"))
          (b (bufferline-test--buffer "b")))
     (bufferline-test--show win a b)
     (bufferline-test--drag (bufferline-test--tab-posn win a)
                            (bufferline-test--text-posn (minibuffer-window)))
     (should (eq (selected-window) win))
     (should (equal (bufferline-test--tabs win) (list a b))))))

(ert-deftest bufferline-test-drag-in-other-window ()
  (bufferline-test-with-frame
   (let* ((left (selected-window))
          (right (split-window-right))
          (a (bufferline-test--buffer "a"))
          (c (bufferline-test--buffer "c"))
          (d (bufferline-test--buffer "d")))
     (bufferline-test--show right c d)
     (bufferline-test--show left a)
     (bufferline-test--drag (bufferline-test--tab-posn right d)
                            (bufferline-test--tab-posn right c))
     (should (equal (bufferline-test--tabs right) (list d c)))
     (should (eq (selected-window) left))
     (should (eq (window-buffer right) d)))))

(ert-deftest bufferline-test-drag-across-pinned ()
  (bufferline-test-with-frame
   (let* ((win (selected-window))
          (a (bufferline-test--buffer "a"))
          (b (bufferline-test--buffer "b"))
          (c (bufferline-test--buffer "c")))
     (bufferline-test--show win a b c)
     (bufferline-state-toggle-pin a)
     (should-error (bufferline-test--drag (bufferline-test--tab-posn win c)
                                          (bufferline-test--tab-posn win a))
                   :type 'user-error)
     (should (equal (bufferline-test--tabs win) (list a b c))))))

(ert-deftest bufferline-test-drag-needs-fifo ()
  (bufferline-test-with-frame
   (let* ((win (selected-window))
          (a (bufferline-test--buffer "a"))
          (b (bufferline-test--buffer "b"))
          (bufferline-sort-by 'name))
     (bufferline-test--show win b a)
     (should-error (bufferline-test--drag (bufferline-test--tab-posn win a)
                                          (bufferline-test--tab-posn win b))
                   :type 'user-error)
     (should (equal (bufferline-test--tabs win) (list a b))))))

;;; New tab button

(defun bufferline-test--new-tab-start (string)
  "Return the index where the new tab button starts in STRING, or nil."
  (seq-position (number-sequence 0 (1- (length string)))
                nil
                (lambda (i _) (equal (get-text-property i 'help-echo string) "New tab"))))

(defun bufferline-test--click-new-tab (window buffer)
  "Click the new tab button drawn after BUFFER's tab in WINDOW's tab line."
  (let* ((string (bufferline-test--render window buffer))
         (index (bufferline-test--new-tab-start string)))
    (bufferline-new-tab-at-click
     (list 'mouse-1 (list window 'tab-line '(0 . 0) 0 (cons string index)
                          nil '(0 . 0) nil '(0 . 0) '(0 . 0))))))

(defun bufferline-test--new-buffers (thunk)
  "Call THUNK and return the buffers it created, killed when the test ends."
  (let* ((before (buffer-list))
         (_ (funcall thunk))
         (created (seq-difference (buffer-list) before)))
    (dolist (buf created)
      (push buf bufferline-test--buffers))
    created))

(ert-deftest bufferline-test-new-tab-button-off-by-default ()
  (should-not (default-value 'bufferline-show-new-tab-button))
  (bufferline-test-with-frame
   (let ((a (bufferline-test--buffer "a")))
     (bufferline-test--show (selected-window) a)
     (let ((string (bufferline-test--render (selected-window) a)))
       (should-not (bufferline-test--new-tab-start string))
       (should-not (string-search bufferline-new-tab-icon string))))))

(ert-deftest bufferline-test-new-tab-button-after-last-tab ()
  (bufferline-test-with-frame
   (let ((a (bufferline-test--buffer "a"))
         (b (bufferline-test--buffer "b"))
         (bufferline-show-new-tab-button t))
     (bufferline-test--show (selected-window) a b a)
     (should-not (bufferline-test--new-tab-start
                  (bufferline-test--render (selected-window) a)))
     (let ((string (bufferline-test--render (selected-window) b)))
       (should (string-suffix-p (concat " " bufferline-new-tab-icon " ")
                                (substring-no-properties string)))
       (should (= (bufferline-test--new-tab-start string)
                  (- (length string) 1 (length bufferline-new-tab-icon))))))))

(ert-deftest bufferline-test-new-tab-button-properties ()
  (bufferline-test-with-frame
   (let* ((a (bufferline-test--buffer "a"))
          (bufferline-show-new-tab-button t)
          (bufferline-new-tab-hover-face 'bufferline-test-pick)
          (_ (bufferline-test--show (selected-window) a))
          (string (bufferline-test--render (selected-window) a))
          (start (bufferline-test--new-tab-start string)))
     (should (eq (lookup-key (get-text-property start 'keymap string) [tab-line mouse-1])
                 #'bufferline-new-tab-at-click))
     (should (equal (plist-get (get-text-property start 'mouse-face string) :foreground)
                    "#ff0000"))
     ;; the button is not part of the tab, so it is not dragged or closed
     (should-not (get-text-property start 'tab string))
     (should-not (get-text-property (1- start) 'tab string)))))

(ert-deftest bufferline-test-new-tab-button-custom-icon ()
  (bufferline-test-with-frame
   (let ((a (bufferline-test--buffer "a"))
         (bufferline-show-new-tab-button t)
         (bufferline-new-tab-icon "[+]"))
     (bufferline-test--show (selected-window) a)
     (let* ((string (bufferline-test--render (selected-window) a))
            (start (bufferline-test--new-tab-start string)))
       (should (equal (substring-no-properties string start) "[+] "))
       (should-not (get-text-property (+ start 3) 'help-echo string))))))

(ert-deftest bufferline-test-new-tab-button-after-trunc-marker ()
  (bufferline-test-with-frame
   (let ((bufferline-show-new-tab-button t)
         (bufferline-show-trunc-markers t)
         (bufferline-right-trunc-marker ">")
         (bufferline-new-tab-icon "+")
         (bufs (mapcar (lambda (i) (bufferline-test--buffer (format "tab%02d" i)))
                       (number-sequence 1 30))))
     (apply #'bufferline-test--show (selected-window) bufs)
     (bufferline-test--show (selected-window) (car bufs))
     (with-selected-window (selected-window)
       (let ((visible (bufferline-buffers-get)))
         (should (> bufferline-buffers--right-count 0))
         (should (string-suffix-p
                  (format "> %d  + " bufferline-buffers--right-count)
                  (substring-no-properties
                   (bufferline-ui-tab-name-format (car (last visible)) visible)))))))))

(ert-deftest bufferline-test-new-tab-button-width ()
  (let ((bufferline-new-tab-icon "[+]"))
    (let ((bufferline-show-new-tab-button nil))
      (should (= (bufferline-buffers-tail-width nil) 0)))
    (let ((bufferline-show-new-tab-button t))
      (should (= (bufferline-buffers-tail-width nil) 5)))))

(ert-deftest bufferline-test-new-tab-button-makes-room ()
  (bufferline-test-with-frame
   (let ((bufferline-show-trunc-markers t)
         (bufferline-new-tab-icon "[new tab]")
         (bufs (mapcar (lambda (i) (bufferline-test--buffer (format "%c" i)))
                       (number-sequence ?a ?t))))
     (apply #'bufferline-test--show (selected-window) bufs)
     (cl-letf (((symbol-function 'window-width) (lambda (&rest _) 60)))
       (let ((without (let ((bufferline-show-new-tab-button nil))
                        (length (bufferline-buffers-get))))
             (with (let ((bufferline-show-new-tab-button t))
                     (length (bufferline-buffers-get)))))
         (should (< with without))
         (should (> with 0)))))))

(ert-deftest bufferline-test-new-tab-command ()
  (bufferline-test-with-frame
   (let ((a (bufferline-test--buffer "a")))
     (bufferline-test--show (selected-window) a)
     (let ((first (car (bufferline-test--new-buffers #'bufferline-new-tab)))
           (second (car (bufferline-test--new-buffers #'bufferline-new-tab))))
       (should (string-prefix-p "untitled" (buffer-name first)))
       (should (string-prefix-p "untitled" (buffer-name second)))
       (should-not (equal (buffer-name first) (buffer-name second)))
       (should (eq (window-buffer) second))
       (should (equal (bufferline-test--tabs (selected-window)) (list a first second)))))))

(ert-deftest bufferline-test-new-tab-click-default ()
  (bufferline-test-with-frame
   (let ((a (bufferline-test--buffer "a"))
         (bufferline-show-new-tab-button t))
     (bufferline-test--show (selected-window) a)
     (let ((created (bufferline-test--new-buffers
                     (lambda () (bufferline-test--click-new-tab (selected-window) a)))))
       (should (= (length created) 1))
       (should (eq (window-buffer) (car created)))))))

(ert-deftest bufferline-test-new-tab-click-other-window ()
  (bufferline-test-with-frame
   (let* ((left (selected-window))
          (right (split-window-right))
          (a (bufferline-test--buffer "a"))
          (c (bufferline-test--buffer "c"))
          (bufferline-show-new-tab-button t)
          (called-in nil)
          (bufferline-new-tab-function (lambda () (setq called-in (selected-window)))))
     (bufferline-test--show right c)
     (bufferline-test--show left a)
     (bufferline-test--click-new-tab right c)
     (should (eq called-in right))
     (should (eq (selected-window) right)))))

(ert-deftest bufferline-test-new-tab-click-calls-command-interactively ()
  (bufferline-test-with-frame
   (let* ((a (bufferline-test--buffer "a"))
          (bufferline-show-new-tab-button t)
          (args nil)
          (bufferline-new-tab-function (lambda (arg)
                                         (interactive (list 'asked))
                                         (setq args (list arg)))))
     (bufferline-test--show (selected-window) a)
     (bufferline-test--click-new-tab (selected-window) a)
     (should (equal args '(asked))))))

;;; Tab counter

(defun bufferline-test--count-start (string)
  "Return the index where the tab counter starts in STRING, or nil."
  (seq-position (number-sequence 0 (1- (length string)))
                nil
                (lambda (i _) (equal (get-text-property i 'help-echo string)
                                     "Current tab and tab count"))))

(ert-deftest bufferline-test-tab-count-off-by-default ()
  (should-not (default-value 'bufferline-show-tab-count))
  (bufferline-test-with-frame
   (let ((a (bufferline-test--buffer "a")))
     (bufferline-test--show (selected-window) a)
     (should-not (bufferline-test--count-start
                  (bufferline-test--render (selected-window) a))))))

(ert-deftest bufferline-test-tab-count-after-last-tab ()
  (bufferline-test-with-frame
   (let ((a (bufferline-test--buffer "a"))
         (b (bufferline-test--buffer "b"))
         (c (bufferline-test--buffer "c"))
         (bufferline-show-tab-count t))
     (bufferline-test--show (selected-window) a b c b)
     (should-not (bufferline-test--count-start
                  (bufferline-test--render (selected-window) a)))
     (let* ((string (bufferline-test--render (selected-window) c))
            (start (bufferline-test--count-start string)))
       (should (string-suffix-p " 2/3 " (substring-no-properties string)))
       (should (= start (- (length string) 5)))
       ;; the counter is not part of the tab
       (should-not (get-text-property start 'tab string))))))

(ert-deftest bufferline-test-tab-count-custom-format ()
  (bufferline-test-with-frame
   (let ((a (bufferline-test--buffer "a"))
         (b (bufferline-test--buffer "b"))
         (bufferline-show-tab-count t)
         (bufferline-tab-count-format "[%d of %d]"))
     (bufferline-test--show (selected-window) a b)
     (should (string-suffix-p " [2 of 2] "
                              (substring-no-properties
                               (bufferline-test--render (selected-window) b)))))))

(ert-deftest bufferline-test-tab-count-without-current-tab ()
  (bufferline-test-with-frame
   (let ((a (bufferline-test--buffer "a"))
         (b (bufferline-test--buffer "b")))
     (should (equal (bufferline-buffers-tab-count (list a b)) "0/2")))))

(ert-deftest bufferline-test-tab-count-includes-hidden-tabs ()
  (bufferline-test-with-frame
   (let ((bufferline-show-tab-count t)
         (bufferline-show-new-tab-button t)
         (bufferline-show-trunc-markers t)
         (bufferline-right-trunc-marker ">")
         (bufferline-new-tab-icon "+")
         (bufs (mapcar (lambda (i) (bufferline-test--buffer (format "tab%02d" i)))
                       (number-sequence 1 30))))
     (apply #'bufferline-test--show (selected-window) bufs)
     (bufferline-test--show (selected-window) (nth 1 bufs))
     (with-selected-window (selected-window)
       (let ((visible (bufferline-buffers-get)))
         (should (> bufferline-buffers--right-count 0))
         ;; right marker, then the counter, then the new tab button
         (should (string-suffix-p
                  (format "> %d  2/30  + " bufferline-buffers--right-count)
                  (substring-no-properties
                   (bufferline-ui-tab-name-format (car (last visible)) visible)))))))))

(ert-deftest bufferline-test-tab-count-width ()
  (bufferline-test-with-frame
   (let ((a (bufferline-test--buffer "a"))
         (b (bufferline-test--buffer "b"))
         (bufferline-tab-count-format "%d/%d"))
     (bufferline-test--show (selected-window) a b)
     (let ((tabs (bufferline-test--tabs (selected-window))))
       (let ((bufferline-show-tab-count nil))
         (should (= (bufferline-buffers-tail-width tabs) 0)))
       (let ((bufferline-show-tab-count t))
         (should (= (bufferline-buffers-tail-width tabs) 5)))
       (let ((bufferline-show-tab-count t)
             (bufferline-show-new-tab-button t)
             (bufferline-new-tab-icon "+"))
         (should (= (bufferline-buffers-tail-width tabs) 8)))))))

(ert-deftest bufferline-test-tab-count-makes-room ()
  (bufferline-test-with-frame
   (let ((bufferline-show-trunc-markers t)
         (bufferline-tab-count-format "tab %d out of %d")
         (bufs (mapcar (lambda (i) (bufferline-test--buffer (format "%c" i)))
                       (number-sequence ?a ?t))))
     (apply #'bufferline-test--show (selected-window) bufs)
     (cl-letf (((symbol-function 'window-width) (lambda (&rest _) 60)))
       (let ((without (let ((bufferline-show-tab-count nil))
                        (length (bufferline-buffers-get))))
             (with (let ((bufferline-show-tab-count t))
                     (length (bufferline-buffers-get)))))
         (should (< with without))
         (should (> with 0)))))))

;;; Navigation buttons

(defun bufferline-test--help-start (string help)
  "Return the index of the first character of STRING whose help is HELP."
  (seq-position (number-sequence 0 (1- (length string)))
                nil
                (lambda (i _) (equal (get-text-property i 'help-echo string) help))))

(defun bufferline-test--click-nav (window buffer help)
  "Click the navigation button with help text HELP after BUFFER's tab.
The tab is drawn by WINDOW's tab line."
  (let* ((string (bufferline-test--render window buffer))
         (index (bufferline-test--help-start string help))
         (command (lookup-key (get-text-property index 'keymap string)
                              [tab-line mouse-1])))
    (funcall command
             (list 'mouse-1 (list window 'tab-line '(0 . 0) 0 (cons string index)
                                  nil '(0 . 0) nil '(0 . 0) '(0 . 0))))))

(ert-deftest bufferline-test-navigation-off-by-default ()
  (should-not (default-value 'bufferline-show-navigation-buttons))
  (bufferline-test-with-frame
   (let ((a (bufferline-test--buffer "a")))
     (bufferline-test--show (selected-window) a)
     (let ((string (bufferline-test--render (selected-window) a)))
       (should-not (bufferline-test--help-start string "Previous tab"))
       (should-not (bufferline-test--help-start string "Next tab"))))))

(ert-deftest bufferline-test-navigation-after-last-tab ()
  (bufferline-test-with-frame
   (let ((a (bufferline-test--buffer "a"))
         (b (bufferline-test--buffer "b"))
         (bufferline-show-navigation-buttons t)
         (bufferline-prev-tab-icon "<")
         (bufferline-next-tab-icon ">"))
     (bufferline-test--show (selected-window) a b)
     (should-not (bufferline-test--help-start
                  (bufferline-test--render (selected-window) a) "Previous tab"))
     (let ((string (bufferline-test--render (selected-window) b)))
       (should (string-suffix-p " < > " (substring-no-properties string)))
       (should (= (bufferline-test--help-start string "Previous tab")
                  (- (length string) 4)))
       (should (= (bufferline-test--help-start string "Next tab")
                  (- (length string) 2)))))))

(ert-deftest bufferline-test-navigation-properties ()
  (bufferline-test-with-frame
   (let* ((a (bufferline-test--buffer "a"))
          (bufferline-show-navigation-buttons t)
          (bufferline-navigation-hover-face 'bufferline-test-pick)
          (_ (bufferline-test--show (selected-window) a))
          (string (bufferline-test--render (selected-window) a)))
     (pcase-dolist (`(,help . ,command)
                    '(("Previous tab" . bufferline-prev-tab-at-click)
                      ("Next tab" . bufferline-next-tab-at-click)))
       (let ((start (bufferline-test--help-start string help)))
         (should (eq (lookup-key (get-text-property start 'keymap string)
                                 [tab-line mouse-1])
                     command))
         (should (equal (plist-get (get-text-property start 'mouse-face string)
                                   :foreground)
                        "#ff0000"))
         (should-not (get-text-property start 'tab string))
         ;; the spaces around the buttons do not react to the mouse
         (should-not (get-text-property (1- start) 'mouse-face string))
         (should-not (get-text-property (1+ start) 'keymap string)))))))

(ert-deftest bufferline-test-navigation-order ()
  (bufferline-test-with-frame
   (let ((bufferline-show-navigation-buttons t)
         (bufferline-show-tab-count t)
         (bufferline-show-new-tab-button t)
         (bufferline-show-trunc-markers t)
         (bufferline-right-trunc-marker ">")
         (bufferline-prev-tab-icon "{")
         (bufferline-next-tab-icon "}")
         (bufferline-new-tab-icon "+")
         (bufs (mapcar (lambda (i) (bufferline-test--buffer (format "tab%02d" i)))
                       (number-sequence 1 30))))
     (apply #'bufferline-test--show (selected-window) bufs)
     (bufferline-test--show (selected-window) (car bufs))
     (with-selected-window (selected-window)
       (let ((visible (bufferline-buffers-get)))
         (should (> bufferline-buffers--right-count 0))
         ;; right marker, navigation, counter, new tab button
         (should (string-suffix-p
                  (format "> %d  { }  1/30  + " bufferline-buffers--right-count)
                  (substring-no-properties
                   (bufferline-ui-tab-name-format (car (last visible)) visible)))))))))

(ert-deftest bufferline-test-navigation-click-cycles ()
  (bufferline-test-with-frame
   (let ((a (bufferline-test--buffer "a"))
         (b (bufferline-test--buffer "b"))
         (c (bufferline-test--buffer "c"))
         (bufferline-show-navigation-buttons t))
     (bufferline-test--show (selected-window) a b c)
     (bufferline-test--click-nav (selected-window) c "Next tab")
     (should (eq (window-buffer) a))
     (bufferline-test--click-nav (selected-window) c "Previous tab")
     (should (eq (window-buffer) c))
     (bufferline-test--click-nav (selected-window) c "Previous tab")
     (should (eq (window-buffer) b)))))

(ert-deftest bufferline-test-navigation-click-other-window ()
  (bufferline-test-with-frame
   (let* ((left (selected-window))
          (right (split-window-right))
          (a (bufferline-test--buffer "a"))
          (c (bufferline-test--buffer "c"))
          (d (bufferline-test--buffer "d"))
          (bufferline-show-navigation-buttons t))
     (bufferline-test--show right c d)
     (bufferline-test--show left a)
     (bufferline-test--click-nav right d "Previous tab")
     ;; the clicked window switches, the selection stays where it was
     (should (eq (window-buffer right) c))
     (should (eq (window-buffer left) a))
     (should (eq (selected-window) left)))))

(ert-deftest bufferline-test-navigation-width ()
  (let ((bufferline-prev-tab-icon "<<")
        (bufferline-next-tab-icon ">"))
    (let ((bufferline-show-navigation-buttons nil))
      (should (= (bufferline-buffers-tail-width nil) 0)))
    (let ((bufferline-show-navigation-buttons t))
      (should (= (bufferline-buffers-tail-width nil) 6)))))

;;; Evil integration

(defvar evil-ex-argument)
(defvar evil-ex-commands)
(defvar evil-motion-state-map)

(defmacro bufferline-test-with-evil (&rest body)
  "Run BODY with Evil loaded, skipping the test when it is missing.
`bufferline-evil-mode' is turned off again once BODY has run."
  (declare (indent 0) (debug t))
  `(progn
     (skip-unless (require 'evil nil t))
     (unwind-protect
         (progn ,@body)
       (bufferline-evil-mode -1))))

(defun bufferline-test--ex (command &optional argument)
  "Call Ex COMMAND as Evil does for :COMMAND ARGUMENT."
  (let ((evil-ex-argument argument)
        (current-prefix-arg nil))
    (call-interactively (cdr (assoc command evil-ex-commands)))))

(ert-deftest bufferline-test-evil-off-by-default ()
  (should-not (default-value 'bufferline-evil-mode)))

(ert-deftest bufferline-test-evil-keys ()
  (bufferline-test-with-evil
   (let ((gt (lookup-key evil-motion-state-map "gt"))
         (gT (lookup-key evil-motion-state-map "gT")))
     (bufferline-evil-mode 1)
     (should (eq (lookup-key evil-motion-state-map "gt") #'bufferline-evil-tab-next))
     (should (eq (lookup-key evil-motion-state-map "gT") #'bufferline-evil-tab-previous))
     (bufferline-evil-mode -1)
     (should (eq (lookup-key evil-motion-state-map "gt") gt))
     (should (eq (lookup-key evil-motion-state-map "gT") gT)))))

(ert-deftest bufferline-test-evil-ex-commands ()
  (bufferline-test-with-evil
   (let ((before (copy-tree evil-ex-commands)))
     (bufferline-evil-mode 1)
     (pcase-dolist (`(,name . ,command)
                    '(("tabn" . bufferline-evil-tab-next)
                      ("tabnext" . bufferline-evil-tab-next)
                      ("tabp" . bufferline-evil-tab-previous)
                      ("tabprevious" . bufferline-evil-tab-previous)
                      ("tabN" . bufferline-evil-tab-previous)
                      ("tabfir" . bufferline-evil-tab-first)
                      ("tabr" . bufferline-evil-tab-first)
                      ("tabl" . bufferline-evil-tab-last)
                      ("tablast" . bufferline-evil-tab-last)
                      ("tabc" . bufferline-evil-tab-close)
                      ("tabo" . bufferline-evil-tab-only)
                      ("tabm" . bufferline-evil-tab-move)
                      ("tabmove" . bufferline-evil-tab-move)
                      ("tabnew" . bufferline-evil-tab-new)
                      ("tabe" . bufferline-evil-tab-new)
                      ("tabedit" . bufferline-evil-tab-new)))
       (should (eq (cdr (assoc name evil-ex-commands)) command)))
     (bufferline-evil-mode -1)
     ;; the commands Evil had come back, the ones it lacked go away
     (should (equal (sort (copy-sequence evil-ex-commands)
                          (lambda (a b) (string< (car a) (car b))))
                    (sort before (lambda (a b) (string< (car a) (car b)))))))))

(ert-deftest bufferline-test-evil-enable-twice ()
  (bufferline-test-with-evil
   (let ((gt (lookup-key evil-motion-state-map "gt"))
         (tabn (assoc "tabn" evil-ex-commands)))
     (bufferline-evil-mode 1)
     (bufferline-evil-mode 1)
     (bufferline-evil-mode -1)
     (should (eq (lookup-key evil-motion-state-map "gt") gt))
     (should (equal (assoc "tabn" evil-ex-commands) tabn)))))

(ert-deftest bufferline-test-evil-disable-keeps-later-bindings ()
  (bufferline-test-with-evil
   (let ((gt (lookup-key evil-motion-state-map "gt"))
         (tabc (cdr (assoc "tabc" evil-ex-commands))))
     (unwind-protect
         (progn
           (bufferline-evil-mode 1)
           (define-key evil-motion-state-map "gt" #'ignore)
           (evil-ex-define-cmd "tabc" #'ignore)
           (bufferline-evil-mode -1)
           (should (eq (lookup-key evil-motion-state-map "gt") #'ignore))
           (should (eq (cdr (assoc "tabc" evil-ex-commands)) #'ignore)))
       (define-key evil-motion-state-map "gt" gt)
       (if tabc
           (evil-ex-define-cmd "tabc" tabc)
         (setq evil-ex-commands (assoc-delete-all "tabc" evil-ex-commands)))))))

(defvar evil-window-map)

(ert-deftest bufferline-test-evil-window-move-key ()
  (bufferline-test-with-evil
   (let ((m (lookup-key evil-window-map "m")))
     (bufferline-evil-mode 1)
     (should (eq (lookup-key evil-window-map "m") #'bufferline-move-tab-to-window))
     ;; reached as C-w m from the motion state
     (should (eq (lookup-key evil-motion-state-map (kbd "C-w m"))
                 #'bufferline-move-tab-to-window))
     (bufferline-evil-mode -1)
     (should (eq (lookup-key evil-window-map "m") m)))))

(ert-deftest bufferline-test-evil-window-move-key-enable-twice ()
  (bufferline-test-with-evil
   (let ((m (lookup-key evil-window-map "m")))
     (bufferline-evil-mode 1)
     (bufferline-evil-mode 1)
     (bufferline-evil-mode -1)
     (should (eq (lookup-key evil-window-map "m") m)))))

(ert-deftest bufferline-test-evil-window-move-key-keeps-later-binding ()
  (bufferline-test-with-evil
   (let ((m (lookup-key evil-window-map "m")))
     (unwind-protect
         (progn
           (bufferline-evil-mode 1)
           (define-key evil-window-map "m" #'ignore)
           (bufferline-evil-mode -1)
           (should (eq (lookup-key evil-window-map "m") #'ignore)))
       (define-key evil-window-map "m" m)))))

(ert-deftest bufferline-test-evil-window-move-key-moves-tab ()
  (bufferline-test-with-evil
   (bufferline-test-with-frame
    (let* ((left (selected-window))
           (right (split-window-right))
           (a (bufferline-test--buffer "a"))
           (b (bufferline-test--buffer "b"))
           (c (bufferline-test--buffer "c"))
           (bufferline-move-tab-split-keys nil))
      (bufferline-test--show right c)
      (bufferline-test--show left b a)
      (bufferline-evil-mode 1)
      (let ((current-prefix-arg nil))
        (call-interactively (lookup-key evil-window-map "m")))
      (should (eq (selected-window) right))
      (should (equal (bufferline-test--tabs right) (list c a)))))))

(ert-deftest bufferline-test-evil-without-evil ()
  (cl-letf* ((require-orig (symbol-function 'require))
             ((symbol-function 'require)
              (lambda (feature &rest args)
                (unless (eq feature 'evil)
                  (apply require-orig feature args)))))
    (should-error (bufferline-evil-mode 1) :type 'user-error)
    (should-not bufferline-evil-mode)))

(ert-deftest bufferline-test-evil-tab-next ()
  (bufferline-test-with-evil
   (bufferline-test-with-frame
    (let ((a (bufferline-test--buffer "a"))
          (b (bufferline-test--buffer "b"))
          (c (bufferline-test--buffer "c")))
      (bufferline-test--show (selected-window) a b c a)
      ;; gt goes to the next tab, with a count to that tab
      (bufferline-evil-tab-next)
      (should (eq (window-buffer) b))
      (bufferline-evil-tab-next 3)
      (should (eq (window-buffer) c))
      (bufferline-evil-tab-next '(1))
      (should (eq (window-buffer) a))
      (bufferline-evil-tab-next)
      (bufferline-evil-tab-next)
      (bufferline-evil-tab-next)
      (should (eq (window-buffer) a))
      (should-error (bufferline-evil-tab-next 4) :type 'user-error)))))

(ert-deftest bufferline-test-evil-tab-previous ()
  (bufferline-test-with-evil
   (bufferline-test-with-frame
    (let ((a (bufferline-test--buffer "a"))
          (b (bufferline-test--buffer "b"))
          (c (bufferline-test--buffer "c")))
      (bufferline-test--show (selected-window) a b c)
      (bufferline-evil-tab-previous)
      (should (eq (window-buffer) b))
      ;; a count goes that many tabs back, wrapping around
      (bufferline-evil-tab-previous 2)
      (should (eq (window-buffer) c))))))

(ert-deftest bufferline-test-evil-ex-tab-next ()
  (bufferline-test-with-evil
   (bufferline-test-with-frame
    (let ((a (bufferline-test--buffer "a"))
          (b (bufferline-test--buffer "b"))
          (c (bufferline-test--buffer "c")))
      (bufferline-test--show (selected-window) a b c a)
      (bufferline-evil-mode 1)
      (bufferline-test--ex "tabnext" "3")
      (should (eq (window-buffer) c))
      (bufferline-test--ex "tabn")
      (should (eq (window-buffer) a))
      (bufferline-test--ex "tabp" "2")
      (should (eq (window-buffer) b))
      (bufferline-test--ex "tablast")
      (should (eq (window-buffer) c))
      (bufferline-test--ex "tabfirst")
      (should (eq (window-buffer) a))
      (bufferline-test--ex "tabr")
      (should (eq (window-buffer) a))))))

(ert-deftest bufferline-test-evil-ex-tab-close ()
  (bufferline-test-with-evil
   (bufferline-test-with-frame
    (let ((a (bufferline-test--buffer "a"))
          (b (bufferline-test--buffer "b"))
          (c (bufferline-test--buffer "c")))
      (bufferline-test--show (selected-window) a b c)
      (bufferline-evil-mode 1)
      (bufferline-test--ex "tabclose")
      (should-not (buffer-live-p c))
      (should (equal (bufferline-test--tabs (selected-window)) (list a b)))))))

(ert-deftest bufferline-test-evil-ex-tab-only ()
  (bufferline-test-with-evil
   (bufferline-test-with-frame
    (let ((a (bufferline-test--buffer "a"))
          (b (bufferline-test--buffer "b"))
          (c (bufferline-test--buffer "c"))
          (bufferline-close-keep-pinned t))
      (bufferline-test--show (selected-window) a b c)
      (bufferline-state-toggle-pin a)
      (bufferline-evil-mode 1)
      (bufferline-test--ex "tabo")
      (should-not (buffer-live-p b))
      (should (equal (bufferline-test--tabs (selected-window)) (list a c)))))))

(ert-deftest bufferline-test-evil-move-index ()
  ;; four tabs, the moved one at POS
  (let ((tabs '(t1 t2 t3 t4)))
    (pcase-dolist (`(,arg ,pos ,index)
                   '((nil 0 3) ("$" 1 3) ("0" 2 0)
                     ("2" 0 1) ("2" 3 2) ("2" 1 1) ("9" 0 3)
                     ("+1" 1 2) ("+" 1 2) ("+5" 1 3)
                     ("-1" 2 1) ("-" 2 1) ("-5" 2 0)))
      (should (= (bufferline-evil--move-index arg pos tabs) index)))
    (should-error (bufferline-evil--move-index "x" 0 tabs) :type 'user-error)))

(ert-deftest bufferline-test-evil-ex-tab-move ()
  (bufferline-test-with-evil
   (bufferline-test-with-frame
    (let ((a (bufferline-test--buffer "a"))
          (b (bufferline-test--buffer "b"))
          (c (bufferline-test--buffer "c"))
          (d (bufferline-test--buffer "d")))
      (bufferline-test--show (selected-window) a b c d a)
      (bufferline-evil-mode 1)
      (bufferline-test--ex "tabmove")
      (should (equal (bufferline-test--tabs (selected-window)) (list b c d a)))
      (bufferline-test--ex "tabm" "0")
      (should (equal (bufferline-test--tabs (selected-window)) (list a b c d)))
      (bufferline-test--ex "tabm" "2")
      (should (equal (bufferline-test--tabs (selected-window)) (list b a c d)))
      (bufferline-test--ex "tabm" "+2")
      (should (equal (bufferline-test--tabs (selected-window)) (list b c d a)))
      (bufferline-test--ex "tabm" "-1")
      (should (equal (bufferline-test--tabs (selected-window)) (list b c a d)))
      ;; moving onto its own place changes nothing
      (bufferline-test--ex "tabm" "3")
      (should (equal (bufferline-test--tabs (selected-window)) (list b c a d)))
      (should (eq (window-buffer) a))))))

(ert-deftest bufferline-test-evil-ex-tab-move-across-pinned ()
  (bufferline-test-with-evil
   (bufferline-test-with-frame
    (let ((a (bufferline-test--buffer "a"))
          (b (bufferline-test--buffer "b")))
      (bufferline-test--show (selected-window) a b)
      (bufferline-state-toggle-pin a)
      (bufferline-evil-mode 1)
      (should-error (bufferline-test--ex "tabm" "0") :type 'user-error)
      (should (equal (bufferline-test--tabs (selected-window)) (list a b)))))))

(ert-deftest bufferline-test-evil-ex-tab-new ()
  (bufferline-test-with-evil
   (bufferline-test-with-frame
    (let ((a (bufferline-test--buffer "a")))
      (bufferline-test--show (selected-window) a)
      (bufferline-evil-mode 1)
      (let ((created (bufferline-test--new-buffers
                      (lambda () (bufferline-test--ex "tabnew")))))
        (should (= (length created) 1))
        (should (string-prefix-p "untitled" (buffer-name (car created))))
        (should (eq (window-buffer) (car created))))))))

(ert-deftest bufferline-test-evil-ex-tab-edit-file ()
  (bufferline-test-with-evil
   (bufferline-test-with-frame
    (let ((a (bufferline-test--buffer "a"))
          (file (make-temp-file "bufferline-test-")))
      (unwind-protect
          (progn
            (bufferline-test--show (selected-window) a)
            (bufferline-evil-mode 1)
            (let ((created (bufferline-test--new-buffers
                            (lambda () (bufferline-test--ex "tabe" file)))))
              (should (= (length created) 1))
              (should (equal (buffer-file-name (car created)) file))
              (should (eq (window-buffer) (car created)))))
        (delete-file file))))))

(provide 'bufferline-test)

;;; bufferline-test.el ends here
