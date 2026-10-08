cmake_minimum_required(VERSION 3.18)
project(test_libena CXX)

find_package(libena    REQUIRED)
find_package(Armadillo REQUIRED)

add_executable(test_libena src/test_libena.cpp)
target_compile_features(test_libena PRIVATE cxx_std_17)
target_link_libraries(test_libena PRIVATE libena::libena ${ARMADILLO_LIBRARIES})
target_include_directories(test_libena PRIVATE ${ARMADILLO_INCLUDE_DIRS})
