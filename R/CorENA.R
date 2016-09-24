Rcpp::sourceCpp(code='
  // [[Rcpp::depends(RcppArmadillo)]]

  #include <Rcpp.h>
  #include <iostream>
  #include <ctime>
  #include <algorithm>
  #include <iterator>
  #include <cmath>
  #include "/Users/clmarquart/Workspaces/RStudio2/rENA/src/optimizer.h"

  using namespace Rcpp;
  using namespace std;

  float f(Vector2 v) {
    float x = v[0];
    float y = v[1];
    return ((-x*x*x*x+4.5*x*x+2)/pow(2.71828,2*y*y));
  }

  // [[Rcpp::export]]
  NumericVector vtest() {
    NelderMeadOptimizer o(2, 0.001);

    // horrible start values
    o.insert(Vector2(2, 1));
    o.insert(Vector2(2.001, 0));
    //o.insert(Vector2(1000000, -200));

    Vector2 v(2, 1);
    while (!o.done()) {
      float score = f(v);
      Rcpp::Rcout << "V: " << v << " -> " << score << std::endl;
      v = o.step(v, score);
    }
   float tolerance = 0.001;

    std::cout << v.dimension() << std::endl;

    return wrap(v[1]);
  }

')
