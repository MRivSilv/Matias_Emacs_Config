;;; md-pv.el --- Real-time Markdown Live Previewer -*- lexical-binding: t; -*-

(require 'cl-lib)
(require 'face-remap)
(require 'shr)

;; Dependency-free preview of headings, paragraphs, flat lists, fenced code,
;; inline code, emphasis, and links.  Not a full CommonMark implementation:
;; tables, nested lists, and images are unsupported; raw HTML is escaped.

(defgroup md-pv nil
  "Live Markdown preview."
  :group 'text)

(defface md-pv-body
  '((t (:inherit variable-pitch :height 1.1)))
  "Preview body text."
  :group 'md-pv)

(defface md-pv-heading-1
  '((t (:inherit variable-pitch :height 1.8 :weight bold)))
  "First-level preview headings."
  :group 'md-pv)

(defface md-pv-heading-2
  '((t (:inherit variable-pitch :height 1.5 :weight bold)))
  "Second-level preview headings."
  :group 'md-pv)

(defface md-pv-heading-3
  '((t (:inherit variable-pitch :height 1.3 :weight bold)))
  "Third-level preview headings."
  :group 'md-pv)

(defface md-pv-heading-4
  '((t (:inherit variable-pitch :height 1.15 :weight bold)))
  "Fourth-level preview headings."
  :group 'md-pv)

(defface md-pv-heading-5
  '((t (:inherit variable-pitch :height 1.05 :weight bold)))
  "Fifth-level preview headings."
  :group 'md-pv)

(defface md-pv-heading-6
  '((t (:inherit variable-pitch :height 1.0 :weight bold :slant italic)))
  "Sixth-level preview headings."
  :group 'md-pv)

(defface md-pv-bold
  '((t (:weight bold)))
  "Bold preview text."
  :group 'md-pv)

(defface md-pv-italic
  '((t (:slant italic)))
  "Italic preview text."
  :group 'md-pv)

(defface md-pv-code
  '((t (:inherit fixed-pitch :height 0.95)))
  "Monospace inline and fenced code."
  :group 'md-pv)

(defun md-pv--render-code (dom)
  "Render code DOM with an explicit face, including inside preformatted blocks."
  ;; SHR's preformatted insertion skips its normal current-font handling.
  (shr-fontize-dom dom 'shr-code))

(define-derived-mode md-pv-preview-mode special-mode "MD Preview"
  "Read-only Markdown preview with buffer-local typography.
Customize faces in the `md-pv' group to change fonts and sizes.
Font sizes and families require graphical Emacs and suitable fonts."
  (setq-local shr-use-fonts t)
  (setq-local shr-external-rendering-functions
              (cons '(code . md-pv--render-code)
                    shr-external-rendering-functions))
  (setq-local line-spacing 0.2)
  (setq-local cursor-type nil)
  (setq-local display-line-numbers nil)
  (visual-line-mode 1)
  (dolist (mapping '((default . md-pv-body)
                     (shr-h1 . md-pv-heading-1)
                     (shr-h2 . md-pv-heading-2)
                     (shr-h3 . md-pv-heading-3)
                     (shr-h4 . md-pv-heading-4)
                     (shr-h5 . md-pv-heading-5)
                     (shr-h6 . md-pv-heading-6)
                     (bold . md-pv-bold)
                     (italic . md-pv-italic)
                     (shr-code . md-pv-code)))
    (face-remap-add-relative (car mapping) (cdr mapping))))

(defvar md-pv--preview-buffer-name "*MD Live Preview*"
  "Name of the buffer used for rendering Markdown preview.")

(defun md-pv--escape-html (text)
  "Escape TEXT for use in HTML content or attributes."
  (dolist (pair '(("&" . "&amp;") ("<" . "&lt;") (">" . "&gt;")
                  ("\"" . "&quot;")))
    (setq text (replace-regexp-in-string (car pair) (cdr pair) text t t)))
  text)

(defun md-pv--render-inline (text)
  "Render supported inline Markdown in TEXT, escaping literal HTML."
  (let ((pattern (concat
                  "`\\([^`\n]+\\)`"
                  "\\|\\*\\*\\*\\([^*\n]+\\)\\*\\*\\*"
                  "\\|___\\([^_\n]+\\)___"
                  "\\|\\*\\*\\([^*\n]+\\)\\*\\*"
                  "\\|__\\([^_\n]+\\)__"
                  "\\|\\*\\([^*\n]+\\)\\*"
                  "\\|_\\([^_\n]+\\)_"
                  "\\|\\[\\([^]\n]+\\)\\](\\([^() \t\n]+\\))"))
        (position 0)
        parts)
    (while (string-match pattern text position)
      (let* ((start (match-beginning 0))
             (end (match-end 0))
             (code (match-string 1 text))
             (bold-italic (or (match-string 2 text) (match-string 3 text)))
             (bold (or (match-string 4 text) (match-string 5 text)))
             (italic (or (match-string 6 text) (match-string 7 text)))
             (label (match-string 8 text))
             (url (match-string 9 text)))
        (push (md-pv--escape-html (substring text position start)) parts)
        (push (cond
               (code (concat "<code>" (md-pv--escape-html code) "</code>"))
               (bold-italic
                (concat "<strong><em>" (md-pv--render-inline bold-italic)
                        "</em></strong>"))
               (bold (concat "<strong>" (md-pv--render-inline bold) "</strong>"))
               (italic (concat "<em>" (md-pv--render-inline italic) "</em>"))
               (label
                (if (and (> start 0) (= (aref text (1- start)) ?!))
                    (md-pv--escape-html (substring text start end))
                  (concat "<a href=\"" (md-pv--escape-html url) "\">"
                          (md-pv--render-inline label) "</a>"))))
              parts)
        (setq position end)))
    (push (md-pv--escape-html (substring text position)) parts)
    (apply #'concat (nreverse parts))))

(defun md-pv--render-html (markdown-text)
  "Convert the supported Markdown subset in MARKDOWN-TEXT to HTML."
  (let (parts paragraph list-type fence code)
    (cl-labels
        ((flush-paragraph ()
           (when paragraph
             (push (concat "<p>"
                           (md-pv--render-inline
                            (mapconcat #'identity (nreverse paragraph) "\n"))
                           "</p>") parts)
             (setq paragraph nil)))
         (close-list ()
           (when list-type
             (push (concat "</" list-type ">") parts)
             (setq list-type nil)))
         (flush-code ()
           (push (concat "<pre><code>"
                         (md-pv--escape-html
                          (mapconcat #'identity (nreverse code) "\n"))
                         "</code></pre>") parts)
           (setq code nil fence nil)))
      (dolist (line (split-string markdown-text "\n"))
        (cond
         (fence
          (if (string-match-p
               (concat "\\`[ \t]*" (regexp-quote fence)
                       (substring fence 0 1) "*[ \t]*\\'")
               line)
              (flush-code)
            (push line code)))
         ((string-match "\\`[ \t]*\\(`\\{3,\\}\\|~\\{3,\\}\\).*\\'" line)
          (setq fence (match-string 1 line))
          (flush-paragraph)
          (close-list))
         ((string-match-p "\\`[ \t]*\\'" line)
          (flush-paragraph)
          (close-list))
         ((string-match "\\`\\(#\\{1,6\\}\\)[ \t]+\\(.*\\)\\'" line)
          (let ((level (length (match-string 1 line)))
                (text (match-string 2 line)))
            (flush-paragraph)
            (close-list)
            (push (format "<h%d>%s</h%d>" level
                          (md-pv--render-inline text) level) parts)))
         ((string-match
           "\\`[ \t]*\\([-+*]\\|[0-9]+[.)]\\)[ \t]+\\(.*\\)\\'" line)
          (let ((type (if (string-match-p "\\`[0-9]" (match-string 1 line))
                          "ol" "ul"))
                (text (match-string 2 line)))
            (flush-paragraph)
            (unless (equal list-type type)
              (close-list)
              (setq list-type type)
              (push (concat "<" type ">") parts))
            (push (concat "<li>" (md-pv--render-inline text) "</li>") parts)))
         (t
          (close-list)
          (push line paragraph))))
      (when fence (flush-code))
      (flush-paragraph)
      (close-list))
    (concat "<!DOCTYPE html><html><head><meta charset=\"utf-8\"></head><body>"
            (apply #'concat (nreverse parts))
            "</body></html>")))

(defun md-pv-update ()
  "Render current buffer content."
  (interactive)
  (when-let* ((window (get-buffer-window md-pv--preview-buffer-name)))
    (let ((content (buffer-substring-no-properties (point-min) (point-max))))
      (with-selected-window window
        (let ((inhibit-read-only t))
          (erase-buffer)
          (insert (md-pv--render-html content))
          (shr-render-region (point-min) (point-max)))))))

(defun md-pv--on-change (&rest _)
  (md-pv-update))

;;;###autoload
(defun md-pv ()
  "Toggle real-time preview of the supported Markdown subset.
Supports headings, paragraphs, flat lists, fenced and inline code,
bold/italic emphasis, and links without an external converter.
Customize the `md-pv' faces to adjust preview fonts and sizes."
  (interactive)
  (let ((source-buf (current-buffer)))
    (if-let* ((win (get-buffer-window md-pv--preview-buffer-name)))
        (progn
          (delete-window win)
          (remove-hook 'after-change-functions #'md-pv--on-change t)
          (message "Markdown preview closed."))
      (let ((preview-buf (get-buffer-create md-pv--preview-buffer-name)))
        (select-window (split-window-right))
        (switch-to-buffer preview-buf)
        (md-pv-preview-mode)
        (select-window (get-buffer-window source-buf))
        (add-hook 'after-change-functions #'md-pv--on-change nil t)
        (md-pv-update)
        (message "Markdown live preview active.")))))

(provide 'md-pv)
;;; md-pv.el ends here
