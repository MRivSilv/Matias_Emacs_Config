;;; keybinds.el --- Personal key bindings -*- lexical-binding: t; -*-

(require 'evil)
(require 'funcs)
(require 'my-git)

;; Make Shift+Space return to Evil normal state from any Evil state.
(dolist (map (list evil-normal-state-map
                   evil-insert-state-map
                   evil-visual-state-map
                   evil-replace-state-map
                   evil-operator-state-map
                   evil-motion-state-map
                   evil-emacs-state-map))
  (define-key map (kbd "S-SPC") #'evil-normal-state))
(global-set-key (kbd "S-SPC") #'evil-normal-state)

(global-set-key (kbd "C-M-'") #'my/insert-backslash)
(global-set-key (kbd "C-}") #'my/insert-backtick)
(global-set-key (kbd "M--") #'dired-jump)
(global-set-key (kbd "M-+") #'my/insert-tilde)
(global-set-key (kbd "C-|") #'my/insert-less-than)
(global-set-key (kbd "C-°") #'my/insert-greater-than)
(global-set-key (kbd "C-c g c") #'git-checkout)

(provide 'keybinds)

;;; keybinds.el ends here
