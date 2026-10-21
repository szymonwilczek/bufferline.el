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

(defmacro bufferline-test-with-frame (&rest body)
  "Run BODY in a single-window frame with fresh tab state."
  (declare (indent 0) (debug t))
  `(let ((bufferline-state--tab-order-counter 0)
         (bufferline-sort-by 'fifo)
         (bufferline-test--buffers nil))
     (save-window-excursion
       (delete-other-windows)
       (switch-to-buffer (get-buffer-create " *bufferline-test-blank*"))
       (set-window-prev-buffers nil nil)
       (set-window-next-buffers nil nil)
       (unwind-protect
           (progn ,@body)
         (mapc #'kill-buffer bufferline-test--buffers)))))

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

(ert-deftest bufferline-test-move-last-tab-to-window ()
  (bufferline-test-with-frame
   (let* ((left (selected-window))
          (right (split-window-right))
          (a (bufferline-test--buffer "a"))
          (c (bufferline-test--buffer "c")))
     (bufferline-test--show right c)
     (bufferline-test--show left a)
     (should-error (bufferline-move-tab-to-window-right) :type 'user-error)
     (should (eq (window-buffer left) a)))))

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
