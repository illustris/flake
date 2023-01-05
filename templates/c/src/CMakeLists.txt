project(HelloWorld)
cmake_minimum_required(VERSION 3.0)

add_executable(hello_world main.c)
install (TARGETS hello_world DESTINATION bin)
