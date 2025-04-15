# Minimum CMake version required. Android Studio usually suggests one.
# You might see different versions like 3.10.2 or 3.18.1 depending on your setup.
cmake_minimum_required(VERSION 3.10.2)

# Define the library we want to build from our C/C++ sources.
# - 'native_code' is the name we choose for our library.
#   This will result in a file named 'libnative_code.so' on Android.
#   This name is IMPORTANT - it's what you'll use in Dart FFI's DynamicLibrary.open().
# - 'SHARED' specifies that we want to build a shared library (.so file),
#   which can be loaded dynamically at runtime. This is REQUIRED for FFI.
# - 'native_code.cpp' is the source file to compile into this library.
#   Add any other .cpp or .c files needed for this library here, each on a new line.
add_library(
        native_code
        SHARED
        native_code.cpp
        # another_source_file.c
 )

# Optional: If your code needed standard Android libraries (like logging)
# you would add find_library and target_link_libraries here.
# Example for Android logging:
# find_library(log-lib log) # Find the native logging library
# target_link_libraries(native_code ${log-lib}) # Link our library against it