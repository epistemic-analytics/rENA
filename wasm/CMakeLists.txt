cmake_minimum_required(VERSION 3.18)
project(rena_wasm_libena LANGUAGES CXX)

# ── libena + libqe + libtma headers ───────────────────────────────────────────
# scripts/sync-headers.sh (run by scripts/build.sh) vendors them into
# wasm/include/: libena from inst/include/libena, libqe and libtma from Conan
# (libtma from tma until it is published).
set(HEADER_DIR "${CMAKE_CURRENT_SOURCE_DIR}/include")
if(NOT EXISTS "${HEADER_DIR}/libena/libena.hpp"
   OR NOT EXISTS "${HEADER_DIR}/libqe/bind/emscripten.hpp"
   OR NOT EXISTS "${HEADER_DIR}/libtma/bind/emscripten.hpp")
    message(FATAL_ERROR "libena / libqe / libtma headers not found in wasm/include/. "
            "Build with `sh wasm/scripts/build.sh`, or run "
            "`sh scripts/sync-headers.sh` from the rENA repo root first.")
endif()

# ── Armadillo (provided by Conan) ─────────────────────────────────────────────
find_package(Armadillo REQUIRED)

# ── WASM module ───────────────────────────────────────────────────────────────
add_executable(libena csrc/libena_wasm.cpp)

target_include_directories(libena PRIVATE
    ${HEADER_DIR}
    ${ARMADILLO_INCLUDE_DIRS}
)

target_link_libraries(libena PRIVATE ${ARMADILLO_LIBRARIES})

# Disable BLAS/LAPACK — Armadillo falls back to its own built-in routines,
# which is the only path that works without external symbols in WASM.
target_compile_definitions(libena PRIVATE
    ARMA_DONT_USE_BLAS
    ARMA_DONT_USE_LAPACK
)

# ── Emscripten link flags (as libqe-wasm's) ───────────────────────────────────
# MODULARIZE=1 + EXPORT_ES6=1 — an ES module exporting the factory function
# --bind                      — enable Embind
# ALLOW_MEMORY_GROWTH         — needed for dynamic Armadillo allocations
# ENVIRONMENT                 — target web + node
# target_link_options() (not the LINK_FLAGS property) keeps each flag a
# separate token on the linker command line.
set_target_properties(libena PROPERTIES SUFFIX ".js")

target_link_options(libena PRIVATE
    -sMODULARIZE=1
    -sEXPORT_ES6=1
    -sEXPORT_NAME=LibENA
    -sWASM=1
    -sALLOW_MEMORY_GROWTH=1
    "-sENVIRONMENT=web,node"
    --bind
    -O3
)

# ── output to dist/ ───────────────────────────────────────────────────────────
install(FILES
    ${CMAKE_CURRENT_BINARY_DIR}/libena.js
    ${CMAKE_CURRENT_BINARY_DIR}/libena.wasm
    DESTINATION ${CMAKE_CURRENT_SOURCE_DIR}/dist
)
