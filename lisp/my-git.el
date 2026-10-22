;;; my-git.el --- Git commands for the editor -*- lexical-binding: t; -*-

(require 'diff-mode)
(require 'seq)
(require 'subr-x)
(require 'vc)

(defun git-checkout ()
  "Switch to a local or remote Git branch without leaving Emacs."
  (interactive)
  (let ((root (vc-root-dir 'Git)))
    (unless root
      (user-error "Not in a Git project"))
    (let ((default-directory root)
          (branch-buffer (generate-new-buffer " *git branches*"))
          (output-buffer (get-buffer-create "*git checkout*")))
      (unwind-protect
          (let ((status (process-file
                         "git" nil branch-buffer nil "branch"
                         "--format=%(refname:short)")))
            (unless (and (integerp status) (zerop status))
              (user-error "Could not list local Git branches: %s"
                          (with-current-buffer branch-buffer
                            (string-trim (buffer-string)))))
            (let ((local-branches
                   (with-current-buffer branch-buffer
                     (split-string (buffer-string) "\n" t))))
              (with-current-buffer branch-buffer
                (erase-buffer))
              (let ((status (process-file
                             "git" nil branch-buffer nil "branch" "--remotes"
                             "--format=%(refname:short)")))
                (unless (and (integerp status) (zerop status))
                  (user-error "Could not list remote Git branches: %s"
                              (with-current-buffer branch-buffer
                                (string-trim (buffer-string))))))
              (let* ((remote-branches
                      (with-current-buffer branch-buffer
                        (seq-filter
                         (lambda (branch)
                           (not (string-match-p "/HEAD\\'" branch)))
                         (split-string (buffer-string) "\n" t))))
                     (branches (append local-branches remote-branches))
                     (branch (completing-read "Switch to branch: "
                                              branches nil t)))
                (with-current-buffer output-buffer
                  (let ((inhibit-read-only t))
                    (erase-buffer)))
                (let* ((remote-branch (member branch remote-branches))
                       (status (if remote-branch
                                   (process-file "git" nil output-buffer nil
                                                 "switch" "--track" branch)
                                 (process-file "git" nil output-buffer nil
                                               "switch" branch))))
                  (unless (and (integerp status) (zerop status))
                    (user-error "Could not switch to %s: %s"
                                branch
                                (with-current-buffer output-buffer
                                  (string-trim (buffer-string))))))
                (message "Switched to branch %s" branch))))
        (kill-buffer branch-buffer)))))

(defun git-status ()
  "Show the current project's Git status in a new frame."
  (interactive)
  (let ((root (vc-root-dir)))
    (unless root
      (user-error "Not in a version-controlled project"))
    (select-frame (make-frame))
    (vc-dir root)))

(defun git-diff ()
  "Show the current project's unstaged Git diff in a new frame."
  (interactive)
  (let ((root (vc-root-dir 'Git))
        (buffer (get-buffer-create "*git diff*")))
    (unless root
      (user-error "Not in a Git project"))
    (unless (file-directory-p root)
      (user-error "Git project directory does not exist: %s" root))
    (setq root (file-name-as-directory (file-truename root)))
    (with-current-buffer buffer
      (let ((inhibit-read-only t))
        (erase-buffer)
        (let* ((default-directory root)
               (status (process-file "git" nil (list buffer t) nil "diff")))
          (unless (and (integerp status) (zerop status))
            (user-error "git diff failed with status %s: %s"
                        status (buffer-string))))
        (diff-mode)))
    (select-frame (make-frame))
    (pop-to-buffer buffer)))

(provide 'my-git)
