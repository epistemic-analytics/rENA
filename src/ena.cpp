// [[Rcpp::depends(RcppArmadillo, libqe)]]
#include <RcppArmadillo.h>
#include <libqe/libqe.hpp>

using namespace Rcpp;

// ── helper ────────────────────────────────────────────────────────────────────
// Convert an R DataFrame to an arma::mat column-by-column.
// Replaces the old toNumericMatrix() helper.
static arma::mat df_to_arma(Rcpp::DataFrame df) {
    int nRows = df.nrows(), nCols = df.size();
    arma::mat m(nRows, nCols, arma::fill::zeros);
    for (int i = 0; i < nCols; ++i)
        m.col(i) = Rcpp::as<arma::vec>(df[i]);
    return m;
}

// ── kept as-is (no libqe equivalent) ─────────────────────────────────────────

//' Merge data frame columns
//' @title Merge data frame columns
//' @description Paste together multiple DataFrame columns with a separator,
//'   used internally to construct unit-ID strings.
//' @param df Dataframe
//' @param cols Character vector of column names to merge
//' @param sep Separator string (default "::")
//' @export
// [[Rcpp::export]]
std::vector<std::string> merge_columns_c(
    Rcpp::DataFrame df,
    Rcpp::CharacterVector cols,
    std::string sep = "::"
) {
    int vRows = df.nrows();
    std::vector<std::string> newCol(vRows);

    Rcpp::List colList;
    for (int j = 0; j < cols.length(); j++) {
        std::ostringstream oss;
        oss << cols[j];
        std::string col = oss.str();
        Rcpp::CharacterVector cv = df[col];
        colList[col] = cv;
    }

    Rcpp::CharacterVector colNames = colList.names();
    for (int i = 0; i < vRows; i++) {
        std::ostringstream ossCol;
        for (int j = 0; j < colNames.length(); j++) {
            std::ostringstream oss;
            oss << cols[j];
            std::string colName = oss.str();
            Rcpp::CharacterVector colVec = colList[colName];
            ossCol << colVec[i];
            if (j + 1 < colNames.length()) ossCol << sep;
        }
        newCol[i] = ossCol.str();
    }
    return newCol;
}

// ── libqe delegates ───────────────────────────────────────────────────────────

//' Calculate the correlations
//'
//' @title Calculate the correlations
//' @description Calculate both Pearson correlations for the
//' provided points and centroids
//' @param points   Numeric matrix (units x dims)
//' @param centroids Numeric matrix (units x dims)
//' @param conf_level Confidence level (default 0.95)
//' @export
// [[Rcpp::export]]
arma::mat ena_correlation(arma::mat points, arma::mat centroids,
                           double conf_level = 0.95) {
    return qe::ena_correlation(points, centroids, conf_level);
}

//' Upper Triangle from Vector
//'
//' @title vector to upper triangle
//' @description Compute pairwise products for all j < i.
//' @param v Numeric matrix (treated as vector)
//' @export
// [[Rcpp::export]]
arma::rowvec vector_to_ut(arma::mat v) {
    return qe::vector_to_upper_tri(v);
}

// [[Rcpp::export]]
std::vector<std::string> svector_to_ut(std::vector<std::string> v) {
    return qe::svector_to_upper_tri(v);
}

// [[Rcpp::export]]
arma::mat rows_to_co_occurrences(Rcpp::DataFrame df, bool binary = true) {
    return qe::rows_to_co_occurrences(df_to_arma(df), binary);
}

// @title ref_window_df
// @description Stanza-window co-occurrence accumulation.
// @param df          A dataframe of code columns
// @param windowSize  Number of prior rows in window (default 1)
// @param windowForward Number of subsequent rows (default 0)
// @param binary      Treat codes as binary (default TRUE)
// [[Rcpp::interfaces(r, cpp)]]
// [[Rcpp::export]]
Rcpp::DataFrame ref_window_df(
    Rcpp::DataFrame df,
    float windowSize    = 1,
    float windowForward = 0,
    bool  binary        = true
) {
    const int INT_MAX_VAL = std::numeric_limits<int>::max();
    const float INF_VAL   = std::numeric_limits<float>::infinity();

    int wb = (windowSize    >= INF_VAL || windowSize    >= static_cast<float>(INT_MAX_VAL))
               ? INT_MAX_VAL : static_cast<int>(windowSize);
    int wf = (windowForward >= INF_VAL || windowForward >= static_cast<float>(INT_MAX_VAL))
               ? INT_MAX_VAL : static_cast<int>(windowForward);

    return Rcpp::wrap(qe::stanza_window(df_to_arma(df), wb, wf, binary));
}

// @title ref_window_lag
// @description Rolling backward window sum of raw code columns.
// @param df         A dataframe of code columns
// @param windowSize Number of rows to look back (default 0, treated as 1)
// @param binary     Unused (kept for API compatibility)
// [[Rcpp::interfaces(r, cpp)]]
// [[Rcpp::export]]
Rcpp::DataFrame ref_window_lag(
    Rcpp::DataFrame df,
    int  windowSize = 0,
    bool binary     = true
) {
    (void)binary;  // param preserved for API compatibility; not used
    return Rcpp::wrap(qe::rolling_window_sum(df_to_arma(df), windowSize));
}

//' Row-wise L2 (Sphere) Normalization
//'
//' @title Row-wise L2 (Sphere) Normalization
//' @description Normalizes each row to unit L2 norm.
//' @param dfM A data.frame or matrix
//' @return Numeric matrix with each row normalized to unit length
//' @export
// [[Rcpp::export]]
Rcpp::NumericMatrix fun_sphere_norm(Rcpp::DataFrame dfM) {
    return Rcpp::wrap(qe::sphere_norm(df_to_arma(dfM)));
}

//' Row-wise Max-Norm Scaling
//'
//' @title Row-wise Max-Norm Scaling
//' @description Scales all rows by dividing by the largest row L2 norm.
//' @param dfM A data.frame or matrix
//' @return Numeric matrix scaled by the largest row norm
//' @export
// [[Rcpp::export]]
Rcpp::NumericMatrix fun_skip_sphere_norm(Rcpp::DataFrame dfM) {
    return Rcpp::wrap(qe::skip_sphere_norm(df_to_arma(dfM)));
}

// [[Rcpp::export]]
Rcpp::NumericMatrix center_data_c(arma::mat values) {
    return Rcpp::wrap(qe::center_data(values));
}

// [[Rcpp::export]]
arma::umat triIndices(int len, int row = -1) {
    return qe::tri_indices(len, row);
}

// [[Rcpp::export]]
Rcpp::List lws_lsq_positions(arma::mat adjMats, arma::mat t, int numDims) {
    qe::NodePositions r = qe::lws_lsq_positions(adjMats, t, numDims);
    return Rcpp::List::create(
        Rcpp::_("nodes")     = r.nodes,
        Rcpp::_("centroids") = r.centroids,
        Rcpp::_("weights")   = r.weights,
        Rcpp::_("points")    = r.points
    );
}

//' Multiobjective, Component by Component, with Ellipsoidal Scaling, for directed ENA
//'
//' @title Directed ENA node positions
//' @description Least-squares node positions for directed ENA.
//' @param line_weights Numeric matrix (units x connections)
//' @param points       Numeric matrix of rotated points (units x dims)
//' @param numDims      Number of dimensions
//' @export
// [[Rcpp::export]]
Rcpp::List directed_node_positions(arma::mat line_weights, arma::mat points,
                                    int numDims) {
    qe::NodePositions r = qe::directed_node_positions(line_weights, points, numDims);
    return Rcpp::List::create(
        Rcpp::_("nodes")     = r.nodes,
        Rcpp::_("centroids") = r.centroids,
        Rcpp::_("weights")   = r.weights,
        Rcpp::_("points")    = r.points
    );
}

//' Node position optimization with ground and response weights/points added
//'
//' @title Directed node positions with ground+response combined
//' @description Directed node positions with paired ground+response rows combined.
//' @param line_weights Numeric matrix (units x connections)
//' @param points       Numeric matrix of rotated points (units x dims)
//' @param numDims      Number of dimensions
//' @export
// [[Rcpp::export]]
Rcpp::List directed_node_positions_with_ground_response_added(
    arma::mat line_weights, arma::mat points, int numDims
) {
    qe::NodePositions r = qe::directed_node_positions_ground_response(
        line_weights, points, numDims);
    return Rcpp::List::create(
        Rcpp::_("nodes")     = r.nodes,
        Rcpp::_("centroids") = r.centroids,
        Rcpp::_("weights")   = r.weights,
        Rcpp::_("points")    = r.points
    );
}
