#
# macOS generic kernel extension Makefile
#

KEXTNAME=example
KEXTVERSION=1.0.0
KEXTBUILD=1.0.0d1
BUNDLEDOMAIN=com.example

# for creating a signed kext
#SIGNCERT=	"your Apple Developer ID certificate label"

# for using unsupported interfaces not part of the supported KPI
#CFLAGS=	-Wno-\#warnings
#KLFLAGS=	-unsupported

# Designed to be included from a Makefile which defines the following:
#
# KEXTNAME        short name of the kext (e.g. example)
# KEXTVERSION     version number, cf TN2420 (e.g. 1.0.0)
# KEXTBUILD       build number, cd TN2420 (e.g. 1.0.0d1)
# BUNDLEDOMAIN    the reverse DNS notation prefix (e.g. com.example)
#
# Optionally, the Makefile can define the following:
#
# SIGNCERT        label of Developer ID cert in keyring for code signing
# ARCH            x86_64 (default) or i386
# PREFIX          install/uninstall location; default /Library/Extensions/
#
# BUNDLEID        kext bundle ID; default $(BUNDLEDOMAIN).kext.$(KEXTNAME)
# KEXTBUNDLE      name of kext bundle directory; default $(KEXTNAME).kext
# KEXTMACHO       name of kext Mach-O executable; default $(KEXTNAME)
#
# MACOSX_VERSION_MIN  minimal version of macOS to target
# SDKROOT         Apple Xcode SDK root directory to use
# CPPFLAGS        additional precompiler flags
# CFLAGS          additional compiler flags
# LDFLAGS         additional linker flags
# LIBS            additional libraries to link against
# KLFLAGS         additional kextlibs flags

# check mandatory vars

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
PREFIX?=	/Library/Extensions/

CODESIGN?=	codesign

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

# convenience defines
CPPFLAGS+=	-DKEXTNAME_S=\"$(KEXTNAME)\" \
		-DKEXTVERSION_S=\"$(KEXTVERSION)\" \
		-DKEXTBUILD_S=\"$(KEXTBUILD)\" \
		-DBUNDLEID_S=\"$(BUNDLEID)\" \
		-DBUNDLEID=$(BUNDLEID) \

# c compiler flags
ifdef MACOSX_VERSION_MIN
CFLAGS+=	-mmacosx-version-min=$(MACOSX_VERSION_MIN)
endif
CFLAGS+=	-arch $(ARCH) \
		-fno-builtin \
		-fno-common \
		-mkernel \
		-msoft-float

# warnings
CFLAGS+=	-Wall -Wextra -g

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
SRCS:=		$(wildcard *.c)
HDRS:=		$(wildcard *.h)
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
	$^ > $@

$(KEXTBUNDLE): $(KEXTMACHO) Info.plist~
	mkdir -p $@/Contents/MacOS
	cp $< $@/Contents/MacOS

	sed -e 's/__LIBS__//g' Info.plist~ > $@/Contents/Info.plist

	# TODO: replace evil system(3)
	cat Info.plist~ \
	| awk '/__LIBS__/ {system("kextlibs -xml $(KLFLAGS) $@");next}1' \
	>$@/Contents/Info.plist~

	mv $@/Contents/Info.plist~ $@/Contents/Info.plist

	touch $@

ifdef SIGNCERT
	# TODO: support --timestamp option
	$(CODESIGN) --force --sign $(SIGNCERT) $(KEXTBUNDLE)
endif

	dsymutil -o $<.kext.dSYM $@/Contents/MacOS/$<

load: $(KEXTBUNDLE)
	sudo chown -R root:wheel $<
	sudo sync
	sudo kextutil $<
	sudo chown -R '$(USER):$(shell id -gn)' $<
	sudo dmesg | grep $(KEXTNAME) | tail -1

stat:
	kextstat | grep $(KEXTNAME)

unload:
	sudo kextunload $(KEXTBUNDLE)

install: $(KEXTBUNDLE) uninstall
	test -d "$(PREFIX)"
	sudo cp -pr $< "$(PREFIX)/$<"
	sudo chown -R root:wheel "$(PREFIX)/$<"

uninstall:
	test -d "$(PREFIX)"
	test -e "$(PREFIX)/$(KEXTBUNDLE)" && \
	sudo rm -rf "$(PREFIX)/$(KEXTBUNDLE)" || true

clean:
	rm -rf $(KEXTBUNDLE) $(KEXTBUNDLE).dSYM $(KEXTMACHO) Info.plist~ $(OBJS)

.PHONY: all load stat unload intall uninstall clean

