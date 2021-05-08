cmake_minimum_required(VERSION 3.17)
project(bls12-381-simulator C)

set(CMAKE_C_STANDARD 11)

# uncomment it for sanitize
#set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -fsanitize=address -fsanitize=undefined")

include_directories(../src)
include_directories(../bindings)
add_definitions(-DUSE_SIM)

add_executable(simulator main.c ../src/server.c)
