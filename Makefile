#
# macOS generic kernel extension Makefile
#

KEXTNAME=example
KEXTVERSION=1.0.0
KEXTBUILD=1.0.0d1
BUNDLEDOMAIN=com.example

#
# Designed to be included from a Makefile which defines the following:
#
# KEXTNAME        Short name of the kext
# KEXTVERSION     Version number, see TN2420
# KEXTBUILD       Build number, see TN2420
# BUNDLEDOMAIN    The reverse DNS notation prefix
#
# Optionally, the Makefile can define the following:
#
# COPYRIGHT       Human-readable copyright
# SIGNCERT        Label of Developer ID cert in keyring for code signing
#                 NOTE: code signature will increase code size(18k)
#                 For ad-hoc signature  use single hyphen(e.g. -)
#
# ARCH            x86_64 (default) or i386
# PREFIX          Install/uninstall location; default /Library/Extensions
#
# BUNDLEID        KEXT bundle ID; default $(BUNDLEDOMAIN).kext.$(KEXTNAME)
# KEXTBUNDLE      Name of kext bundle directory; default $(KEXTNAME).kext
# KEXTMACHO       Name of kext Mach-O executable; default $(KEXTNAME)
#
# MACOSX_VERSION_MIN    Minimal version of macOS to target
#                       If you don't know  specify 10.4
#                       Default set to current system version
# SDKROOT         Apple Xcode SDK root directory to use
# CPPFLAGS        Additional precompiler flags
# CFLAGS          Additional compiler flags
#                 Example: -Wunknown-warning-option
#
# LDFLAGS         Additional linker flags
# LIBS            Additional libraries to link against
# KLFLAGS         Additional kextlibs flags
#                 Example: -unsupported
#

#
# Check mandatory vars
#
ifndef KEXTNAME
$(error KEXTNAME not defined)
endif

ifndef KEXTVERSION
ifdef KEXTBUILD
KEXTVERSION:=	$(KEXTBUILD)
else
$(error KEXTVERSION not defined)
endif
endif

ifndef KEXTBUILD
ifdef KEXTVERSION
KEXTBUILD:=	$(KEXTVERSION)
else
$(error KEXTBUILD not defined)
endif
endif

ifndef BUNDLEDOMAIN
$(error BUNDLEDOMAIN not defined)
endif


# defaults
BUNDLEID?=	$(BUNDLEDOMAIN).kext.$(KEXTNAME)
KEXTBUNDLE?=	$(KEXTNAME).kext
KEXTMACHO?=	$(KEXTNAME)
ARCH?=		x86_64
#ARCH?=		i386
PREFIX?=	/Library/Extensions

CODESIGN?=codesign

# Apple SDK
ifneq "" "$(SDKROOT)"
SDKFLAGS=	-isysroot $(SDKROOT)
CC=		$(shell xcrun -find -sdk $(SDKROOT) cc)
#CXX=		$(shell xcrun -find -sdk $(SDKROOT) c++)
CODESIGN=	$(shell xcrun -find -sdk $(SDKROOT) codesign)
endif

# standard defines and includes for kernel extensions
CPPFLAGS+=	-DKERNEL \
		-DKERNEL_PRIVATE \
		-DDRIVER_PRIVATE \
		-DAPPLE \
		-DNeXT \
		$(SDKFLAGS) \
		-I/System/Library/Frameworks/Kernel.framework/Headers \
		-I/System/Library/Frameworks/Kernel.framework/PrivateHeaders

#
# Convenience defines
# BUNDLEID macro will be used in KMOD_EXPLICIT_DECL
#
CPPFLAGS+=	-DKEXTNAME_S=\"$(KEXTNAME)\" \
		-DKEXTVERSION_S=\"$(KEXTVERSION)\" \
		-DKEXTBUILD_S=\"$(KEXTBUILD)\" \
		-DBUNDLEID_S=\"$(BUNDLEID)\" \
		-DBUNDLEID=$(BUNDLEID)

#
# C compiler flags
#
ifdef MACOSX_VERSION_MIN
CFLAGS+=	-mmacosx-version-min=$(MACOSX_VERSION_MIN)
endif
CFLAGS+=	-arch $(ARCH) \
		-fno-builtin \
		-fno-common \
		-mkernel

# warnings
CFLAGS+=	-Wall -Wextra

# linker flags
ifdef MACOSX_VERSION_MIN
LDFLAGS+=	-mmacosx-version-min=$(MACOSX_VERSION_MIN)
endif
LDFLAGS+=	-arch $(ARCH)
LDFLAGS+=	-nostdlib \
		-Xlinker -kext \
		-Xlinker -object_path_lto \
		-Xlinker -export_dynamic

# libraries
#LIBS+=		-lkmodc++
LIBS+=		-lkmod
LIBS+=		-lcc_kext

# kextlibs flags
KLFLAGS+=	-c -unsupported

# source, header, object and make files
SRCS:=		$(wildcard src/*.c)
HDRS:=		$(wildcard src/*.h)
OBJS:=		$(SRCS:.c=.o)
MKFS:=		$(wildcard Makefile)


# targets

all: $(KEXTBUNDLE)

%.o: %.c $(HDRS)
	$(CC) $(CPPFLAGS) $(CFLAGS) -c -o $@ $<

$(OBJS): $(MKFS)

$(KEXTMACHO): $(OBJS)
	$(CC) $(LDFLAGS) -static -o $@ $(LIBS) $^
	otool -h $@

Info.plist~: Info.plist.in
	sed \
		-e 's/__KEXTNAME__/$(KEXTNAME)/g' \
		-e 's/__KEXTMACHO__/$(KEXTMACHO)/g' \
		-e 's/__KEXTVERSION__/$(KEXTVERSION)/g' \
		-e 's/__KEXTBUILD__/$(KEXTBUILD)/g' \
		-e 's/__BUNDLEID__/$(BUNDLEID)/g' \
		-e 's/__OSBUILD__/$(shell /usr/bin/sw_vers -buildVersion)/g' \
		-e 's/__COPYRIGHT__/$(COPYRIGHT)/g' \
	$^ > $@

$(KEXTBUNDLE): $(KEXTMACHO) Info.plist~
	mkdir -p $@/Contents/MacOS
	mv $< $@/Contents/MacOS

	# Clear placeholders(o.w. kextlibs cannot parse)
	sed 's/__KEXTLIBS__//g' Info.plist~ > $@/Contents/Info.plist

	awk '/__KEXTLIBS__/{system("kextlibs -xml $(KLFLAGS) $@");next};1' Info.plist~ > $@/Contents/Info.plist~

	mv $@/Contents/Info.plist~ $@/Contents/Info.plist

	touch $@

ifdef SIGNCERT
	# TODO: support --timestamp option
	$(CODESIGN) --force --sign $(SIGNCERT) $@
endif

	dsymutil -o $<.kext.dSYM $@/Contents/MacOS/$<

load: $(KEXTBUNDLE)
	sudo chown -R root:wheel $<
	sudo sync
	sudo kextutil $<
	# restore original owner:group
	sudo chown -R '$(USER):$(shell id -gn)' $<
	sudo dmesg | grep $(KEXTNAME) | tail -1

stat:
	kextstat | grep $(KEXTNAME)

unload:
	sudo kextunload $(KEXTBUNDLE)
	sudo dmesg | grep $(KEXTNAME) | tail -2

install: $(KEXTBUNDLE) uninstall
	test -d "$(PREFIX)"
	sudo cp -pr $< "$(PREFIX)/$<"
	sudo chown -R root:wheel "$(PREFIX)/$<"

uninstall:
	test -d "$(PREFIX)"
	test -e "$(PREFIX)/$(KEXTBUNDLE)" && \
	sudo rm -rf "$(PREFIX)/$(KEXTBUNDLE)" || true

clean:
	rm -rf $(KEXTBUNDLE) $(KEXTBUNDLE).dSYM Info.plist~ $(OBJS) $(KEXTMACHO)

.PHONY: all load stat unload intall uninstall clean

