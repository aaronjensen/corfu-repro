(defvar elpaca-installer-version 0.7)
(defvar elpaca-directory (expand-file-name "elpaca/" user-emacs-directory))
(defvar elpaca-builds-directory (expand-file-name "builds/" elpaca-directory))
(defvar elpaca-repos-directory (expand-file-name "repos/" elpaca-directory))
(defvar elpaca-order '(elpaca :repo "https://github.com/progfolio/elpaca.git"
                              :ref nil :depth 1
                              :files (:defaults "elpaca-test.el" (:exclude "extensions"))
                              :build (:not elpaca--activate-package)))
(let* ((repo  (expand-file-name "elpaca/" elpaca-repos-directory))
       (build (expand-file-name "elpaca/" elpaca-builds-directory))
       (order (cdr elpaca-order))
       (default-directory repo))
  (add-to-list 'load-path (if (file-exists-p build) build repo))
  (unless (file-exists-p repo)
    (make-directory repo t)
    (when (< emacs-major-version 28) (require 'subr-x))
    (condition-case-unless-debug err
        (if-let ((buffer (pop-to-buffer-same-window "*elpaca-bootstrap*"))
                 ((zerop (apply #'call-process `("git" nil ,buffer t "clone"
                                                 ,@(when-let ((depth (plist-get order :depth)))
                                                     (list (format "--depth=%d" depth) "--no-single-branch"))
                                                 ,(plist-get order :repo) ,repo))))
                 ((zerop (call-process "git" nil buffer t "checkout"
                                       (or (plist-get order :ref) "--"))))
                 (emacs (concat invocation-directory invocation-name))
                 ((zerop (call-process emacs nil buffer nil "-Q" "-L" "." "--batch"
                                       "--eval" "(byte-recompile-directory \".\" 0 'force)")))
                 ((require 'elpaca))
                 ((elpaca-generate-autoloads "elpaca" repo)))
            (progn (message "%s" (buffer-string)) (kill-buffer buffer))
          (error "%s" (with-current-buffer buffer (buffer-string))))
      ((error) (warn "%s" err) (delete-directory repo 'recursive))))
  (unless (require 'elpaca-autoloads nil t)
    (require 'elpaca)
    (elpaca-generate-autoloads "elpaca" repo)
    (load "./elpaca-autoloads")))
(add-hook 'after-init-hook #'elpaca-process-queues)
(elpaca `(,@elpaca-order))

(elpaca elpaca-use-package
  ;; Enable use-package :ensure support for Elpaca.
  (elpaca-use-package-mode))

(setq tab-always-indent 'complete)

(use-package corfu
  :ensure t
  :demand t

  :config
  (setq corfu-quit-no-match 'separator
        corfu-preselect 'prompt)

  (global-corfu-mode)

  (setq debug-on-error t)
  (defadvice corfu--post-command (around intercept activate)
    (condition-case err
        ad-do-it
      ((debug error) (signal (car err) (cdr err))))))

(use-package corfu-prescient
  :after corfu
  :ensure t
  :demand t
  :config
  (corfu-prescient-mode))

(use-package lsp-mode
  :ensure t
  :demand t
  :hook ((js-mode . (lambda ()
                      (lsp)))
         (lsp-completion-mode . (lambda ()
                                  (setq completion-at-point-functions '(aj-capf-lsp)))))
  :init
  (setq lsp-completion-provider :none))

(use-package ripgrep-capf
  :demand t
  :ensure (:host github :repo "aaronjensen/ripgrep-capf" :protocol ssh))

(use-package cape
  :after corfu
  :ensure t
  :demand t
  :config
  (defalias 'aj-capf-lsp (cape-capf-super #'lsp-completion-at-point #'ripgrep-capf)))
