(define-module (guix-channel packages virtualbox)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (gnu packages linux)
  #:use-module (gnu packages backup)
  #:use-module (gnu packages base)
  #:use-module (guix build-system linux-module)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix gexp))

;; Based on
;; https://gitlab.com/nonguix/nonguix/blob/master/nongnu/packages/linux.scm
(define-public linux-vbox
  (package
    (inherit linux-libre)
    (name "linux-vbox")
    (version "5.2.1")
    (source (origin
              (method url-fetch)
              (uri (string-append
                   "https://cdn.kernel.org/pub/linux/kernel/v5.x/linux-"
                   version ".tar.xz"))
              (sha256
               (base32
                "01k5v3kdwk65cfx6bw4cl32jbfvf976jbya7q4a8lab3km7fi09m"))))
    (native-inputs
     `(("kconfig" ,(local-file "linux-vbox.config"))
       ,@(alist-delete "kconfig" (package-native-inputs linux-libre))))
    (synopsis "Vanilla Linux kernel configured for use as a VirtualBox guest")
    (description "Linux is an operating system kernel.  This version is \
configured specifically to run as a VirtualBox guest.")
    (license license:gpl2)
    (home-page "https://www.kernel.org")))

(define-public vbox-guest-additions
  (package
   (name "vbox-guest-additions")
   (version "6.1.34")
   (source (origin
            (method url-fetch)
            (uri (string-append
                  "https://download.virtualbox.org/virtualbox/"
                  version "/VBoxGuestAdditions_" version ".iso"))
            (sha256
             (base32
              "0yr5hwd1k087r0zyg8skxzw5yhlc3alvf56ph1y6l2wpwsh6zy48"))))
   (native-inputs
    `(("libarchive" ,libarchive))) ;; for bsdtar to extract from an iso
   (build-system linux-module-build-system)
   (arguments
    `(#:linux ,linux-vbox
      #:tests? #f
      #:phases
      (modify-phases %standard-phases
        (replace 'unpack
          (lambda _
            (let ((source (assoc-ref %build-inputs "source")))
              ;; Extract VBoxLinuxAdditions.run from the iso
              (invoke "bsdtar" "vxf" source "--include" "VBoxLinuxAdditions.run")
              ;; Extract the data from VBoxLinuxAdditions.run
              (system "\
OFFSET=`grep -oba 'ustar  ' VBoxLinuxAdditions.run | head -1 | cut -d : -f 1`; \
OFFSET=`expr $OFFSET - 257`; \
dd if=VBoxLinuxAdditions.run bs=4M | \
  ( dd bs=$OFFSET of=/dev/null count=1; dd bs=4M ) | \
  bsdtar vxf - --include VBoxGuestAdditions-amd64.tar.bz2")
              (invoke "bsdtar" "vxf" "VBoxGuestAdditions-amd64.tar.bz2"
                      "--include" "src")
              (chdir (string-append "src/vboxguest-" ,version))
              #t)))
        (delete 'configure)
        (replace 'build
          (lambda _
            (let ((kern-dir (string-append
                              (assoc-ref %build-inputs "linux-module-builder")
                              "/lib/modules/build"))
                  (kern-ver ,(package-version linux-vbox)))
              (invoke "make"
                       (string-append "KERN_DIR=" kern-dir)
                       (string-append "KERN_VER=" kern-ver))
              #t)))
        (replace 'install
          (lambda _
            (let ((module-dir (string-append %output "/lib/modules/"
                                            ,(package-version linux-vbox)
                                            "/extra/")))
              (for-each (lambda (file) (install-file file module-dir))
                        (list "vboxguest.ko" "vboxsf.ko" "vboxvideo.ko"))
              #t))))))
   (home-page "https://www.virtualbox.org")
   (synopsis "Guest additions modules from VirtualBox")
   (description "This package contains VirtualBox guest additions modules to \
support extended functionality in the guest OS.")
   (license license:gpl2)))

;; For local testing
;;linux-vbox
;;vbox-guest-additions
