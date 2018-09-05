### Makefile for macOS generic kernel extension

---

#### Summary

`Makefile` is a GNU makefile used to build macOS generic kernel extension without heavy XCode intervention.

#### Build variables

Mandatary:

- *KEXTNAME* - Short name for the kext(e.g. example)

- *KEXTVERSION* - Version number, see TN2420(e.g. 1.0.0)

- *KEXTBUILD* - Build number, see TN2420(e.g. 1.0.0d1)

- *BUNDLEDOMAIN* - Reverse DNS notation prefix(e.g. com.example)

Optional:

- *COPYRIGHT* - Human-readable copyright

- *SIGNCERT* - Label of Developer ID cert in keyring for code signing.

 For ad-hoc signature  use single hyphen(e.g. -)
 
- *ARCH* - x86_64 (default) or i386

- *PREFIX* - Install/uninstall location; default */Library/Extensions*



---

### References:

https://github.com/droe/example.kext

https://developer.apple.com/library/archive/technotes/tn2420/_index.html

https://developer.apple.com/library/archive/technotes/tn2459/_index.html

https://developer.apple.com/library/archive/documentation/Darwin/Conceptual/KEXTConcept/Articles/infoplist_keys.html

