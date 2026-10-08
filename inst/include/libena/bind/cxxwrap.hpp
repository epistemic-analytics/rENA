/**
 * @file libena/bind/cxxwrap.hpp
 * @brief Plain-data packers for libena results in CxxWrap.jl (Julia) bindings.
 *
 * Results cross the boundary as std::tuple values of std::vector / int32_t,
 * which Julia receives as plain Tuples of CxxWrap's own StdVector type.  No
 * result type is registered with add_type, so modules built by different
 * products (ENA.jl, a future TMA.jl, ...) can be loaded together: CxxWrap
 * keys registered types by C++ type, and the same packer compiled into two
 * modules would clash.  The Julia wrapper reshapes the tuples into
 * NamedTuples.
 *
 * Matrices travel as (data, rows, cols): data is column-major, Armadillo's
 * and Julia's layout, so `reshape(collect(data), rows, cols)` rebuilds them.
 *
 * Requires CxxWrap (jlcxx, with jlcxx/stl.hpp: link cxxwrap_julia_stl);
 * never included by libena.hpp.  Array conversion comes from
 * libqe/bind/cxxwrap.hpp.
 */
#ifndef LIBENA_BIND_CXXWRAP_HPP
#define LIBENA_BIND_CXXWRAP_HPP

#include <libqe/bind/cxxwrap.hpp>
#include <jlcxx/stl.hpp>
#include <jlcxx/tuple.hpp>

#include <libena/rotation.hpp>
#include <libena/positions.hpp>
#include <libena/ccd.hpp>

#include <cstdint>
#include <string>
#include <tuple>
#include <vector>

namespace qe {
namespace bind {
namespace jl {

inline std::vector<double> pack(const arma::vec& v) {
    return std::vector<double>(v.memptr(), v.memptr() + v.n_elem);
}

/// (nodes, rows, cols, centroids, rows, cols, weights, rows, cols,
///  points, rows, cols)
using NodePositionsTuple = std::tuple<
    std::vector<double>, int32_t, int32_t,
    std::vector<double>, int32_t, int32_t,
    std::vector<double>, int32_t, int32_t,
    std::vector<double>, int32_t, int32_t>;

inline NodePositionsTuple to_tuple(const qe::NodePositions& r) {
    auto n = [](const arma::mat& m) { return static_cast<int32_t>(m.n_rows); };
    auto c = [](const arma::mat& m) { return static_cast<int32_t>(m.n_cols); };
    return {pack(r.nodes),     n(r.nodes),     c(r.nodes),
            pack(r.centroids), n(r.centroids), c(r.centroids),
            pack(r.weights),   n(r.weights),   c(r.weights),
            pack(r.points),    n(r.points),    c(r.points)};
}

/// (rotation, rows, cols, eigenvalues, column_names)
using RotationTuple = std::tuple<
    std::vector<double>, int32_t, int32_t,
    std::vector<double>,
    std::vector<std::string>>;

inline RotationTuple to_tuple(const qe::RotationResult& r) {
    return {pack(r.rotation),
            static_cast<int32_t>(r.rotation.n_rows),
            static_cast<int32_t>(r.rotation.n_cols),
            pack(r.eigenvalues),
            r.column_names};
}

/// (window_size, peak_lag, lag, frob, frob_sq_unbiased, frob_unbiased_signed,
///  total_weight)
using CCDTuple = std::tuple<
    int32_t, int32_t,
    std::vector<double>, std::vector<double>, std::vector<double>,
    std::vector<double>, std::vector<double>>;

inline CCDTuple to_tuple(const qe::CCDResult& r) {
    return {static_cast<int32_t>(r.window_size),
            static_cast<int32_t>(r.peak_lag),
            pack(r.lag), pack(r.frob), pack(r.frob_sq_unbiased),
            pack(r.frob_unbiased_signed), pack(r.total_weight)};
}

} // namespace jl
} // namespace bind
} // namespace qe

#endif // LIBENA_BIND_CXXWRAP_HPP
