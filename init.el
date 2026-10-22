;; -*- lexical-binding: t; -*-

;;; Startup

(global-auto-revert-mode 1)

;;; Editor defaults

(setq desktop-restore-frames t
      make-backup-files nil
      default-tab-width 2)

(setq display-line-numbers-type 'relative)
(dolist (hook '(prog-mode-hook text-mode-hook conf-mode-hook))
  (add-hook hook #'display-line-numbers-mode))

(add-to-list 'auto-mode-alist '("\\.\\(?:md\\|markdown\\)\\'" . text-mode))

;; Set the default text size to 12 pt (120 = 12 pt in Emacs).
;;; Packages and local libraries

(add-to-list 'load-path (expand-file-name "evil" user-emacs-directory))
(require 'evil)

(add-to-list 'load-path (expand-file-name "lisp" user-emacs-directory))
(require 'md-pv)
(require 'welcome)
(require 'my-git)
(require 'funcs)
(require 'keybinds)
(evil-mode 1)

;;; Automatic pairing

(require 'elec-pair)
(setq electric-pair-pairs '((?\( . ?\))
                            (?\[ . ?\])
                            (?\{ . ?\})
                            (?\" . ?\")
                            (?\' . ?\')))
(electric-pair-mode 1)

;;; Theme

;; Theme settings are managed by Custom.
(custom-set-variables
 ;; custom-set-variables was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(custom-enabled-themes '(tango)))

(custom-set-faces
 ;; custom-set-faces was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 )

;; Set the default text size to 12 pt (120 = 12 pt in Emacs).
(set-face-attribute 'default nil :height 150)

;;; File change handling

;; Refresh buffers edited by external tools without prompting.
(setq revert-without-query '(".*")
      auto-revert-verbose nil
      auto-revert-interval 0.1
      auto-revert-use-notify t)
