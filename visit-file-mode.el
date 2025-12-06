;;; visit-file-mode.el --- Jump to files from stack traces -*- lexical-binding: t; -*-

;; Copyright (C) 2025

;; Author: Wilfred Hughes
;; Version: 0.1.0
;; Package-Requires: ((emacs "24.3"))
;; Keywords: convenience, tools
;; URL: https://github.com/Wilfred/visit-file-mode

;;; Commentary:

;; visit-file-mode is a minor mode that allows you to jump to a file
;; based on a path, line and column found in stack traces.
;;
;; It recognizes various formats including:
;; - OCaml: in file "src/list.ml", line 191, characters 10-25
;; - Rust: at ./src/main.rs:473:13
;;
;; When the minor mode is active, occurrences of these patterns in
;; the buffer are highlighted. You can jump to the file at the
;; specified location.

;;; Code:

(defgroup visit-file-mode nil
  "Jump to files from stack traces."
  :group 'tools
  :prefix "visit-file-mode-")

(defface visit-file-mode-highlight
  '((t :inherit link))
  "Face used to highlight file paths that exist in visit-file-mode."
  :group 'visit-file-mode)

(defface visit-file-mode-highlight-missing
  '((t :inherit font-lock-warning-face))
  "Face used to highlight file paths that don't exist in visit-file-mode."
  :group 'visit-file-mode)

(defvar visit-file-mode-patterns
  '(
    ;; OCaml format: in file "path/to/file.ml", line 191, characters 10-25
    ("in file \"\\([^\"]+\\)\", line \\([0-9]+\\)\\(?:, characters \\([0-9]+\\)-[0-9]+\\)?"
     (file . 1) (line . 2) (column . 3))

    ;; Rust format: at ./path/to/file.rs:123:45
    ;; Also matches absolute paths like /home/user/file.rs:123:45
    ("at \\([^:[:space:]]+\\):\\([0-9]+\\):\\([0-9]+\\)"
     (file . 1) (line . 2) (column . 3))

    ;; Generic format: path/to/file.ext:123:45
    ("\\(?:^\\|[[:space:]]\\)\\(/?[^:[:space:]]+\\.[a-z]+\\):\\([0-9]+\\):\\([0-9]+\\)"
     (file . 1) (line . 2) (column . 3))
    )
  "List of patterns to match file paths with line and column numbers.
Each pattern is a list of (REGEXP . CAPTURE-GROUPS) where
CAPTURE-GROUPS is an alist mapping 'file, 'line, and 'column to
their respective capture group numbers.")

(defun visit-file-mode--parse-match (pattern)
  "Parse the current match using PATTERN and return (file line column).
PATTERN should be an element from `visit-file-mode-patterns'."
  (let* ((groups (cdr pattern))
         (file-group (cdr (assq 'file groups)))
         (line-group (cdr (assq 'line groups)))
         (column-group (cdr (assq 'column groups)))
         (file (match-string-no-properties file-group))
         (line (string-to-number (match-string-no-properties line-group)))
         (column (when column-group
                   (let ((col-str (match-string-no-properties column-group)))
                     (when col-str
                       (string-to-number col-str))))))
    (list file line column)))

(defun visit-file-mode-visit-at-point ()
  "Visit the file at point based on recognized patterns."
  (interactive)
  (let ((found nil)
        (original-point (point)))
    (save-excursion
      (beginning-of-line)
      (let ((line-end (line-end-position)))
        (dolist (pattern visit-file-mode-patterns)
          (when (and (not found)
                     (re-search-forward (car pattern) line-end t)
                     (<= (match-beginning 1) original-point)
                     (>= (match-end 0) original-point))
            (let* ((match-data (visit-file-mode--parse-match pattern))
                   (file (nth 0 match-data))
                   (line (nth 1 match-data))
                   (column (nth 2 match-data))
                   (full-path (expand-file-name file)))
              (if (file-exists-p full-path)
                  (progn
                    (find-file full-path)
                    (goto-char (point-min))
                    (forward-line (1- line))
                    (when column
                      (forward-char (1- column)))
                    (setq found t))
                (message "File not found: %s" full-path)))))))
    (unless found
      (message "No file path found at point"))))

(defun visit-file-mode--fontify (limit)
  "Font-lock function to highlight file paths up to LIMIT."
  (let ((found nil))
    (while (and (not found) (< (point) limit))
      (let ((start-pos (point)))
        (dolist (pattern visit-file-mode-patterns)
          (when (and (not found)
                     (re-search-forward (car pattern) limit t))
            (let* ((match-data (visit-file-mode--parse-match pattern))
                   (file (nth 0 match-data))
                   (full-path (expand-file-name file)))
              (put-text-property (match-beginning 1) (match-end 0)
                                 'face
                                 (if (file-exists-p full-path)
                                     'visit-file-mode-highlight
                                   'visit-file-mode-highlight-missing))
              (put-text-property (match-beginning 1) (match-end 0)
                                 'mouse-face 'highlight)
              (setq found t))))
        (unless found
          (goto-char (1+ start-pos)))))
    found))

(defvar visit-file-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "RET") 'visit-file-mode-visit-at-point)
    (define-key map (kbd "<mouse-1>") 'visit-file-mode-visit-at-point)
    map)
  "Keymap for `visit-file-mode'.")

;;;###autoload
(define-minor-mode visit-file-mode
  "Minor mode for jumping to files from stack traces.

When enabled, file paths with line and column numbers are highlighted.
Press RET or click to visit the file at the specified location."
  :lighter " VFile"
  :keymap visit-file-mode-map
  (if visit-file-mode
      (font-lock-add-keywords nil '((visit-file-mode--fontify)) t)
    (font-lock-remove-keywords nil '((visit-file-mode--fontify))))
  (if (fboundp 'font-lock-flush)
      (font-lock-flush)
    (when font-lock-mode
      (font-lock-fontify-buffer))))

(provide 'visit-file-mode)
;;; visit-file-mode.el ends here
