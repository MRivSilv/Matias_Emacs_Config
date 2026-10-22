;;; funcs.el --- Personal interactive commands -*- lexical-binding: t; -*-

(defun my/insert-backtick ()
  "Insert a backtick at point."
  (interactive)
  (insert "`"))

(defun my/insert-tilde ()
  "Insert a tilde at point."
  (interactive)
  (insert "~"))

(defun my/insert-less-than ()
  "Insert a less-than sign at point."
  (interactive)
  (insert "<"))

(defun my/insert-greater-than ()
  "Insert a greater-than sign at point."
  (interactive)
  (insert ">"))

(defun my/insert-backslash ()
  "Insert a backslash since idk Im not allowed."
  (interactive)
  (insert "\\"))

(provide 'funcs)
