#!/bin/sh
# sync-headers.sh — vendor the C++ headers that qe-ena's extension (python/),
#                   rena-wasm's module (wasm/) and ENA.jl's library (julia/)
#                   build against into python/include/, wasm/include/ and
#                   julia/include/:
#
#   libena  from inst/include/libena/ (this repo's canonical copy)
#   libqe   from Conan: libqe/$LIBQE_VERSION on the qe-libs registry, or from a
#           local libqe checkout when LIBQE_INCLUDE=<libqe>/include is set
#   libtma  (qe-ena and rena-wasm compile the accumulation they use) from
#           LIBTMA_INCLUDE=<tma>/inst/include if set, else Conan
#           libtma/$LIBTMA_VERSION, else -- until tma publishes it -- a sibling
#           tma checkout (../tma), else a clone of tma's $TMA_REF branch
#           (default develop) from $TMA_GIT_URL
#
# The R package doesn't need this: it gets libqe through LinkingTo.  Needed for:
#
#   1. Building or installing qe-ena from a checkout:
#        sh scripts/sync-headers.sh && pip install ./python
#   2. A self-contained qe-ena sdist (it ships python/include/):
#        sh scripts/sync-headers.sh && python -m build --sdist python/
#      cranqe runs this script before building, when the repo provides it.
#   3. rena-wasm: wasm/scripts/build.sh runs it.
#   4. ENA.jl from a checkout (cranqe's Julia build runs it too).
#
# Conan: uses `conan` on PATH, else installs it into a throwaway venv with
# $PYTHON (default python3).  It runs with a throwaway CONAN_HOME, so your own
# Conan configuration and cache are untouched.
#
# Usage (from anywhere):  sh scripts/sync-headers.sh

set -e
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# Bump with DESCRIPTION's LinkingTo: libqe minimum / Imports: tma minimum.
LIBQE_VERSION="${LIBQE_VERSION:-0.1.9}"
LIBTMA_VERSION="${LIBTMA_VERSION:-0.3.6}"
TMA_REF="${TMA_REF:-develop}"
TMA_GIT_URL="${TMA_GIT_URL:-https://gitlab.com/epistemic-analytics/qe-packages/tma.git}"
CONAN_REMOTE="https://gitlab.com/api/v4/projects/22522458/packages/conan"
DESTS="${REPO_ROOT}/python/include ${REPO_ROOT}/wasm/include ${REPO_ROOT}/julia/include"

TMP="$(mktemp -d)"
trap 'rm -rf "${TMP}"' EXIT

# ── Conan (only when a header tree comes from it) ────────────────────────────
CONAN=""
conan_setup() {
    [ -n "${CONAN}" ] && return 0
    if command -v conan >/dev/null 2>&1; then
        CONAN=conan
    else
        echo "Installing conan into a throwaway venv (${PYTHON:-python3})..."
        "${PYTHON:-python3}" -m venv "${TMP}/venv"
        VBIN="${TMP}/venv/bin"
        [ -d "${VBIN}" ] || VBIN="${TMP}/venv/Scripts"   # Windows venv layout
        "${VBIN}/python" -m pip install --quiet conan
        CONAN="${VBIN}/conan"
    fi
    export CONAN_HOME="${TMP}/conan-home"
    ${CONAN} remote add qe-libs "${CONAN_REMOTE}" --force >/dev/null
}

# conan_headers <name> <version>: download the header-only package and print
# its include/<name> directory (empty, and status 1, when it is not published).
# Call conan_setup first: conan_headers runs in a subshell ($(...)), so its
# own setup would not persist.
conan_headers() {
    echo "Downloading $1/$2 from ${CONAN_REMOTE}..." >&2
    ${CONAN} download "$1/$2:*" -r qe-libs >/dev/null 2>&1 || return 1
    find "${CONAN_HOME}/p" -type d -path "*/p/include/$1" | head -1
}

# ── libqe headers ─────────────────────────────────────────────────────────────
if [ -z "${LIBQE_INCLUDE:-}" ] || [ -z "${LIBTMA_INCLUDE:-}" ]; then
    conan_setup
fi
if [ -n "${LIBQE_INCLUDE:-}" ]; then
    LIBQE_SRC="${LIBQE_INCLUDE}/libqe"
    LIBQE_FROM="${LIBQE_SRC}"
else
    LIBQE_SRC="$(conan_headers libqe "${LIBQE_VERSION}")" || true
    if [ -z "${LIBQE_SRC}" ]; then
        echo "ERROR: libqe/${LIBQE_VERSION} not found on ${CONAN_REMOTE}" >&2
        exit 1
    fi
    LIBQE_FROM="libqe/${LIBQE_VERSION} (Conan)"
fi

# ── libtma headers ────────────────────────────────────────────────────────────
if [ -n "${LIBTMA_INCLUDE:-}" ]; then
    LIBTMA_SRC="${LIBTMA_INCLUDE}/libtma"
    LIBTMA_FROM="${LIBTMA_SRC}"
else
    LIBTMA_SRC="$(conan_headers libtma "${LIBTMA_VERSION}")" || true
    LIBTMA_FROM="libtma/${LIBTMA_VERSION} (Conan)"
    if [ -z "${LIBTMA_SRC}" ] && [ -d "${REPO_ROOT}/../tma/inst/include/libtma" ]; then
        # Not published yet: a local tma checkout next to this one.
        LIBTMA_SRC="$(cd "${REPO_ROOT}/../tma/inst/include/libtma" && pwd)"
        LIBTMA_FROM="${LIBTMA_SRC} (sibling checkout)"
    fi
    if [ -z "${LIBTMA_SRC}" ]; then
        # Not published yet: take it from tma's branch.  Drop this fallback once
        # libtma is on the registry.
        echo "libtma/${LIBTMA_VERSION} not on ${CONAN_REMOTE}; cloning tma ${TMA_REF}..."
        git clone --quiet --depth 1 --branch "${TMA_REF}" "${TMA_GIT_URL}" "${TMP}/tma"
        LIBTMA_SRC="${TMP}/tma/inst/include/libtma"
        LIBTMA_FROM="tma ${TMA_REF} (git)"
    fi
fi

# ── copy into each destination ───────────────────────────────────────────────
for DST in ${DESTS}; do
    # Generated (git-ignored) copies: clear them so a header that moved or was
    # removed upstream is not left behind.
    rm -rf "${DST}/libena" "${DST}/libqe" "${DST}/libtma"
    mkdir -p "${DST}"
    echo "Syncing inst/include/libena -> ${DST}/libena"
    cp -R "${REPO_ROOT}/inst/include/libena" "${DST}/libena"
    echo "Syncing ${LIBQE_FROM} -> ${DST}/libqe"
    cp -R "${LIBQE_SRC}" "${DST}/libqe"
    echo "Syncing ${LIBTMA_FROM} -> ${DST}/libtma"
    cp -R "${LIBTMA_SRC}" "${DST}/libtma"
done
echo "Done."
