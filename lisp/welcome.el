;;; welcome.el --- Custom startup dashboard -*- lexical-binding: t; -*-

;; Lexical binding lets button actions remember values such as their file
;; or command, even when clicked after the function that created them returns.
;; These built-in libraries supply clickable buttons, cl-loop, recent-file
;; history, and sequence helpers such as seq-take.
(require 'button)
(require 'cl-lib)
(require 'recentf)
(require 'seq)

;; Resolve the artwork relative to this library, not the current project.
;; load-file-name is available when loading; buffer-file-name supports evaluation
;; directly from the file's editing buffer.
(defconst welcome--art-file
  (expand-file-name "ascii-art/welcome.txt"
                    (file-name-directory (or load-file-name buffer-file-name)))
  "Path to the welcome screen banner.")

;; A face describes appearance.  Use different reds for light and dark themes,
;; with the default face as a fallback on displays without color.
(defface welcome-banner
  '((((class color) (background light)) (:foreground "#781f2b"))
    (((class color) (background dark)) (:foreground "#b64b58"))
    (t (:inherit default)))
  "Deep crimson used for the Horde emblem."
  :group 'faces)

(defun welcome--banner (art)
  "Render ART as a solid emblem when SVG display is available."
  ;; Terminals and graphical builds without SVG support display the original
  ;; text artwork instead of an image.
  (if (not (and (display-graphic-p) (image-type-available-p 'svg)))
      (propertize art 'face 'welcome-banner)
    (require 'svg)
    ;; let* computes these values in order, so later values can use earlier ones.
    ;; Size the image in screen pixels, but draw in a coordinate system where
    ;; each Braille character occupies two columns and four rows of dots.
    (let* ((lines (split-string art "\n" t))
           (columns (apply #'max (mapcar #'length lines)))
           (rows (length lines))
           (color (face-foreground 'welcome-banner nil t))
           (svg (svg-create (* columns (frame-char-width))
                            (* rows (frame-char-height))
                            :viewBox (format "0 0 %d %d"
                                             (* columns 2) (* rows 4))))
           ;; Coordinates are ordered by the eight bits in a Braille character.
           (dots '((0 . 0) (0 . 1) (0 . 2) (1 . 0)
                   (1 . 1) (1 . 2) (0 . 3) (1 . 3)))
           paths)
      ;; Walk the artwork character by character.  Subtracting #x2800 exposes
      ;; the Braille dot bitmask; each set bit becomes a small square SVG path.
      (cl-loop for line in lines
               for y from 0 do
               (cl-loop for char across line
                        for x from 0
                        when (<= #x2800 char #x28ff) do
                        (cl-loop for (dx . dy) in dots
                                 for bit from 0
                                 when (/= 0 (logand (ash 1 bit)
                                                    (- char #x2800))) do
                                 (push (format "M%d %dh1v1h-1z"
                                               (+ (* x 2) dx)
                                               (+ (* y 4) dy))
                                       paths))))
      ;; Combine the squares into one path.  The small stroke closes visual
      ;; gaps, making neighboring dots look like a solid emblem.
      (svg-node svg 'path :d (mapconcat #'identity (nreverse paths) " ")
                :fill color :stroke color :stroke-width 0.2
                :stroke-linejoin "round")
      ;; Emacs displays the SVG in place of this space via its display property.
      (concat (propertize " " 'display (svg-image svg :ascent 'center))
              "\n"))))

(defun welcome--center-content (window banner-end)
  "Center the dashboard within WINDOW, with artwork ending at BANNER-END."
  ;; A marker follows the artwork boundary as padding is inserted before it.
  ;; save-excursion measures the widest artwork line without moving point
  ;; permanently; point is Emacs' name for the current buffer position.
  (let* ((graphic (display-graphic-p))
         (art-end (copy-marker banner-end))
         (art-width (save-excursion
                      (goto-char (point-min))
                      (let ((width 0))
                        (while (< (point) art-end)
                          (setq width (max width (- (line-end-position)
                                                    (line-beginning-position))))
                          (forward-line 1))
                        width))))
    (goto-char (point-min))
    (while (not (eobp))
      ;; Strip old indentation from text, but preserve spacing inside the art.
      (unless (< (point) art-end)
        (delete-region (point) (progn (skip-chars-forward " ") (point))))
      (let* ((start (point))
             (end (line-end-position))
             (image (get-text-property start 'display))
             (banner (< start art-end))
             (width
              ;; Images supply their own pixel width.  Text art shares one
              ;; width so its lines stay aligned; other text is centered per line.
              (cond
               ((and (consp image) (eq (car image) 'image))
                (car (image-size image t)))
               (banner (* art-width (frame-char-width)))
               (graphic
                (string-pixel-width (buffer-substring start end)))
               (t (* (string-width (buffer-substring start end))
                     (frame-char-width))))))
        (when (< start end)
          (let ((padding (max 0 (/ (- (window-body-width window t) width)
                                    2))))
            ;; Graphical Emacs supports exact pixel padding; terminals need
            ;; whole spaces.  max above prevents negative padding in narrow windows.
            (if graphic
                (insert (propertize " " 'display
                                    `(space :width (,padding))))
              (insert (make-string (/ padding (frame-char-width)) ?\s)))))
        (forward-line 1)))
    ;; Release the temporary marker after all insertions are finished.
    (set-marker art-end nil)))

;; A frame is an Emacs window at the OS level; it can contain several Emacs
;; windows (panes).  Redraw only panes showing this dashboard after a resize.
(defun welcome--resize (frame)
  "Update welcome screens displayed in FRAME."
  (dolist (window (window-list frame 'no-minibuffer))
    (with-selected-window window
      (when (derived-mode-p 'welcome-mode)
        (welcome--render)))))

(defun welcome--recenter ()
  "Recenter the welcome screen after its window configuration changes."
  ;; Splitting or deleting panes can change the available width too.
  ;; when-let* skips the redraw when the dashboard is not currently visible.
  (when-let* ((window (get-buffer-window (current-buffer))))
    (with-selected-window window
      (welcome--render))))

(defun welcome-open-config ()
  "Open the Emacs initialization file."
  (interactive)
  ;; interactive makes this callable through M-x as well as through a button.
  ;; Fall back to init.el if Emacs has no recorded initialization file.
  (find-file (or user-init-file
                 (expand-file-name "init.el" user-emacs-directory))))

(defun welcome-open-scratch ()
  "Switch to the scratch buffer, creating it if needed."
  (interactive)
  (let ((buffer (get-buffer "*scratch*")))
    ;; Reuse existing scratch contents.  Only initialize the mode and greeting
    ;; if the user previously killed the scratch buffer.
    (unless buffer
      (setq buffer (get-buffer-create "*scratch*"))
      (with-current-buffer buffer
        (funcall initial-major-mode)
        (when initial-scratch-message
          (insert initial-scratch-message))))
    (switch-to-buffer buffer)))

(defvar welcome-mode-map
  (let ((map (make-sparse-keymap)))
    ;; Inherit special-mode's navigation and q-to-dismiss behavior, then add
    ;; dashboard shortcuts.  These bindings apply only in welcome-mode.
    (set-keymap-parent map special-mode-map)
    (define-key map (kbd "f") #'find-file)
    (define-key map (kbd "r") #'recentf-open-files)
    (define-key map (kbd "c") #'welcome-open-config)
    (define-key map (kbd "s") #'welcome-open-scratch)
    (define-key map (kbd "g") #'revert-buffer)
    (define-key map (kbd "TAB") #'forward-button)
    (define-key map (kbd "<backtab>") #'backward-button)
    map)
  "Keymap for the welcome screen.")

(define-derived-mode welcome-mode special-mode "Welcome"
  "A read-only startup screen with navigation shortcuts."
  ;; special-mode supplies read-only behavior.  These settings affect only
  ;; this buffer: hide the cursor, avoid wrapping, and make refresh redraw it.
  (setq-local cursor-type nil
              truncate-lines t
              revert-buffer-function #'welcome--render)
  ;; The final t installs this hook locally, not in every buffer.
  (add-hook 'window-configuration-change-hook #'welcome--recenter nil t)
  (setq-local default-directory user-emacs-directory))

;; Keep dashboard keys such as f and r from being intercepted by Evil's normal
;; state.  Delay this setup until Evil is loaded, regardless of load order.
(with-eval-after-load 'evil
  (evil-set-initial-state 'welcome-mode 'emacs))

(defun welcome--shortcut (key label command)
  "Insert a button for COMMAND with KEY and LABEL."
  (insert "  ")
  ;; The button runs COMMAND interactively, so commands such as find-file
  ;; prompt normally.  _button is an unused argument passed by the button API.
  ;; KEY is a displayed label; the actual keyboard binding lives in the keymap.
  (insert-text-button (format "[%s] %s" key label)
                      'follow-link t
                      'action (lambda (_button)
                                (call-interactively command)))
  (insert "\n"))

(defun welcome--render (&rest _)
  "Render the welcome screen in the current buffer."
  ;; Refresh callbacks can pass arguments; &rest _ accepts and ignores them.
  ;; Temporarily bypass read-only protection so the dashboard can be rebuilt.
  (let ((inhibit-read-only t)
        banner-end)
    (erase-buffer)
    (insert "\n")
    ;; Read the Unicode artwork as UTF-8 in a disposable buffer, then render
    ;; the resulting string into the dashboard.
    (insert (welcome--banner
             (with-temp-buffer
               (let ((coding-system-for-read 'utf-8))
                 (insert-file-contents welcome--art-file))
               (buffer-string))))
    ;; Remember where the artwork ends so centering can treat it as one block.
    (setq banner-end (point))
    (insert (propertize "\n  Lok'tar Ogar!!\n\n" 'face 'bold))
    (welcome--shortcut "f" "Open file" #'find-file)
    (welcome--shortcut "r" "Browse recent files" #'recentf-open-files)
    (welcome--shortcut "c" "Open configuration" #'welcome-open-config)
    (welcome--shortcut "s" "Scratch buffer" #'welcome-open-scratch)
    (insert (propertize "\n  Recent files\n\n" 'face 'bold))
    ;; Show up to five recent files.  Each button displays a shortened path,
    ;; exposes the full path on hover, and remembers which file to open.
    (if recentf-list
        (dolist (file (seq-take recentf-list 5))
          (insert "  ")
          (insert-text-button (abbreviate-file-name file)
                              'follow-link t
                              'help-echo file
                              'action (lambda (_button) (find-file file)))
          (insert "\n"))
      (insert "  No recent files yet.\n"))
    (insert (propertize
             "\n  TAB: next link   RET: open   g: refresh   q: dismiss\n"
             'face 'shadow))
    ;; Width-dependent centering needs a visible window.  Startup can create
    ;; this buffer before it is displayed, so centering is conditional.
    (when-let* ((window (get-buffer-window (current-buffer))))
      (welcome--center-content window banner-end))
    ;; Leave the screen at the top and prevent a misleading "modified" marker.
    (goto-char (point-min))
    (set-buffer-modified-p nil)))

(defun welcome--buffer ()
  "Return the rendered welcome buffer."
  ;; Reuse one named buffer.  with-current-buffer prepares it without changing
  ;; which buffer the user currently sees, then returns it to the caller.
  (with-current-buffer (get-buffer-create "*Welcome*")
    (welcome-mode)
    (welcome--render)
    (current-buffer)))

;;;###autoload
(defun welcome-show ()
  "Display the custom welcome screen."
  (interactive)
  (switch-to-buffer (welcome--buffer))
  ;; Render again now that the buffer is visible and can be centered.
  (welcome--render))

;; Register frame-resize handling and enable persistent recent-file history.
(add-hook 'window-size-change-functions #'welcome--resize)
(recentf-mode 1)
;; Replace the standard startup screen with this buffer-producing function.
;; The scratch greeting remains available when opening scratch separately.
(setq inhibit-startup-screen t
      initial-scratch-message ";; Lok'tar Ogar!!\n\n"
      initial-buffer-choice #'welcome--buffer)

;; Allow (require 'welcome) to recognize that this library has been loaded.
(provide 'welcome)
;;; welcome.el ends here
