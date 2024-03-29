# Created by: Jyun-Yan You <jyyou@cs.nctu.edu.tw>
# $FreeBSD: head/lang/rust/Makefile 508994 2019-08-15 14:30:16Z tobik $

PORTNAME=	rust
PORTVERSION?=	1.37.0
PORTREVISION?=	0
CATEGORIES=	lang
MASTER_SITES=	https://static.rust-lang.org/dist/:src \
		https://static.rust-lang.org/dist/:rust_bootstrap \
		LOCAL/tobik/rust:rust_bootstrap \
		https://static.rust-lang.org/dist/:cargo_bootstrap \
		LOCAL/tobik/rust:cargo_bootstrap
DISTNAME?=	${PORTNAME}c-${PORTVERSION}-src
DISTFILES?=	${NIGHTLY_SUBDIR}${DISTNAME}${EXTRACT_SUFX}:src \
		${RUSTC_BOOTSTRAP}${BOOTSTRAPS_SUFFIX}.tar.gz:rust_bootstrap \
		${RUST_STD_BOOTSTRAP}${BOOTSTRAPS_SUFFIX}.tar.gz:rust_bootstrap \
		${CARGO_BOOTSTRAP}${BOOTSTRAPS_SUFFIX}.tar.gz:cargo_bootstrap
DIST_SUBDIR?=	rust
EXTRACT_ONLY?=	${DISTFILES:N*\:*bootstrap:C/:.*//}

MAINTAINER=	rust@FreeBSD.org
COMMENT=	Language with a focus on memory safety and concurrency

LICENSE=	APACHE20 \
		MIT
LICENSE_COMB=	dual
LICENSE_FILE_APACHE=	${WRKSRC}/LICENSE-APACHE
LICENSE_FILE_MIT=	${WRKSRC}/LICENSE-MIT

BUILD_DEPENDS=		cmake:devel/cmake
LIB_DEPENDS=		libcurl.so:ftp/curl \
			libgit2.so:devel/libgit2 \
			libssh2.so:security/libssh2

ONLY_FOR_ARCHS?=	aarch64 amd64 armv6 armv7 i386 powerpc64
ONLY_FOR_ARCHS_REASON=	requires prebuilt bootstrap compiler

CONFLICTS_INSTALL?=	rust-nightly

# See WRKSRC/src/stage0.txt for this date and version values.
BOOTSTRAPS_DATE?=		2019-07-04
BOOTSTRAPS_SUFFIX?=		${BOOTSTRAPS_SUFFIX_${ARCH}}
BOOTSTRAPS_SUFFIX_powerpc64?=	-elfv1

RUST_BOOTSTRAP_VERSION?=	1.36.0
RUSTC_BOOTSTRAP=		${BOOTSTRAPS_DATE_${ARCH}:U${BOOTSTRAPS_DATE}}/rustc-${RUST_BOOTSTRAP_VERSION_${ARCH}:U${RUST_BOOTSTRAP_VERSION}}-${RUST_TARGET}
RUST_STD_BOOTSTRAP=		${BOOTSTRAPS_DATE_${ARCH}:U${BOOTSTRAPS_DATE}}/rust-std-${RUST_BOOTSTRAP_VERSION_${ARCH}:U${RUST_BOOTSTRAP_VERSION}}-${RUST_TARGET}

CARGO_BOOTSTRAP_VERSION?=	0.37.0
CARGO_BOOTSTRAP=		${BOOTSTRAPS_DATE_${ARCH}:U${BOOTSTRAPS_DATE}}/cargo-${CARGO_BOOTSTRAP_VERSION_${ARCH}:U${CARGO_BOOTSTRAP_VERSION}}-${RUST_TARGET}

CARGO_VENDOR_DIR?=		${WRKSRC}/vendor

# Rust's target arch string is different from *BSD arch strings
RUST_ARCH_aarch64=	aarch64
RUST_ARCH_amd64=	x86_64
RUST_ARCH_armv6=	armv6
RUST_ARCH_armv7=	armv7
RUST_ARCH_i386=		i686
RUST_ARCH_powerpc64=	powerpc64
RUST_ARCH_x86_64=	x86_64 # dragonfly
RUST_TARGET=		${RUST_ARCH_${ARCH}}-unknown-${OPSYS:tl}
LLVM_TARGET=		${ARCH:C/armv.*/ARM/:S/aarch64/AArch64/:S/powerpc64/PowerPC/}
PLIST_SUB+=		RUST_TARGET=${RUST_TARGET}

USES=		compiler gmake libedit pkgconfig python:2.7,build ssl tar:xz

OPTIONS_DEFINE=		DOCS GDB SOURCES
GDB_DESC=		Install ports gdb (necessary for debugging rust programs)
SOURCES_DESC=		Install source files

GDB_RUN_DEPENDS=		${LOCALBASE}/bin/gdb:devel/gdb

PLIST_FILES=		lib/rustlib/components \
			lib/rustlib/rust-installer-version

.include <bsd.port.pre.mk>

.if ${ARCH} == powerpc64 && !exists(/usr/bin/clang)
# The bootstrap is hardcoded to use gcc8
# but we can build with a newer or older compiler as provided by USE_GCC=yes
BUILD_DEPENDS+=	gcc8:lang/gcc8
USE_GCC=	yes
EXTRA_PATCHES=	${PATCHDIR}/extra-patch-ppc64-gcc
.endif

.if ${OPSYS} == FreeBSD && ${ARCH} == aarch64 && \
	(${OSVERSION} < 1200502 || \
	(${OSVERSION} > 1300000 && ${OSVERSION} < 1300006))
IGNORE=	fails to run due to a bug in rtld, update to 12-STABLE r342847 or 13-CURRENT r342113
.endif

.ifdef QEMU_EMULATING
IGNORE=	fails to build with qemu-user-static
.endif

X_PY_ENV=	HOME="${WRKDIR}" \
		LIBGIT2_SYS_USE_PKG_CONFIG=1 \
		LIBSSH2_SYS_USE_PKG_CONFIG=1 \
		OPENSSL_DIR="${OPENSSLBASE}"
X_PY_CMD=	${PYTHON_CMD} ${WRKSRC}/x.py

post-extract:
	@${MKDIR} ${WRKSRC}/build/cache/${BOOTSTRAPS_DATE_${ARCH}:U${BOOTSTRAPS_DATE}}
	${LN} -sf ${DISTDIR}/${DIST_SUBDIR}/${RUSTC_BOOTSTRAP}${BOOTSTRAPS_SUFFIX}.tar.gz \
		${WRKSRC}/build/cache/${RUSTC_BOOTSTRAP}.tar.gz
	${LN} -sf ${DISTDIR}/${DIST_SUBDIR}/${RUST_STD_BOOTSTRAP}${BOOTSTRAPS_SUFFIX}.tar.gz \
		${WRKSRC}/build/cache/${RUST_STD_BOOTSTRAP}.tar.gz
	${LN} -sf ${DISTDIR}/${DIST_SUBDIR}/${CARGO_BOOTSTRAP}${BOOTSTRAPS_SUFFIX}.tar.gz \
		${WRKSRC}/build/cache/${CARGO_BOOTSTRAP}.tar.gz

post-patch:
	@${REINPLACE_CMD} 's,gdb,${LOCALBASE}/bin/gdb,' ${WRKSRC}/src/etc/rust-gdb
	@${ECHO_MSG} "Canonical bootstrap date and version before patching:"
	@${GREP} -E '^(date|rustc|cargo)' ${WRKSRC}/src/stage0.txt
# If we override the versions and date of the bootstraps (for instance
# on aarch64 where we provide our own bootstraps), we need to update
# places where they are recorded.
	@${REINPLACE_CMD} -e 's,^date:.*,date: ${BOOTSTRAPS_DATE_${ARCH}:U${BOOTSTRAPS_DATE}},' \
		-e 's,^rustc:.*,rustc: ${RUST_BOOTSTRAP_VERSION_${ARCH}:U${RUST_BOOTSTRAP_VERSION}},' \
		-e 's,^cargo:.*,cargo: ${CARGO_BOOTSTRAP_VERSION_${ARCH}:U${CARGO_BOOTSTRAP_VERSION}},' \
		${WRKSRC}/src/stage0.txt
	@${ECHO_MSG} "Bootstrap date and version after patching:"
	@${GREP} -E '^(date|rustc|cargo)' ${WRKSRC}/src/stage0.txt
# Disable vendor checksums
	@${REINPLACE_CMD} 's,"files":{[^}]*},"files":{},' \
		${CARGO_VENDOR_DIR}/*/.cargo-checksum.json
.if ${ARCH} == powerpc64 && exists(/usr/bin/clang)
	@${REINPLACE_CMD} -e \
		's|Endian::Big => ELFv1|Endian::Big => ELFv2|' \
		${WRKSRC}/src/librustc_target/abi/call/powerpc64.rs
	@${REINPLACE_CMD} -e \
		's|powerpc64-unknown-freebsd|powerpc64-unknown-freebsd13.0|' \
		${WRKSRC}/src/librustc_target/spec/powerpc64_unknown_freebsd.rs
#.endif

post-patch-SOURCES-off:
# Mimic tools in config.toml with just src excluded
	@${REINPLACE_CMD} -e 's/config.tools.*"src".*/false;/' \
		${WRKSRC}/src/bootstrap/install.rs

.if defined(WITH_CCACHE_BUILD) && !defined(NO_CCACHE) && !defined(NOCCACHE)
CCACHE_VALUE=	"${CCACHE_WRAPPER_PATH:C,/libexec/ccache$,,}/bin/ccache"
.else
CCACHE_VALUE=	false
.endif

do-configure:
	${SED} -E \
		-e 's,%PREFIX%,${PREFIX},' \
		-e 's,%SYSCONFDIR%,${PREFIX}/etc,' \
		-e 's,%MANDIR%,${MANPREFIX}/man,' \
		-e 's,%PYTHON_CMD%,${PYTHON_CMD},' \
		-e 's,%CHANNEL%,${PKGNAMESUFFIX:Ustable:S/^-//},' \
		-e 's,%TARGET%,${RUST_TARGET},' \
		-e 's,%CCACHE%,${CCACHE_VALUE},' \
		-e 's,%CC%,${CC},' \
		-e 's,%CXX%,${CXX},' \
		< ${FILESDIR}/config.toml \
		> ${WRKSRC}/config.toml
# no need to build a crosscompiler for these targets
.if ${ARCH} == aarch64 || ${ARCH} == armv6 || ${ARCH} == armv7 || ${ARCH} == powerpc64
	@${REINPLACE_CMD} -e 's,^#targets =.*,targets = "${LLVM_TARGET}",' \
		-e 's,^#experimental-targets =.*,experimental-targets = "",' \
		${WRKSRC}/config.toml
.endif
	@${REINPLACE_CMD} -e 's,%CC%,${CC},g' \
		${WRKSRC}/src/librustc_llvm/build.rs \
		${WRKSRC}/src/bootstrap/native.rs

post-configure-DOCS-on:
	${REINPLACE_CMD} -e 's,%DOCS%,true,' ${WRKSRC}/config.toml

post-configure-DOCS-off:
	${REINPLACE_CMD} -e 's,%DOCS%,false,' ${WRKSRC}/config.toml

do-build:
	cd ${WRKSRC} && \
	${SETENV} ${X_PY_ENV} \
	${X_PY_CMD} build \
		--verbose \
		--config ./config.toml \
		--jobs ${MAKE_JOBS_NUMBER}

do-install:
	cd ${WRKSRC} && \
	${SETENV} ${X_PY_ENV} \
		DESTDIR=${STAGEDIR} \
	${X_PY_CMD} 'install' \
		--verbose \
		--config ./config.toml \
		--jobs ${MAKE_JOBS_NUMBER}

# In post-install, we use the manifests generated during Rust install
# to in turn generate the PLIST. We do that, instead of the regular
# `pkg-plist`, because several libraries have a computed filename based
# on the absolute path of the source files. As it is user-specific, we
# can't know their filename in advance.
#
# Both rustc and Cargo components install the same README.md and LICENSE
# files. The install process backs up the first copy to install the
# second. Thus here, we need to remove those backups. We also need to
# dedup the entries in the generated PLIST, because both components'
# manifests list them.
#
# We fix manpage entries in the generated manifests because Rust
# installs them uncompressed but the Ports framework compresses them.
post-install:
	for f in ${STAGEDIR}${PREFIX}/lib/rustlib/manifest-*; do \
	    ${REINPLACE_CMD} -i '' -E \
	        -e 's|:${STAGEDIR}|:|' \
	        -e 's|(man/man[1-9]/.*\.[0-9])|\1.gz|' \
	        "$$f"; \
	    ${ECHO_CMD} "$${f#${STAGEDIR}}" >> ${TMPPLIST}; \
	    ${AWK} '\
	        /^file:/ { \
	            file=$$0; \
	            sub(/^file:/, "", file); \
	            print file; \
	        } \
	        /^dir:/ { \
	            dir=$$0; \
	            sub(/^dir:/, "", dir); \
	            system("find ${STAGEDIR}" dir " -type f | ${SED} -E -e \"s|${STAGEDIR}||\""); \
	        }' \
	        "$$f" >> ${TMPPLIST}; \
	done
	${RM} -r ${STAGEDIR}${PREFIX}/share/doc/rust/*.old
	${SORT} -u < ${TMPPLIST} > ${TMPPLIST}.uniq
	${MV} ${TMPPLIST}.uniq ${TMPPLIST}
	@${RM} \
	    ${STAGEDIR}${PREFIX}/lib/rustlib/install.log \
	    ${STAGEDIR}${PREFIX}/lib/rustlib/uninstall.sh
# FIXME: Static libraries in lib/rustlib/*/lib/*.rlib are not stripped,
# but they contain non-object files which make strip(1) unhappy.
	@${FIND} ${STAGEDIR}${PREFIX}/bin -exec ${FILE} -i {} + | ${AWK} -F: \
		'/executable|sharedlib/ { print $$1 }' | ${XARGS} ${STRIP_CMD}

# Note that make test does not work when rust is already installed.
do-test:
	cd ${WRKSRC} && \
	${SETENV} ${X_PY_ENV} \
		ALLOW_NONZERO_RLIMIT_CORE=1 \
	${X_PY_CMD} test \
		--verbose \
		--config ./config.toml \
		--jobs ${MAKE_JOBS_NUMBER}

.if !defined(_RUST_MAKESUM_GUARD)
makesum:
	${MAKE} -D_RUST_MAKESUM_GUARD makesum ARCH=${ONLY_FOR_ARCHS:O:[1]}
.for arch in ${ONLY_FOR_ARCHS:O:[2..-1]}
	${MAKE} -D_RUST_MAKESUM_GUARD makesum ARCH=${arch} DISTINFO_FILE=${DISTINFO_FILE}.${arch}
	${GREP} ${RUST_ARCH_${arch}} ${DISTINFO_FILE}.${arch} >> ${DISTINFO_FILE}
	${RM} ${DISTINFO_FILE}.${arch}
.endfor
	${MAKE} -D_RUST_MAKESUM_GUARD makesum ARCH=powerpc64 BOOTSTRAPS_SUFFIX="-elfv2" DISTINFO_FILE=${DISTINFO_FILE}.powerpc64-elfv2
	${GREP} ${RUST_ARCH_powerpc64} ${DISTINFO_FILE}.powerpc64-elfv2 >> ${DISTINFO_FILE}
	${RM} ${DISTINFO_FILE}.powerpc64-elfv2
.endif

BOOTSTRAPS_SOURCE_PKG_FBSDVER=		10
BOOTSTRAPS_SOURCE_PKG_FBSDVER_aarch64=	11
BOOTSTRAPS_SOURCE_PKG_FBSDVER_armv6=	11
BOOTSTRAPS_SOURCE_PKG_FBSDVER_armv7=	12
BOOTSTRAPS_SOURCE_PKG_FBSDVER_powerpc64=	11
BOOTSTRAPS_SOURCE_PKG_REV=
BOOTSTRAPS_SOURCE_PKG_URL=	https://pkg.freebsd.org/FreeBSD:${BOOTSTRAPS_SOURCE_PKG_FBSDVER_${ARCH}:U${BOOTSTRAPS_SOURCE_PKG_FBSDVER}}:${ARCH}/latest/All/rust-${RUST_BOOTSTRAP_VERSION_${ARCH}:U${RUST_BOOTSTRAP_VERSION}}${BOOTSTRAPS_SOURCE_PKG_REV}.txz
BOOTSTRAPS_SOURCE_PKG=		${_DISTDIR}/${BOOTSTRAPS_DATE_${ARCH}:U${BOOTSTRAPS_DATE}}/rust-${RUST_BOOTSTRAP_VERSION_${ARCH}:U${RUST_BOOTSTRAP_VERSION}}-${ARCH}.txz

package-to-bootstraps: ${BOOTSTRAPS_SOURCE_PKG}
	${MKDIR} ${WRKDIR}/bootstraps
	${RM} -r ${WRKDIR}/bootstraps/usr
	${EXTRACT_CMD} \
		-C ${WRKDIR}/bootstraps \
		--strip-components 3 \
		${EXTRACT_BEFORE_ARGS} ${BOOTSTRAPS_SOURCE_PKG} ${LOCALBASE}
# `rustc` bootstrap.
	${RM} -r ${WRKDIR}/bootstraps/rustc-${RUST_BOOTSTRAP_VERSION_${ARCH}:U${RUST_BOOTSTRAP_VERSION}}-${RUST_TARGET}
	${MKDIR} ${WRKDIR}/bootstraps/rustc-${RUST_BOOTSTRAP_VERSION_${ARCH}:U${RUST_BOOTSTRAP_VERSION}}-${RUST_TARGET}
	cd ${WRKDIR}/bootstraps/rustc-${RUST_BOOTSTRAP_VERSION_${ARCH}:U${RUST_BOOTSTRAP_VERSION}}-${RUST_TARGET} && \
		${MKDIR} rustc/bin rustc/lib && \
		${MV} ${WRKDIR}/bootstraps/bin/rust* rustc/bin && \
		${MV} ${WRKDIR}/bootstraps/lib/*.so rustc/lib
	${TAR} -cz --format=ustar -C ${WRKDIR}/bootstraps \
		-f ${_DISTDIR}/${RUSTC_BOOTSTRAP}${BOOTSTRAPS_SUFFIX}.tar.gz \
		rustc-${RUST_BOOTSTRAP_VERSION_${ARCH}:U${RUST_BOOTSTRAP_VERSION}}-${RUST_TARGET}
# `rust-std` bootstrap.
	${RM} -r ${WRKDIR}/bootstraps/rust-std-${RUST_BOOTSTRAP_VERSION_${ARCH}:U${RUST_BOOTSTRAP_VERSION}}-${RUST_TARGET}
	${MKDIR} ${WRKDIR}/bootstraps/rust-std-${RUST_BOOTSTRAP_VERSION_${ARCH}:U${RUST_BOOTSTRAP_VERSION}}-${RUST_TARGET}
	cd ${WRKDIR}/bootstraps/rust-std-${RUST_BOOTSTRAP_VERSION_${ARCH}:U${RUST_BOOTSTRAP_VERSION}}-${RUST_TARGET} && \
		${MKDIR} rust-std-${RUST_TARGET}/lib/rustlib/${RUST_TARGET} && \
		${MV} ${WRKDIR}/bootstraps/lib/rustlib/${RUST_TARGET}/lib rust-std-${RUST_TARGET}/lib/rustlib/${RUST_TARGET}
	${TAR} -cz --format=ustar -C ${WRKDIR}/bootstraps \
		-f ${_DISTDIR}/${RUST_STD_BOOTSTRAP}${BOOTSTRAPS_SUFFIX}.tar.gz \
		rust-std-${RUST_BOOTSTRAP_VERSION_${ARCH}:U${RUST_BOOTSTRAP_VERSION}}-${RUST_TARGET}

${BOOTSTRAPS_SOURCE_PKG}:
	${MKDIR} ${@:H}
	${FETCH_CMD} -o $@ ${BOOTSTRAPS_SOURCE_PKG_URL}

.include <bsd.port.post.mk>
