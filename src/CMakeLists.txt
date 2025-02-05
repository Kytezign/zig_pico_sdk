# Tried to minimize what this was doing.  If a more complicated c side build is needed...
# Cross that bridge later. 
set(PROJECT zig_example) # This name needs to match the load step 
cmake_minimum_required(VERSION 3.12)
include($ENV{PICO_SDK_PATH}/external/pico_sdk_import.cmake)
project(${PROJECT} C CXX ASM)
pico_sdk_init()
add_executable(${PROJECT})
# Generate PIO - this creates a step ${PROJECT}_async_spi_pio_h
# The PIO header that is generated needs to be included in the root source file for usage
# Build will search in the install path but if the file is generated somewhere else,
# it will need to be stated explicitly in the build
pico_generate_pio_header(${PROJECT}  ${CMAKE_SOURCE_DIR}/async_spi.pio)


# For other c sources that need to be built.
# target_sources(${PROJECT}  PUBLIC
#                 ${CMAKE_CURRENT_LIST_DIR}/xxx.c
#                 ${CMAKE_CURRENT_LIST_DIR}/yyy.c
#                 ${CMAKE_CURRENT_SOURCE_DIR}/zzz.c
#             )


# Connect to zig library
add_library(zig_lib STATIC IMPORTED)
set_property(TARGET zig_lib PROPERTY  IMPORTED_LOCATION "${CMAKE_BINARY_DIR}/lib/libzigmain.a")
# Add other libraries here as needed. 
target_link_libraries(${PROJECT} pico_stdlib zig_lib hardware_pio hardware_pio)
# Example: target_link_libraries(${PROJECT} pico_stdlib hardware_pio tinyusb_device tinyusb_board zig_lib hardware_pwm)

pico_add_extra_outputs(${PROJECT})
