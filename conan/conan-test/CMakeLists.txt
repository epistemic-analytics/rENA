cmake_minimum_required(VERSION 3.18)
project(test_libena CXX)

find_package(libena    REQUIRED)
find_package(Armadillo REQUIRED)

add_executable(test_libena src/test_libena.cpp)
target_compile_features(test_libena PRIVATE cxx_std_17)
# Use libqe's built-in linear algebra (linalg_fallback.hpp), not LAPACK: the
# test only checks that the headers compile, link and run, and ConanCenter's
# prebuilt OpenBLAS binary died with SIGILL ("Illegal instruction") on a
# cranqe runner whose CPU lacks the instructions it was built for.
target_compile_definitions(test_libena PRIVATE ARMA_DONT_USE_BLAS ARMA_DONT_USE_LAPACK)
target_link_libraries(test_libena PRIVATE libena::libena ${ARMADILLO_LIBRARIES})
target_include_directories(test_libena PRIVATE ${ARMADILLO_INCLUDE_DIRS})
