/**
 * @file libena/bind/nanobind.hpp
 * @brief Plain-data packers for libena results in nanobind (Python) bindings.
 *
 * Results cross the boundary as dicts of numpy arrays, not registered
 * nanobind classes, so extension modules built by different products (qe-ena,
 * a future qe-tma, ...) can be loaded together without type-registration
 * clashes.  Python-side result classes (ena.libena.NodePositions,
 * RotationResult) wrap the dicts to keep attribute access.
 *
 * Requires nanobind; never included by libena.hpp.  Array conversion comes
 * from libqe/bind/nanobind.hpp.
 */
#ifndef LIBENA_BIND_NANOBIND_HPP
#define LIBENA_BIND_NANOBIND_HPP

#include <libqe/bind/nanobind.hpp>

#include <libena/rotation.hpp>
#include <libena/positions.hpp>
#include <libena/ccd.hpp>

namespace qe {
namespace bind {
namespace py {

/// {nodes, centroids, weights, points}
inline ::nanobind::dict to_dict(const qe::NodePositions& r) {
    ::nanobind::dict out;
    out["nodes"]     = from_mat(r.nodes);
    out["centroids"] = from_mat(r.centroids);
    out["weights"]   = from_mat(r.weights);
    out["points"]    = from_mat(r.points);
    return out;
}

/// {rotation, eigenvalues, column_names (list of str)}
inline ::nanobind::dict to_dict(const qe::RotationResult& r) {
    ::nanobind::list names;
    for (const std::string& s : r.column_names)
        names.append(::nanobind::str(s.c_str(), s.size()));
    ::nanobind::dict out;
    out["rotation"]     = from_mat(r.rotation);
    out["eigenvalues"]  = from_vec(r.eigenvalues);
    out["column_names"] = names;
    return out;
}

/// {window_size, peak_lag, lag, frob, frob_sq_unbiased, frob_unbiased_signed,
///  total_weight}
inline ::nanobind::dict to_dict(const qe::CCDResult& r) {
    ::nanobind::dict out;
    out["window_size"]          = r.window_size;
    out["peak_lag"]             = r.peak_lag;
    out["lag"]                  = from_vec(r.lag);
    out["frob"]                 = from_vec(r.frob);
    out["frob_sq_unbiased"]     = from_vec(r.frob_sq_unbiased);
    out["frob_unbiased_signed"] = from_vec(r.frob_unbiased_signed);
    out["total_weight"]         = from_vec(r.total_weight);
    return out;
}

} // namespace py
} // namespace bind
} // namespace qe

#endif // LIBENA_BIND_NANOBIND_HPP
