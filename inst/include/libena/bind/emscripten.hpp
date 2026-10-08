/**
 * @file libena/bind/emscripten.hpp
 * @brief Plain-data packers for libena results in Emscripten (Embind) bindings.
 *
 * Results cross the boundary as plain JS objects, not registered Embind
 * classes, matching libqe-wasm's conventions:
 *
 *   RotationResult → { rotation: {data, rows, cols}, eigenvalues: number[],
 *                      column_names: string[] }
 *   NodePositions  → { nodes, centroids, weights, points }  (each {data, rows, cols})
 *   CCDResult      → { window_size, peak_lag, lag, frob, frob_sq_unbiased,
 *                      frob_unbiased_signed, total_weight }  (curves: number[])
 *
 * Requires Emscripten; never included by libena.hpp.  Array conversion comes
 * from libqe/bind/emscripten.hpp.
 */
#ifndef LIBENA_BIND_EMSCRIPTEN_HPP
#define LIBENA_BIND_EMSCRIPTEN_HPP

#include <libqe/bind/emscripten.hpp>

#include <libena/rotation.hpp>
#include <libena/positions.hpp>
#include <libena/ccd.hpp>

#include <emscripten/val.h>
#include <string>
#include <vector>

namespace qe {
namespace bind {
namespace js {

/// arma::vec → plain JS number[]
inline ::emscripten::val vec_to_js_array(const arma::vec& v) {
    std::vector<double> tmp(v.memptr(), v.memptr() + v.n_elem);
    return ::emscripten::val::array(tmp.begin(), tmp.end());
}

inline ::emscripten::val to_js(const qe::RotationResult& r) {
    ::emscripten::val result = ::emscripten::val::object();
    result.set("rotation",    mat_to_js(r.rotation));
    result.set("eigenvalues", vec_to_js_array(r.eigenvalues));
    ::emscripten::val names = ::emscripten::val::array();
    for (const auto& s : r.column_names)
        names.call<void>("push", ::emscripten::val(s));
    result.set("column_names", names);
    return result;
}

inline ::emscripten::val to_js(const qe::NodePositions& r) {
    ::emscripten::val result = ::emscripten::val::object();
    result.set("nodes",     mat_to_js(r.nodes));
    result.set("centroids", mat_to_js(r.centroids));
    result.set("weights",   mat_to_js(r.weights));
    result.set("points",    mat_to_js(r.points));
    return result;
}

inline ::emscripten::val to_js(const qe::CCDResult& r) {
    ::emscripten::val result = ::emscripten::val::object();
    result.set("window_size",          r.window_size);
    result.set("peak_lag",             r.peak_lag);
    result.set("lag",                  vec_to_js_array(r.lag));
    result.set("frob",                 vec_to_js_array(r.frob));
    result.set("frob_sq_unbiased",     vec_to_js_array(r.frob_sq_unbiased));
    result.set("frob_unbiased_signed", vec_to_js_array(r.frob_unbiased_signed));
    result.set("total_weight",         vec_to_js_array(r.total_weight));
    return result;
}

} // namespace js
} // namespace bind
} // namespace qe

#endif // LIBENA_BIND_EMSCRIPTEN_HPP
