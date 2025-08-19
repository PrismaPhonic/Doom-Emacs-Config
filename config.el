;; The default is 800 kilobytes.  Measured in bytes.
(setq gc-cons-threshold (* 50 1000 1000))

(defun pmf/display-startup-time ()
  (message "Emacs loaded in %s with %d garbage collections."
           (format "%.2f seconds"
                   (float-time
                    (time-subtract after-init-time before-init-time)))
           gcs-done))

(add-hook 'emacs-startup-hook #'pmf/display-startup-time)

(setq user-full-name "Peter Farr"
      user-mail-address "farr.peterm@gmail.com")

(defun my/toggle-file-split (filepath)
  "Toggle horizontal split showing FILEPATH.
If it's visible, close it. Otherwise, open in a horizontal split."
  (interactive "fPath to file: ")
  (let* ((fullpath (expand-file-name filepath))
         (buf (or (find-buffer-visiting fullpath)
                  (find-file-noselect fullpath)))
         (win (get-buffer-window buf t))) ;; search all visible frames
    (if win
        (delete-window win)
      (let ((new-win (split-window-below)))
        (set-window-buffer new-win buf)
        (select-window new-win)))))

(map! :leader
      :desc "Toggle gtd tasks"
      "o g" (lambda () (interactive) (my/toggle-file-split "~/org/gtd/org-gtd-tasks.org"))
      :desc "Toggle jira issues"
      "o j" (lambda () (interactive) (my/toggle-file-split "~/.org-jira/AUTH.org")))

(defun my/org-md-scratchpad ()
  "Open Org buffer, export to Markdown via Pandoc, clean output, copy to clipboard, and clean up."
  (interactive)
  (let* ((buf (generate-new-buffer "*org-md-scratchpad*"))
         (win (split-window-below)))
    (select-window win)
    (switch-to-buffer buf)
    (org-mode)
    (insert "#+BEGIN_SRC shell :results verbatim :exports both\n#+END_SRC")
    (goto-char (point-max))
    ;; Setup C-c C-c to export + copy
    (let ((map (make-sparse-keymap)))
      (set-keymap-parent map org-mode-map)
      (define-key map (kbd "C-c C-c")
                  (lambda ()
                    (interactive)
                    (let* ((scratchpad-buf (current-buffer))
                           (tmp-org (make-temp-file "scratchpad" nil ".org"))
                           (tmp-md (make-temp-file "scratchpad" nil ".md")))
                      (condition-case err
                          (progn
                            ;; Evaluate code blocks
                            (let ((org-confirm-babel-evaluate nil))
                              (org-babel-execute-buffer))
                            ;; Write Org content to temp file
                            (write-region (point-min) (point-max) tmp-org nil 'quiet)
                            ;; Run Pandoc with clean formatting options
                            (call-process "pandoc" nil nil nil
                                          tmp-org "-f" "org" "-t" "markdown"
                                          "-o" tmp-md
                                          "--wrap=none"
                                          "--markdown-headings=atx")
                            ;; Read final result and copy
                            (with-temp-buffer
                              (insert-file-contents tmp-md)
                              (kill-new (buffer-string)))
                            (message "✅ Markdown copied to clipboard.")
                            ;; Cleanup
                            (kill-buffer scratchpad-buf)
                            (when (window-live-p win)
                              (delete-window win)))
                        (error (message "❌ Export failed: %s" (error-message-string err)))))))
      (use-local-map map))))

;; Opens org to markdown scratch pad.
(map! :leader
      :desc "Org to markdown scratchpad"
      "o o" (lambda () (interactive) (my/org-md-scratchpad)))

(setq ispell-program-name "hunspell")
(setq ispell-dictionary "en_US")

(setq doom-theme 'doom-oceanic-next)

(setq doom-font (font-spec :family "Monaspace Neon" :size 16 :weight 'light)
      doom-variable-pitch-font (font-spec :family "Monaspace Argon" :size 17)
      doom-serif-font (font-spec :family "Monaspace Xenon" :size 17))

(setq display-line-numbers-type 'relative)

;; Enforce that emacs uses the system default browser set with
;; $ xdg-settings set default-web-browser firefox-developer-edition.desktop
(setq browser-url-browser-function 'browse-url-default-browser)

(defun pmf/org-font-setup ()
  ;; Set faces for heading levels
  (dolist (face '((org-level-1 . 1.2)
                  (org-level-2 . 1.1)
                  (org-level-3 . 1.05)
                  (org-level-4 . 1.0)
                  (org-level-5 . 1.0)
                  (org-level-6 . 1.0)
                  (org-level-7 . 1.0)
                  (org-level-8 . 1.0)))
    (set-face-attribute (car face) nil :font "Cantarell" :weight 'regular :height (cdr face)))

  ;; Ensure that anything that should be fixed-pitch in Org files appears that way
  (set-face-attribute 'org-block nil    :foreground nil :inherit 'fixed-pitch :height 1.0)
  (set-face-attribute 'org-table nil    :inherit 'fixed-pitch)
  (set-face-attribute 'org-formula nil  :inherit 'fixed-pitch)
  (set-face-attribute 'org-code nil     :inherit '(shadow fixed-pitch))
  (set-face-attribute 'org-table nil    :inherit '(shadow fixed-pitch))
  (set-face-attribute 'org-verbatim nil :inherit '(shadow fixed-pitch))
  (set-face-attribute 'org-special-keyword nil :inherit '(font-lock-comment-face fixed-pitch))
  (set-face-attribute 'org-meta-line nil :inherit '(font-lock-comment-face fixed-pitch))
  (set-face-attribute 'org-checkbox nil  :inherit 'fixed-pitch)
  (set-face-attribute 'line-number nil :inherit 'fixed-pitch)
  (set-face-attribute 'line-number-current-line nil :inherit 'fixed-pitch))

(add-hook 'org-mode-hook #'pmf/org-font-setup)

(setq org-directory "~/org")
(setq org-agenda-files
      '("~/org/calendar-beorg.org"
        "~/org/reminders-beorg.org"))

(after! org
  ;; Add a nice drop down carrot instead of the standard [..] when collapsed
  (setq org-ellipsis " ▾")

  ;; When we are done with a todo, log the time it completed
  (setq org-agenda-start-with-log-mode t)
  (setq org-log-done 'time)
  (setq org-log-into-drawer t)

  ;; Override doom emacs org mode todo states to change WAITING to NEXT.
  ;; This might get removed as we use org-gtd entirely now.
  (setq org-todo-keywords
        '((sequence
           "TODO(t)"     ; A task that needs doing & is ready to do
           "PROJ(p)"     ; A project, which usually contains other tasks
           "STRT(s)"     ; A task that is in progress
           "NEXT(n)"     ; A task that's on my list of things to do next
           "WAIT(w)"     ; This task is paused/on hold because I'm waiting for others
           "INBOX(i)"     ; An unconfirmed and unapproved task or notion
           "|"
           "DONE(d)"     ; Task successfully completed
           "CANCEL(c)")))    ; Task was cancelled, aborted, or is no longer applicable

  (setq org-todo-keyword-faces
        '(("STRT"   . +org-todo-active)
          ("NEXT"   . +org-todo-onhold)
          ("WAIT"   . +org-todo-onhold)
          ("PROJ"   . +org-todo-project)
          ("CANCEL" . +org-todo-cancel))))

(after! org
  ;; Persist clocks across restarts (optional but handy)
  (setq org-clock-persist 'history
        org-clock-in-resume t
        org-clock-out-remove-zero-time-clocks t
        org-clock-mode-line-total 'current) ; or 'today / 'auto

  (org-clock-persistence-insinuate)

  ;; Keep the modeline in sync when clock changes
  (add-hook 'org-clock-in-hook    #'org-clock-update-mode-line)
  (add-hook 'org-clock-out-hook   #'org-clock-update-mode-line)
  (add-hook 'org-clock-cancel-hook #'org-clock-update-mode-line))

(setq org-gtd-update-ack "3.0.0")

(use-package! org-gtd
  :after org
  :config
  (setq org-edna-use-inheritance t)
  (setq org-gtd-directory "~/org/gtd")
  (org-edna-mode)
  (map! :leader
        (:prefix ("l" . "org-gtd")
         :desc "Capture"           "c"  #'org-gtd-capture
         :desc "Engage"            "e"  #'my/org-gtd-engage
         :desc "Process inbox"     "p"  #'org-gtd-process-inbox
         :desc "Show all next"     "n"  #'org-gtd-show-all-next
         :desc "Set area of focus" "a"  #'org-gtd-area-of-focus-set-on-item-at-point
         :desc "Stuck projects"    "s"  #'org-gtd-review-stuck-projects))

  (map! :desc "Capture gtd item" "C-c c" #'org-gtd-capture)

  (map! :desc "Area of focus gtd item" "C-c a" #'org-gtd-area-of-focus-set-on-item-at-point)

  (map! :map org-gtd-clarify-map
        :desc "Organize this item" "C-c c" #'org-gtd-organize)

  ;; Setup capture templates to org-gtd inbox
  (setq org-gtd-capture-templates
        '(("i" "Inbox"
           entry  (file "~/org/gtd/inbox.org")
           "* %?\n%U\n\n"
           :kill-buffer t)
          ("l" "Inbox with link"
           entry (file "~/org/gtd/inbox.org")
           "* %?\n%U\n\n  %a"
           :kill-buffer t)
          ("s" "Slack"
           entry (file "~/org/gtd/inbox.org")
           "* [Slack thread w/ %^{Author}]: %?\n%U\n\n  %a"
           :kill-buffer t)
          ("e" "Email"
           entry (file "~/org/gtd/inbox.org")
           "* Respond to %:fromname: %:subject\n%U\n\n  %a"
           :immediate-finish t
           :kill-buffer t)))

  ;; Override the areas of focus with our own
  (setq org-gtd-areas-of-focus '("work" "coding" "music" "adventure" "family" "health" "home" "life"))

  ;; Add asking for area of focus when processing inbox
  (setq org-gtd-organize-hooks '(org-set-tags-command org-gtd-set-area-of-focus)))

(defun my/save-buffers-after-processing-inbox (&rest _)
  "Save all buffers after processing inbox."
  (save-some-buffers t))

(advice-add 'org-gtd-process--stop :after #'my/save-buffers-after-processing-inbox)

;; Prompt for today's daily focus if not stored yet, otherwise get from file.
(defun my/org-gtd-get-daily-focus ()
  "Get or prompt for today's focus, stored in ~/org/gtd/focus.org."
  (let* ((today (format-time-string "%Y-%m-%d"))
         (focus-file (expand-file-name "focus.org" org-gtd-directory))
         (focus-text nil))
    ;; Try to read the focus from the file if it exists
    (when (file-exists-p focus-file)
      (with-temp-buffer
        (insert-file-contents focus-file)
        (goto-char (point-min))
        (when (re-search-forward (format "^\\* %s \\(.*\\)" (regexp-quote today)) nil t)
          (setq focus-text (match-string 1)))))
    ;; If not found, prompt user and append to the file
    (unless focus-text
      (setq focus-text (read-string "Set today's focus: "))
      (with-temp-buffer
        (when (file-exists-p focus-file)
          (insert-file-contents focus-file))
        (goto-char (point-max))
        (unless (bolp) (insert "\n"))
        (insert (format "* %s %s\n" today focus-text))
        (write-region (point-min) (point-max) focus-file)))
    focus-text))

(defun my/org-gtd-engage ()
  "Show custom GTD agenda view grouped by area of focus."
  (interactive)
  (org-gtd-core-prepare-agenda-buffers)
  (with-org-gtd-context
      ;; Step 1: get today's focus
      (let* ((daily-focus (my/org-gtd-get-daily-focus))

             ;; Step 2: create header block to display focus
             (focus-block
              `(tags "+FOCUS"
                ((org-agenda-overriding-header ,(format "Today's Focus 🎯: %s" daily-focus))
                 (org-agenda-ignore-drawer-properties t)
                 (org-agenda-skip-function (lambda () t)))))  ;; dummy block just to display header

             ;; Step 3: build remaining blocks
             (next-action-blocks
              (cl-loop for area in org-gtd-areas-of-focus
                       for matcher = (format "TODO=\"NEXT\"+CATEGORY=\"%s\"" area)
                       for entries = (org-map-entries (lambda () t) matcher 'agenda)
                       unless (null entries)
                       collect `(todo ,org-gtd-next
                                 ((org-agenda-overriding-header ,(format "%s Next Actions" (capitalize area)))
                                  (org-agenda-skip-function
                                   (lambda () (org-gtd-skip-unless-area-of-focus ,area)))))))

             (agenda-block
              `(agenda ""
                ((org-agenda-span 1)
                 (org-agenda-start-day nil)
                 (org-agenda-skip-additional-timestamps-same-entry t))))

             (project-block
              `(tags ,org-gtd-project-headings
                ((org-agenda-overriding-header "Active Projects")
                 (org-agenda-sorting-strategy '(category-down)))))

             (all-blocks (append (list agenda-block focus-block project-block) next-action-blocks))

             (org-agenda-custom-commands
              `(("x" "GTD Engage View"
                 ,all-blocks
                 ((org-agenda-buffer-name "*Org GTD Engage*"))))))
        (org-agenda nil "x")
        (goto-char (point-min)))))

(after! org-modern
  ;; Customize the symbols used for headlines
  (setq org-modern-hide-stars nil  ;; optional: show leading stars
        org-modern-star '(("◉" "○" "●" "○" "●" "○" "●"))
        org-modern-fold-icons
        '((t . "▸")
          (nil . "▾"))))

(use-package! olivetti
  :after org
  :config
  ;; Configure column width to 100
  (setq olivetti-body-width 100)
  (setq olivetti-style t)

  ;; Turn on olivetti mode which centers the content among other things
  :hook (org-mode . olivetti-mode))

(after! diff-hl
  (setq diff-hl-global-modes '(not image-mode pdf-view-mode org-mode)))

;; Enable org-habit to show up in agenda view
(use-package! org-habit
  :after org
  :config
  (setq org-habit-show-all-today t)
  (setq org-habit-graph-column 60))

(dolist (mode '(org-mode-hook
                term-mode-hook
                vterm-mode-hook
                shell-mode-hook
                treemacs-mode-hook
                eshell-mode-hook))
  (add-hook mode (lambda () (display-line-numbers-mode 0))))

(after! org
  ;; This is needed as of Org 9.2
  (require 'org-tempo)

  (add-to-list 'org-structure-template-alist '("sh" . "src shell"))
  (add-to-list 'org-structure-template-alist '("el" . "src emacs-lisp"))
  (add-to-list 'org-structure-template-alist '("ru" . "src rust")))

(defun pmf/org-indent-elisp-src-blocks ()
  "Indent all Emacs Lisp src blocks in the current Org buffer, then save."
  (interactive)
  (require 'ob) ;; ensure org-babel macros are loaded
  (save-excursion
    (org-babel-map-src-blocks nil ;; iterate over all babel blocks in current buffer
      (when (string= lang "emacs-lisp")
        (org-babel-do-in-edit-buffer
         (emacs-lisp-mode)
         (indent-region (point-min) (point-max)))))
    (save-buffer)))

(advice-add 'org-refile :after #'(lambda (&rest _) (org-save-all-org-buffers)))

(after! lsp-ui
  (setq lsp-ui-sideline-enable nil)
  (setq lsp-ui-sideline-show-hover nil))

(use-package! flycheck-posframe
  :after flycheck
  :hook (flycheck-mode . flycheck-posframe-mode)
  :config
  ;; thin white outline
  (setq flycheck-posframe-border-width 1
        flycheck-posframe-position 'point)
  (set-face-attribute 'flycheck-posframe-border-face nil :foreground "white")

  (defun pmf/flycheck-posframe-simple-padding ()
    (let* ((bg  (or (face-background 'flycheck-posframe-face nil t)
                    (face-background 'tooltip nil t)
                    (face-background 'default nil t)))
           (pad 10)) ;; padding thickness
      ;; padding: draw a box in the same color as the background
      (set-face-attribute 'flycheck-posframe-face nil
                          :box `(:line-width ,pad :color ,bg))
      ;; severity faces: inherit colors from error/warning/etc,
      ;; and the box from the base face (no color overrides)
      (dolist (pair '((flycheck-posframe-error-face   . error)
                      (flycheck-posframe-warning-face . warning)
                      (flycheck-posframe-info-face    . shadow)))
        (set-face-attribute (car pair) nil
                            :inherit (list (cdr pair) 'flycheck-posframe-face)
                            :foreground 'unspecified
                            :background 'unspecified
                            :box 'unspecified))))

  (add-hook 'doom-load-theme-hook #'pmf/flycheck-posframe-simple-padding)
  (pmf/flycheck-posframe-simple-padding))

(after! rustic
  (setq +tree-sitter-hl-enabled-modes '(rust-mode))
  (add-hook 'rust-mode-hook #'tree-sitter-mode)
  (add-hook 'rust-mode-hook #'tree-sitter-hl-mode)

  (setq lsp-enable-semantic-highlighting t)
  (add-hook 'lsp-mode-hook #'lsp-enable-which-key-integration)
  (add-hook 'lsp-mode-hook #'lsp-semantic-tokens-mode)

  (setq lsp-rust-analyzer-cargo-watch-command "clippy")
  (setq lsp-rust-clippy-preference "on")

  (defun my/rust-enable-format-on-save ()
    (add-hook 'before-save-hook #'lsp-format-buffer nil t))

  (add-hook 'rust-mode-hook #'my/rust-enable-format-on-save))

;; Custom function to run evxcr for rust repl functionality
(defun pmf/rust-evcxr-repl ()
  "Start or switch to an evcxr REPL."
  (interactive)
  (unless (executable-find "evcxr")
    (user-error "evcxr not found on PATH. `cargo install evcxr_repl` then `doom env`"))
  (let* ((buf-name "*evcxr*")
         (buf (get-buffer buf-name)))
    (if (and buf (comint-check-proc buf))
        (pop-to-buffer buf)
      (let ((default-directory (or (and (fboundp 'projectile-project-root)
                                        (projectile-project-root))
                                   default-directory)))
        (pop-to-buffer (make-comint-in-buffer "evcxr" buf-name "evcxr" nil))))))

(after! rustic
  ;; Tell Doom's +eval to use rustic's REPL in rustic-mode
  (set-repl-handler! 'rust-mode #'pmf/rust-evcxr-repl))

;; Setup for magit forge with rumble gitlab instance
(setq auth-sources '("~/.authinfo.gpg"))
(after! forge
  (require 'forge-gitlab)
  (push '("git.rumble.work"           ; GITHOST in he remote URL
          "gitlab.rumble.work/api/v4" ; APIHOST (your web instance + API path)
          "gitlab.rumble.work"        ; WEBHOST (used for browsing)
          forge-gitlab-repository)    ; CLASS
        forge-alist))

(setq epa-pinentry-mode 'loopback)
(setenv "GPG_TTY" (getenv "TTY"))

(add-hook 'prog-mode 'rainbow-delimiters-mode)

(eshell-git-prompt-use-theme 'powerline)

(use-package! org-jira
  :after org
  :config
  ;; Point at work jira
  (setq jiralib-url "https://seastead.atlassian.net")
  ;; These fields will break issue creation an updating as we don't have them.
  (setq jiralib-update-issue-fields-exclude-list '(priority components))

  ;; Map jira states back to known org todo states
  (setq org-jira-done-states '("Closed" "Resolved" "Done" "Cancelled"))
  (setq org-jira-jira-status-to-org-keyword-alist '(("To Do" . "TODO")
                                                    ("In Progress" . "STRT")
                                                    ("Done" . "DONE"))))

(after! org-jira
  ;; Add mapping in org mode for org-jira-todo-to-jira - this needs to be
  ;; accessible from within org-mode generally. All org-jira keybindings are
  ;; currently scoped by the library to only work in org-jira mode, which is only
  ;; enabled on org-jira.org style files (pulled issues)
  (map! :leader
;;; <leader> j --- jira
        (:prefix-map ("j" . "jira")
         :desc "Get issues" "g" #'org-jira-get-issues))

  ;; Add logic so that when we call org-jira-todo-to-jira we insert a link to the
  ;; org-jira ticket line back onto the original todo item.
  (defvar my/org-jira--origin-marker nil
    "Marker pointing to the original Org TODO that spawned the JIRA issue.")

  (defvar my/org-jira--original-heading-text nil
    "Backup of the original TODO heading and its body.")

  ;; Before advice: store point + full heading text
  (defun my/org-jira--store-todo-entry ()
    (setq my/org-jira--origin-marker (point-marker))
    (let ((start (org-back-to-heading t))
          (end (save-excursion (org-end-of-subtree t t))))
      (setq my/org-jira--original-heading-text
            (buffer-substring-no-properties start end))))

  (defun my/org-jira--restore-todo-with-link ()
    (let (link-path link-desc ticket-id)
      ;; Step 1: get JIRA link and ticket ID from ~/.org-jira/AUTH.org
      (with-current-buffer (find-file-noselect "~/.org-jira/AUTH.org")
        (goto-char (point-max))
        (when (re-search-backward "^\\*+ +TODO\\b" nil t)
          (org-back-to-heading t)
          (let* ((link (org-store-link nil))
                 (parsed (org-link-unescape link)))
            (when (string-match "\\[\\[\\(.*?\\)\\]\\[\\(.*?\\)\\]\\]" parsed)
              (setq link-path (match-string 1 parsed))
              (setq link-desc (match-string 2 parsed)))
            ;; Extract ticket ID from heading text (e.g., AUTH-211)
            (when (re-search-forward "\\(AUTH-[0-9]+\\)" (org-entry-end-position) t)
              (setq ticket-id (match-string 1))))))

      ;; Step 2: switch back to original buffer and insert
      (when (and my/org-jira--origin-marker
                 (marker-buffer my/org-jira--origin-marker))
        (let ((origin-buf (marker-buffer my/org-jira--origin-marker)))
          (when (buffer-live-p origin-buf)
            (with-current-buffer origin-buf
              (goto-char my/org-jira--origin-marker)
              (insert my/org-jira--original-heading-text)
              ;; Move to heading and insert ticket ID prefix if available

              (save-excursion
                (org-back-to-heading t)
                (let* ((components (org-heading-components))
                       (todo (nth 2 components))
                       (heading (nth 4 components)))
                  ;; Only update heading if ticket-id is not already present
                  (when (and ticket-id
                             (not (string-prefix-p (concat ticket-id ": ") heading)))
                    ;; Reconstruct the full headline safely
                    (org-edit-headline
                     (format "%s: %s" ticket-id heading)))))

              ;; Move to end of heading and insert backlink
              (save-excursion
                (goto-char (org-entry-end-position))
                (insert "Linked JIRA ticket: ")
                (when link-path
                  (org-insert-link nil link-path link-desc))
                (insert "\n")))
            (switch-to-buffer origin-buf)
            (goto-char my/org-jira--origin-marker)
            (recenter))))))

  (advice-add 'org-jira-todo-to-jira :before #'my/org-jira--store-todo-entry)
  (advice-add 'org-jira-todo-to-jira :after  #'my/org-jira--restore-todo-with-link))

;; This is a custom function and hook that does the following:
;; 1. Intercepts when forge-create-pullreq gets called
;; 2. Grabs the jira ticket from the current branch
;; 3. Inserts the tip commit contents in as the PR contents (similar behavior to gitlab)
;; 4. Injects a "Closes <jira-ticket-id>" line into the PR details
(with-eval-after-load 'forge
  (defun my/forge--populate-pr-if-buffer ()
    "When PR buffer appears, auto-fill with commit body and JIRA ID."
    (when (string= (buffer-name) "new-pullreq")
      (remove-hook 'post-command-hook #'my/forge--populate-pr-if-buffer)
      (let* ((commit-msg (string-trim-right
                          (magit-git-output "log" "-1" "--pretty=%B")))
             (branch-name (magit-get-current-branch))
             (jira-id (when (string-match "\\bAUTH-[0-9]+\\b" branch-name)
                        (match-string 0 branch-name)))
             (closes-line (when jira-id (concat "\n\nCloses " jira-id)))
             (full-msg (concat commit-msg closes-line)))
        (goto-char (point-min))
        (when (looking-at "^#\\s-*")
          (replace-match (concat "# " full-msg))))))

  (defun my/forge--setup-auto-pr-body ()
    "Temporarily watch for the PR buffer to appear."
    (add-hook 'post-command-hook #'my/forge--populate-pr-if-buffer))

  ;; Use a safe advice wrapper that ignores arguments
  (advice-add 'forge-create-pullreq :after
              (lambda (&rest _) (my/forge--setup-auto-pr-body))))

(use-package! slack
  :commands (slack-start)
  :bind (("C-c S K" . slack-stop)
         ("C-c S c" . slack-select-rooms)
         ("C-c S u" . slack-select-unread-rooms)
         ("C-c S U" . slack-user-select)
         ("C-c S m" . slack-im-open)
         ("C-c S s" . slack-search-from-messages)
         ("C-c S J" . slack-jump-to-browser)
         ("C-c S j" . slack-jump-to-app)
         ("C-c S e" . slack-insert-emoji)
         ("C-c S E" . slack-message-edit)
         ("C-c S r" . slack-message-add-reaction)
         ("C-c S t" . slack-thread-show-or-create)
         ("C-c S g" . slack-message-redisplay)
         ("C-c S G" . slack-conversations-list-update-quick)
         ("C-c S q" . slack-quote-and-reply)
         ("C-c S Q" . slack-quote-and-reply-with-link)
         ("C-c S T" . slack-all-threads)
         (:map slack-mode-map
               (("@" . slack-message-embed-mention)
                ("#" . slack-message-embed-channel)))
         (:map slack-thread-message-buffer-mode-map
               (("C-c '" . slack-message-write-another-buffer)
                ("@" . slack-message-embed-mention)
                ("#" . slack-message-embed-channel)))
         (:map slack-message-buffer-mode-map
               (("C-c '" . slack-message-write-another-buffer)))
         (:map slack-message-compose-buffer-mode-map
               (("C-c '" . slack-message-send-from-buffer)))
         )
  :config
  (slack-register-team
   :name "rumbleinc"
   :token (auth-source-pick-first-password
           :host "rumbleinc.slack.com"
           :user "peter.farr@rumble.com")
   :cookie (auth-source-pick-first-password
            :host "rumbleinc.slack.com"
            :user "peter.farr@rumble.com^cookie")
   :full-and-display-names t
   :default t
   :subscribed-channels '(rumble-sso-auth))

  (setq slack-block-highlight-source t))

(use-package alert
  :commands (alert)
  :init
  (setq alert-default-style 'notifier))

(after! mu4e
  ;; Each path is relative to the path of the maildir you passed to mu
  (set-email-account! "farr.peterm@gmail"
                      '((mu4e-sent-folder       . "/[Gmail].Sent Mail")
                        (mu4e-drafts-folder       . "/[Gmail].Drafts")
                        (mu4e-trash-folder       . "/[Gmail].Trash")
                        (mu4e-refile-folder       . "/[Gmail].All Mail")
                        (smtpmail-smtp-user     . "farr.peterm@gmail.com")
                        (mu4e-compose-signature . "Best,\nPeter Farr"))
                      t)

  ;; don't need to run cleanup after indexing for gmail
  (setq mu4e-index-cleanup nil
        ;; because gmail uses labels as folders we can use lazy check since
        ;; messages don't really "move"
        mu4e-index-lazy-check t)

  (setq
   user-mail-address "farr.peterm@gmail.com"
   user-full-name "Peter Farr"

   message-send-mail-function 'smtpmail-send-it
   send-mail-function 'smtpmail-send-it

   smtpmail-stream-type 'starttls
   smtpmail-smtp-server "smtp.gmail.com"
   smtpmail-smtp-service 587

   smtpmail-auth-supported '(login plain)
   smtpmail-smtp-user "farr.peterm@gmail.com"

   auth-sources '("~/.authinfo.gpg")

   smtpmail-debug-info t))

;; Make gc pauses faster by decreasing the threshold.
(setq gc-cons-threshold (* 2 1000 1000))
