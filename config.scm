;; This is an operating system configuration template
;; for a "desktop" setup without full-blown desktop
;; environments.

(use-modules 
  (gnu) 
  (gnu system nss) 
  ;; (gnu services xorg)
  (nongnu packages linux) 
  (nongnu system linux-initrd))

(use-service-modules desktop)

(use-package-modules bootloaders certs emacs emacs-xyz ratpoison suckless wm
                     xorg terminals)

(operating-system
  (kernel linux)
  (initrd microcode-initrd)
  (firmware (list linux-firmware))

  (host-name "guixsd")
  (timezone "Europe/Kiev")
  (locale "en_US.utf8")

  ;; Use the UEFI variant of GRUB with the EFI System
  ;; Partition mounted on /boot/efi.
  (bootloader (bootloader-configuration
                (bootloader grub-efi-bootloader)
                (target "/boot/efi")))

  ;; Assume the target root file system is labelled "my-root",
  ;; and the EFI System Partition has UUID 1234-ABCD.
  (file-systems (append
                 (list (file-system
                         (device (file-system-label "guixsd"))
                         (mount-point "/")
                         (type "ext4"))
                       (file-system
                         (device (file-system-label "ESP"))
                         (mount-point "/boot/efi")
                         (type "vfat")))
                 %base-file-systems))

  (users (cons (user-account
                (name "andriy")
                (comment "Andrii")
                (group "users")
                (supplementary-groups '("wheel" "netdev"
                                        "audio" "video")))
               %base-user-accounts))

  ;; Add a bunch of window managers; we can choose one at
  ;; the log-in screen with F1.
  (packages (append (list
                     ;; window managers
                     awesome ratpoison i3-wm i3status dmenu
                     emacs emacs-exwm emacs-desktop-environment
                     ;; terminal emulator
                     xterm alacritty
                     ;; for HTTPS access
                     nss-certs)
                    %base-packages))

  ;; Use the "desktop" services, which include the X11
  ;; log-in service, networking with NetworkManager, and more.
  (services %desktop-services)

  ;; (services
  ;;   (append
  ;;     (list
  ;;   (set-xorg-configuration
  ;;     (xorg-configuration
  ;;       (modules
  ;;         %default-xorg-modules)))
  ;;   %desktop-services)))


  ;; Allow resolution of '.local' host names with mDNS.
  (name-service-switch %mdns-host-lookup-nss))
