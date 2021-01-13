;; This is an operating system configuration template
;; for a "desktop" setup without full-blown desktop
;; environments.

(use-modules 
  (gnu) 
  (srfi srfi-1)
  (gnu system nss) 
  (gnu services xorg)
  (gnu services pm)
  (gnu services networking)
  (gnu services desktop)
  (gnu packages gnome) 
  (gnu packages linux)
  (gnu packages vim)
  (gnu packages gtk)
  (gnu packages xorg)
  (gnu packages emacs)
  (gnu packages audio)
  (gnu packages pulseaudio)
  (gnu packages version-control)
  (nongnu packages linux) 
  (nongnu system linux-initrd))

(use-service-modules desktop)

(use-package-modules bootloaders certs 
emacs wm
xorg terminals)

;; Allow members of the "video" group to change the screen brightness.
(define %backlight-udev-rule
  (udev-rule
   "90-backlight.rules"
   (string-append "ACTION==\"add\", SUBSYSTEM==\"backlight\", "
                  "RUN+=\"/run/current-system/profile/bin/chgrp video /sys/class/backlight/%k/brightness\""
                  "\n"
                  "ACTION==\"add\", SUBSYSTEM==\"backlight\", "
                  "RUN+=\"/run/current-system/profile/bin/chmod g+w /sys/class/backlight/%k/brightness\"")))

(define %my-desktop-services
  (modify-services %desktop-services
                   (elogind-service-type config =>
                                         (elogind-configuration (inherit config)
                                                                (handle-lid-switch-external-power 'suspend)))
                   (udev-service-type config =>
                                      (udev-configuration (inherit config)
                                                          (rules (cons %backlight-udev-rule
                                                                       (udev-configuration-rules config)))))
                   (network-manager-service-type config =>
                                                 (network-manager-configuration (inherit config)
                                                                                (vpn-plugins (list network-manager-openvpn))))))

(define %xorg-libinput-config
  "Section \"InputClass\"
  Identifier \"Touchpads\"
  Driver \"libinput\"
  MatchDevicePath \"/dev/input/event*\"
  MatchIsTouchpad \"on\"

  Option \"Tapping\" \"on\"
  Option \"TappingDrag\" \"on\"
  Option \"DisableWhileTyping\" \"on\"
  Option \"MiddleEmulation\" \"on\"
  Option \"ScrollMethod\" \"twofinger\"
EndSection
Section \"InputClass\"
  Identifier \"Keyboards\"
  Driver \"libinput\"
  MatchDevicePath \"/dev/input/event*\"
  MatchIsKeyboard \"on\"
EndSection
")

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
                         (type "btrfs")
                         (options "subvol=@"))
                       (file-system
                         (device (file-system-label "guixsd"))
                         (mount-point "/home")
                         (type "btrfs")
                         (options "subvol=@home"))
                       (file-system
                         (device (file-system-label "guixsd"))
                         (mount-point "/gnu")
                         (type "btrfs")
                         (options "subvol=@gnu"))
                       (file-system
                         (device (file-system-label "guixsd"))
                         (mount-point "/var")
                         (type "btrfs")
                         (options "subvol=@var"))
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
                     awesome 
                     ;; editors
                     emacs vim
                     ;; terminal emulators
                     xterm alacritty
                     ;; tools
                     git gvfs
                     ;; misc
                     bluez bluez-alsa
                     pulseaudio tlp
                     xf86-input-libinput
                     ;; for HTTPS access
                     nss-certs)
                    %base-packages))

  ;; Use the "desktop" services, which include the X11
  ;; log-in service, networking with NetworkManager, and more.
  ;; (services %desktop-services)

  (services (cons* (service slim-service-type
                            (slim-configuration
                              (xorg-configuration
                                (xorg-configuration
                                  ;; (keyboard-layout keyboard-layout)
                                  (extra-config (list %xorg-libinput-config))))))
                   (service tlp-service-type
                            (tlp-configuration
                              (cpu-boost-on-ac? #t)
                              (wifi-pwr-on-bat? #t)))
                   (pam-limits-service ;; This enables JACK to enter realtime mode
                     (list
                       (pam-limits-entry "@realtime" 'both 'rtprio 99)
                       (pam-limits-entry "@realtime" 'both 'memlock 'unlimited)))
                   (service thermald-service-type)
                   ;; (service docker-service-type)
                   ;; (service libvirt-service-type
                   ;;          (libvirt-configuration
                   ;;            (unix-sock-group "libvirt")
                   ;;            (tls-port "16555")))
                   ;; (service cups-service-type
                   ;;          (cups-configuration
                   ;;            (web-interface? #t)
                   ;;            (extensions
                   ;;              (list cups-filters))))
                   ;; (service nix-service-type)
                   (bluetooth-service #:auto-enable? #t)
                   (remove (lambda (service)
                             (eq? (service-kind service) gdm-service-type))
                           %my-desktop-services)))

  ;; Allow resolution of '.local' host names with mDNS.
  (name-service-switch %mdns-host-lookup-nss))
