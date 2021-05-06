cmake_minimum_required(VERSION 3.17)
project(bls12-381-simulator C)

set(CMAKE_C_STANDARD 11)
include_directories(../src)

add_executable(simulator main.c)