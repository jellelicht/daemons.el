;;; services.el --- UI for managing init system services -*- lexical-binding: t -*-

;; Copyright (c) 2018 Chris Bowdon
;;
;; Author: Chris Bowdon
;; URL: https://github.com/cbowdon/services-mode
;;
;; This file is not part of GNU Emacs.
;;
;;; License: GPLv3
;;
;; Created: February 13, 2018
;; Modified: February 13, 2018
;; Version: 0.0.1
;; Keywords: startup screen tools
;; Package-Requires: ((emacs "25.3")
;;
;;; Commentary:
;; A UI for managing init system services.

;;; Code:


(require 'seq)

;; declarations
(defconst services--list-buffer-name "*services*")
(defconst services--output-buffer-name "*services-output*")

(defgroup services-mode-customization-group nil "Customization group for Services mode")

(defcustom services-always-sudo nil
  "Whether to always attempt to sudo up in services-mode.
This defaults to off because in some systems at least you can query status
without special privileges and will be prompted for a root password if you try
anything else. But at other times it's much more convenient to just assume sudo
powers when the buffer loads and enact everything as root.

Security wise - off is safer of course, to avoid unnecessary privilege."
  :type 'boolean
  :group 'services-mode-customization-group)

(defcustom services-do-no-evil t
  "Whether to add services-mode(s) to evil-emacs-state-modes.
This is the author's preference - it's a special mode and these are ergonomic
enough that it's not worth choosing new bindings. But the choice is yours."
  :type 'boolean
  :group 'services-mode-customization-group)

;; to be defined for each init system
(defvar services--commands-alist nil "Services commands alist")
(defvar services--list-fun nil "Function to list all services")

(defvar services-mode-map nil "Keymap for services mode")

(defvar services-list nil "List of current system services")

;; defuns
(defun split-lines (string)
  "Split STRING Into list of lines."
  (split-string string "[\n\r]+" t))

(defun services--list-all ()
  (funcall services--list-fun))

(defun services--run (command)
  "Run the given service COMMAND. Show results in a temporary buffer."
  (let ((service-name (tabulated-list-get-id))
        (command-fun (alist-get command services--commands-alist)))
    (when (not command-fun)
      (error "No such service command: %s" command))
    (with-current-buffer (get-buffer-create services--output-buffer-name)
      (setq buffer-read-only nil)
      (delete-region (point-min) (point-max))
      (insert (concat
               (propertize (format "Output of `%s` on `%s`:" command service-name) 'face 'underline)
               "\n\n"))
      (shell-command (funcall command-fun service-name) t)
      (services-output-mode))
    (switch-to-buffer-other-window services--output-buffer-name)))

(defun services-status-at-point () (interactive) (services--run 'status))
(defun services-show-at-point () (interactive) (services--run 'show))
(defun services-start-at-point () (interactive) (services--run 'start))
(defun services-stop-at-point () (interactive) (services--run 'stop))
(defun services-restart-at-point () (interactive) (services--run 'restart))
(defun services-reload-at-point () (interactive) (services--run 'reload))

;; Start by supporting systemd
(load-file "./services-systemd.el")

;; assignments
(setq services-mode-map
      (let ((map (make-sparse-keymap)))
        (define-key map (kbd "RET") 'services-status-at-point)
        (define-key map (kbd "s") 'services-start-at-point)
        (define-key map (kbd "S") 'services-stop-at-point)
        (define-key map (kbd "R") 'services-restart-at-point)
        (define-key map (kbd "r") 'services-reload-at-point)
        map))

;; mode definitions
(defun services-mode-refresh ()
  "Refresh the list of services."
  (setq tabulated-list-entries 'services--list-all))

(define-derived-mode services-mode tabulated-list-mode
  "Services"
  "UI for viewing and controlling system services"
  :group 'services-mode-customization-group
  (setq tabulated-list-format [("Service" 60 t)
                               ("Enabled" 40 t)]
        tabulated-list-padding 2)
  (add-hook 'tabulated-list-revert-hook 'services-mode-refresh)
  (tabulated-list-init-header))

(defun services ()
  (interactive)
  (let ((list-buffer (get-buffer-create services--list-buffer-name)))
    (with-current-buffer list-buffer
      (display-buffer-pop-up-window list-buffer nil)
      (switch-to-buffer-other-window list-buffer)
      (when services-always-sudo
        ;; Become root, but hang out in a temp dir to minimise damage potential
        (let ((tempdir (shell-command-to-string "mktemp -d")))
          (cd (format "/sudo::%s" tempdir))))
      (services-mode)
      (services-mode-refresh)
      (tabulated-list-print t t))))

(define-derived-mode services-output-mode special-mode
  "Services Output"
  "Mode for displaying output of Services commands"
  :group 'services-mode-customization-group)

;; evil
(when (and services-do-no-evil
           (boundp 'evil-emacs-state-modes)
           (not (memq 'services-mode evil-emacs-state-modes)))
  (add-to-list 'evil-emacs-state-modes 'services-mode)
  (add-to-list 'evil-emacs-state-modes 'services-output-mode))

(provide 'services)
