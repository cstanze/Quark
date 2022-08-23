cmake_minimum_required(VERSION 3.19.6)

project(
  <ProjectName>
  C
  CXX
)

# Don't clobber existing variable values when
# evaluating `option()` declarations.
if(POLICY CMP0077)
  cmake_policy(SET CMP0077 NEW)
endif()

option(<PN>_CROSS_COMPILE "Enable cross-compiling" OFF)
set(<PN>_CROSS_COMPILE_TARGET "arm-linux-gnueabihf" CACHE STRING "Target platform")
set(<PN>_CROSS_COMPILE_SYSTEM "Linux" CACHE STRING "Target system")
set(<PN>_CROSS_COMPILE_PROCESSOR "arm" CACHE STRING "Target processor")
set(<PN>_CROSS_COMPILE_SYSROOT "/usr/arm-linux-gnueabihf" CACHE STRING "Target sysroot")

option(<PN>_DEBUG "Enable debug build" ON)

if(DEFINED ENV{PREFIX_DIR} AND NOT "$ENV{PREFIX_DIR}" STREQUAL "" AND NOT EXISTS "${<PN>_CROSS_COMPILE}")
  set(CMAKE_INSTALL_PREFIX "$ENV{PREFIX_DIR}")
else()
  set(CMAKE_INSTALL_PREFIX "$ENV{HOME}/.<pn>")
endif()
set(CMAKE_PREFIX_PATH "${CMAKE_INSTALL_PREFIX};${CMAKE_BINARY_DIR}")
add_definitions(-DINSTALL_PREFIX="${CMAKE_INSTALL_PREFIX}")
message(STATUS "Using prefix: ${CMAKE_INSTALL_PREFIX}")

# Module setup
set(CMAKE_MODULE_PATH "${CMAKE_MODULE_PATH};${PROJECT_SOURCE_DIR}/cmake/modules")

include(QuarkTargets)

# macOS RPath fix
set(ORIGIN "$ORIGIN")
if(APPLE)
  set(ORIGIN "@loader_path")
endif()
set(CMAKE_INSTALL_RPATH "${ORIGIN}/../lib;${ORIGIN}/../lib;${ORIGIN}/.")
set(CMAKE_BUILD_WITH_INSTALL_NAME_DIR ON)
set(CMAKE_BUILD_WITH_INSTALL_RPATH ON)
set(CMAKE_INSTALL_RPATH_USE_LINK_PATH ON)
set(CMAKE_MACOSX_RPATH ON)

# C++ Standard
set(CMAKE_CXX_STANDARD <CxxStandard> CACHE STRING "C++ standard to conform to")
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

# Build type

if(NOT CMAKE_BUILD_TYPE AND NOT CMAKE_CONFIGURATION_TYPES)
  set(CMAKE_BUILD_TYPE "Debug" CACHE STRING
    "Build type for <ProjectName> [Debug, RelWithDebInfo, Release]"
    FORCE)
  message(STATUS "Build type not specified, defaulting to ${CMAKE_BUILD_TYPE}")
endif()

if(${CMAKE_SYSTEM_NAME} MATCHES ".*BSD.*")
  add_definitions(-D_WITH_GETLINE)
endif()

if("${CMAKE_BUILD_TYPE}" STREQUAL "Debug" OR "${CMAKE_BUILD_TYPE}" STREQUAL "RelWithDebInfo")
  message(STATUS "Building with debug info...")
  add_definitions(-DDEBUG)
endif()

if("${CMAKE_BUILD_TYPE}" STREQUAL "RelWithDebInfo" OR "${CMAKE_BUILD_TYPE}" STREQUAL "Release")
  message(STATUS "Building with release info...")
  add_definitions(-DRELEASE)
endif()

# Cross-compiling
if("${<PN>_CROSS_COMPILE}")
  if(NOT CMAKE_CXX_COMPILER_ID MATCHES "Clang")
    message(FATAL_ERROR "Cross-compiling requires Clang")
  endif()

  message(STATUS "Cross-compiling for ${<PN>_CROSS_COMPILE_TARGET}...")
  message(STATUS "System: ${<PN>_CROSS_COMPILE_SYSTEM}")
  message(STATUS "Processor: ${<PN>_CROSS_COMPILE_PROCESSOR}")
  message(STATUS "Sysroot: ${<PN>_CROSS_COMPILE_SYSROOT}")

  # Set system name, processor, and sysroot
  set(CMAKE_SYSTEM_NAME ${<PN>_CROSS_COMPILE_SYSTEM})
  set(CMAKE_SYSTEM_PROCESSOR ${<PN>_CROSS_COMPILE_PROCESSOR})
  set(CMAKE_SYSROOT ${<PN>_CROSS_COMPILE_SYSROOT})

  # Set compiler and target
  set(CMAKE_C_COMPILER clang)
  set(CMAKE_CXX_COMPILER clang++)
  set(CMAKE_C_COMPILER_TARGET ${<PN>_CROSS_COMPILE_TARGET}) 
  set(CMAKE_CXX_COMPILER_TARGET ${<PN>_CROSS_COMPILE_TARGET})
endif()

set(CMAKE_TRY_COMPILE_TARGET_TYPE "STATIC_LIBRARY")

# Config
option(<PN>_ENABLE_TESTS "Enable tests" OFF)
option(<PN>_ENABLE_COMPILE_COMMANDS "Enable compile_commands.json" ON)

set(CMAKE_EXPORT_COMPILE_COMMANDS ${<PN>_ENABLE_COMPILE_COMMANDS})

set(<PN>_VERSION "0.0.1")

execute_process(COMMAND date +"%Y-%m-%d" OUTPUT_VARIABLE BUILD_DATE OUTPUT_STRIP_TRAILING_WHITESPACE)

# Check if the directory is a git repository
execute_process(COMMAND git rev-parse --is-inside-work-tree
  WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
  OUTPUT_VARIABLE GIT_REPO
  OUTPUT_STRIP_TRAILING_WHITESPACE
)

if(GIT_REPO)
  # Get git revision
  execute_process(COMMAND git rev-parse --short HEAD
    WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
    OUTPUT_VARIABLE GIT_REVISION
    OUTPUT_STRIP_TRAILING_WHITESPACE
  )

  # Get git branch
  execute_process(COMMAND git rev-parse --abbrev-ref HEAD
    WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
    OUTPUT_VARIABLE GIT_BRANCH
    OUTPUT_STRIP_TRAILING_WHITESPACE
  )
endif()

configure_file(
  ${CMAKE_SOURCE_DIR}/include/Config.hpp.in
  ${CMAKE_BINARY_DIR}/include/Config.hpp
  @ONLY
)

# Pthread
set(CMAKE_THREAD_PREFER_PTHREAD ON)
set(THRADS_PREFER_PTHREAD_FLAG ON)
find_package(Threads REQUIRED)
if(CMAKE_USE_PTHREADS_INIT)
  message(STATUS "Using thread flags: -pthread")
  set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -pthread")
  set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -pthread")
  set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} -pthread")
else()
  message(STATUS "Using thread flags: ${CMAKE_THREAD_LIBS_INIT}")
  set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} ${CMAKE_THREAD_LIBS_INIT}")
  set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} ${CMAKE_THREAD_LIBS_INIT}")
  set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} ${CMAKE_THREAD_LIBS_INIT}")
endif()

# ccache
find_program(CCACHE_PROGRAM ccache)
if (CCACHE_PROGRAM)
  message(STATUS "Using ccache: ${CCACHE_PROGRAM}")
  set_property(GLOBAL PROPERTY RULE_LAUNCH_COMPILE "${CCACHE_PROGRAM}")
  set_property(GLOBAL PROPERTY RULE_LAUNCH_LINK "${CCACHE_PROGRAM}")
endif()

# Install CMake modules
install(
  DIRECTORY ${CMAKE_SOURCE_DIR}/cmake/modules/
  DESTINATION ${CMAKE_INSTALL_PREFIX}/share/cmake/modules
)

# Install includes
install(
  DIRECTORY ${CMAKE_SOURCE_DIR}/include/
  DESTINATION ${CMAKE_INSTALL_PREFIX}/include
)

add_subdirectory(lib)
