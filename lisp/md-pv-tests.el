;;; md-pv-tests.el --- Markdown preview tests -*- lexical-binding: t; -*-

(require 'ert)
(require 'md-pv)

(ert-deftest md-pv-headings-and-paragraphs ()
  (let ((html (md-pv--render-html "# Title\n\nHello **world** and *Emacs*.")))
    (should (string-match-p "<h1>Title</h1>" html))
    (should (string-match-p
             "<p>Hello <strong>world</strong> and <em>Emacs</em>.</p>" html))
    (should-not (string-match-p "<pre>" html))))

(ert-deftest md-pv-inline-markup ()
  (should (equal (md-pv--render-inline
                  "__bold__ _italic_ [**link**](https://example.com?a=1&b=2)")
                 (concat "<strong>bold</strong> <em>italic</em> "
                         "<a href=\"https://example.com?a=1&amp;b=2\">"
                         "<strong>link</strong></a>")))
  (should (equal (md-pv--render-inline "`**literal** <tag>`")
                 "<code>**literal** &lt;tag&gt;</code>"))
  (should (equal (md-pv--render-inline "![image](image.png)")
                 "![image](image.png)")))

(ert-deftest md-pv-combined-emphasis ()
  (should (equal (md-pv--render-inline "***Both*** ___Also___")
                 (concat "<strong><em>Both</em></strong> "
                         "<strong><em>Also</em></strong>")))
  (should (equal (md-pv--render-inline "`***literal***`")
                 "<code>***literal***</code>")))

(ert-deftest md-pv-preview-typography ()
  (let ((shr-use-fonts nil))
    (with-temp-buffer
      (let ((source-remapping face-remapping-alist))
        (with-temp-buffer
          (md-pv-preview-mode)
          (should buffer-read-only)
          (should shr-use-fonts)
          (should visual-line-mode)
          (should-not font-lock-mode)
          (should (equal line-spacing 0.2))
          (should (memq 'md-pv-body (cdr (assq 'default face-remapping-alist))))
          (let ((previous-height 2.0))
            (dotimes (index 6)
              (let* ((level (1+ index))
                     (shr-face (intern (format "shr-h%d" level)))
                     (preview-face (intern (format "md-pv-heading-%d" level)))
                     (height (face-attribute preview-face :height)))
                (should (memq preview-face
                              (cdr (assq shr-face face-remapping-alist))))
                (should (< height previous-height))
                (should (eq (face-attribute preview-face :weight) 'bold))
                (setq previous-height height))))
          (should (eq (face-attribute 'md-pv-body :inherit) 'variable-pitch))
          (should (eq (face-attribute 'md-pv-code :inherit) 'fixed-pitch))
          (should (eq (face-attribute 'md-pv-bold :weight) 'bold))
          (should (eq (face-attribute 'md-pv-italic :slant) 'italic))
          (let ((inhibit-read-only t))
            (insert (md-pv--render-html
                     "# Heading\n\n**Bold** *Italic* ***Both*** `code`\n\n```\nblock\n```"))
            (shr-render-region (point-min) (point-max)))
          (dolist (sample '(("Heading" shr-h1) ("Bold" bold) ("Italic" italic)
                            ("Both" bold italic) ("code" shr-code)
                            ("block" shr-code)))
            (goto-char (point-min))
            (search-forward (car sample))
            (let ((faces (ensure-list (get-text-property (1- (point)) 'face))))
              (dolist (face (cdr sample))
                (should (memq face faces))))))
        (should (equal face-remapping-alist source-remapping))
        (should-not shr-use-fonts)))))

(ert-deftest md-pv-lists ()
  (let ((html (md-pv--render-html "- One\n- **Two**\n\n1. First\n2. Second")))
    (should (string-match-p
             "<ul><li>One</li><li><strong>Two</strong></li></ul>" html))
    (should (string-match-p
             "<ol><li>First</li><li>Second</li></ol>" html))))

(ert-deftest md-pv-code-fences ()
  (dolist (fence '("```" "~~~"))
    (let ((html (md-pv--render-html
                 (concat fence "text\n# literal\n<a> & **bold**\n"
                         fence "\n# Heading"))))
      (should (string-match-p
               (regexp-quote
                "<pre><code># literal\n&lt;a&gt; &amp; **bold**</code></pre>")
               html))
      (should (string-match-p "<h1>Heading</h1>" html))))
  (should (string-match-p "<pre><code>unfinished</code></pre>"
                          (md-pv--render-html "```\nunfinished"))))

(ert-deftest md-pv-literal-html-and-incomplete-markup ()
  (should (equal (md-pv--render-inline "<script>&\" *unfinished")
                 "&lt;script&gt;&amp;&quot; *unfinished"))
  (should (string-match-p "<body></body>" (md-pv--render-html ""))))

(ert-deftest md-pv-rendered-heading-face ()
  (with-temp-buffer
    (insert (md-pv--render-html "# Heading\n\n**Bold**"))
    (shr-render-region (point-min) (point-max))
    (goto-char (point-min))
    (search-forward "Heading")
    (should (memq 'shr-h1 (ensure-list (get-text-property
                                      (1- (point)) 'face))))
    (should-not (string-match-p "# Heading\\|\\*\\*Bold\\*\\*" (buffer-string)))))

(ert-deftest md-pv-live-preview-lifecycle ()
  (save-window-excursion
    (with-temp-buffer
      (switch-to-buffer (current-buffer))
      (insert "# Initial\n")
      (unwind-protect
          (progn
            (md-pv)
            (should-not buffer-read-only)
            (should (with-current-buffer md-pv--preview-buffer-name
                      (and (eq major-mode 'md-pv-preview-mode)
                           buffer-read-only
                           (string-match-p "Initial" (buffer-string)))))
            (insert "\n**Updated**")
            (should (with-current-buffer md-pv--preview-buffer-name
                      (and (string-match-p "Updated" (buffer-string))
                           (not (string-match-p "\\*\\*Updated\\*\\*"
                                                (buffer-string))))))
            (md-pv)
            (should-not (memq #'md-pv--on-change after-change-functions))
            (should-not (get-buffer-window md-pv--preview-buffer-name)))
        (remove-hook 'after-change-functions #'md-pv--on-change t)
        (when (get-buffer md-pv--preview-buffer-name)
          (kill-buffer md-pv--preview-buffer-name))))))

;;; md-pv-tests.el ends here
