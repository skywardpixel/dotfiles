(setq treesit-font-lock-level 4)

(use-package lsp-mode
  :commands (lsp lsp-deferred)
  :init
  (setq lsp-keymap-prefix "C-c l") 
  :hook ((objc-mode . lsp)
         (go-mode . lsp)
         (python-mode . lsp)))

(use-package lsp-ui :commands lsp-ui-mode)

(provide 'setup-prog)
