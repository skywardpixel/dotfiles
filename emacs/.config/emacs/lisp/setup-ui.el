(use-package doom-themes
             :ensure t
             :custom
             (doom-themes-enable-bold t)
             (doom-themes-enable-italic t)
             :config
             (load-theme 'doom-tokyo-night t))

(use-package doom-modeline
             :ensure t
             :init (doom-modeline-mode 1))

(setq inhibit-startup-message t)
(global-display-line-numbers-mode t)
(setq display-line-numbers-type 'relative)
(global-hl-line-mode t)
(when (member "Lilex Nerd Font" (font-family-list))
  (set-frame-font "Lilex Nerd Font-12" nil t))

(provide 'setup-ui)
