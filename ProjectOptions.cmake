include(cmake/SystemLink.cmake)
include(cmake/LibFuzzer.cmake)
include(CMakeDependentOption)
include(CheckCXXCompilerFlag)


include(CheckCXXSourceCompiles)


macro(myprj_supports_sanitizers)
  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND NOT WIN32)

    message(STATUS "Sanity checking UndefinedBehaviorSanitizer, it should be supported on this platform")
    set(TEST_PROGRAM "int main() { return 0; }")

    # Check if UndefinedBehaviorSanitizer works at link time
    set(CMAKE_REQUIRED_FLAGS "-fsanitize=undefined")
    set(CMAKE_REQUIRED_LINK_OPTIONS "-fsanitize=undefined")
    check_cxx_source_compiles("${TEST_PROGRAM}" HAS_UBSAN_LINK_SUPPORT)

    if(HAS_UBSAN_LINK_SUPPORT)
      message(STATUS "UndefinedBehaviorSanitizer is supported at both compile and link time.")
      set(SUPPORTS_UBSAN ON)
    else()
      message(WARNING "UndefinedBehaviorSanitizer is NOT supported at link time.")
      set(SUPPORTS_UBSAN OFF)
    endif()
  else()
    set(SUPPORTS_UBSAN OFF)
  endif()

  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND WIN32)
    set(SUPPORTS_ASAN OFF)
  else()
    if (NOT WIN32)
      message(STATUS "Sanity checking AddressSanitizer, it should be supported on this platform")
      set(TEST_PROGRAM "int main() { return 0; }")

      # Check if AddressSanitizer works at link time
      set(CMAKE_REQUIRED_FLAGS "-fsanitize=address")
      set(CMAKE_REQUIRED_LINK_OPTIONS "-fsanitize=address")
      check_cxx_source_compiles("${TEST_PROGRAM}" HAS_ASAN_LINK_SUPPORT)

      if(HAS_ASAN_LINK_SUPPORT)
        message(STATUS "AddressSanitizer is supported at both compile and link time.")
        set(SUPPORTS_ASAN ON)
      else()
        message(WARNING "AddressSanitizer is NOT supported at link time.")
        set(SUPPORTS_ASAN OFF)
      endif()
    else()
      set(SUPPORTS_ASAN ON)
    endif()
  endif()
endmacro()

macro(myprj_setup_options)
  option(myprj_ENABLE_HARDENING "Enable hardening" ON)
  option(myprj_ENABLE_COVERAGE "Enable coverage reporting" OFF)
  cmake_dependent_option(
    myprj_ENABLE_GLOBAL_HARDENING
    "Attempt to push hardening options to built dependencies"
    ON
    myprj_ENABLE_HARDENING
    OFF)

  myprj_supports_sanitizers()

  if(NOT PROJECT_IS_TOP_LEVEL OR myprj_PACKAGING_MAINTAINER_MODE)
    option(myprj_ENABLE_IPO "Enable IPO/LTO" OFF)
    option(myprj_WARNINGS_AS_ERRORS "Treat Warnings As Errors" OFF)
    option(myprj_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(myprj_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" OFF)
    option(myprj_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(myprj_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" OFF)
    option(myprj_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(myprj_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(myprj_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(myprj_ENABLE_CLANG_TIDY "Enable clang-tidy" OFF)
    option(myprj_ENABLE_CPPCHECK "Enable cpp-check analysis" OFF)
    option(myprj_ENABLE_PCH "Enable precompiled headers" OFF)
    option(myprj_ENABLE_CACHE "Enable ccache" OFF)
  else()
    option(myprj_ENABLE_IPO "Enable IPO/LTO" ON)
    option(myprj_WARNINGS_AS_ERRORS "Treat Warnings As Errors" ON)
    option(myprj_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(myprj_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" ${SUPPORTS_ASAN})
    option(myprj_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(myprj_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" ${SUPPORTS_UBSAN})
    option(myprj_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(myprj_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(myprj_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(myprj_ENABLE_CLANG_TIDY "Enable clang-tidy" ON)
    option(myprj_ENABLE_CPPCHECK "Enable cpp-check analysis" ON)
    option(myprj_ENABLE_PCH "Enable precompiled headers" OFF)
    option(myprj_ENABLE_CACHE "Enable ccache" ON)
  endif()

  if(NOT PROJECT_IS_TOP_LEVEL)
    mark_as_advanced(
      myprj_ENABLE_IPO
      myprj_WARNINGS_AS_ERRORS
      myprj_ENABLE_USER_LINKER
      myprj_ENABLE_SANITIZER_ADDRESS
      myprj_ENABLE_SANITIZER_LEAK
      myprj_ENABLE_SANITIZER_UNDEFINED
      myprj_ENABLE_SANITIZER_THREAD
      myprj_ENABLE_SANITIZER_MEMORY
      myprj_ENABLE_UNITY_BUILD
      myprj_ENABLE_CLANG_TIDY
      myprj_ENABLE_CPPCHECK
      myprj_ENABLE_COVERAGE
      myprj_ENABLE_PCH
      myprj_ENABLE_CACHE)
  endif()

  myprj_check_libfuzzer_support(LIBFUZZER_SUPPORTED)
  if(LIBFUZZER_SUPPORTED AND (myprj_ENABLE_SANITIZER_ADDRESS OR myprj_ENABLE_SANITIZER_THREAD OR myprj_ENABLE_SANITIZER_UNDEFINED))
    set(DEFAULT_FUZZER ON)
  else()
    set(DEFAULT_FUZZER OFF)
  endif()

  option(myprj_BUILD_FUZZ_TESTS "Enable fuzz testing executable" ${DEFAULT_FUZZER})

endmacro()

macro(myprj_global_options)
  if(myprj_ENABLE_IPO)
    include(cmake/InterproceduralOptimization.cmake)
    myprj_enable_ipo()
  endif()

  myprj_supports_sanitizers()

  if(myprj_ENABLE_HARDENING AND myprj_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR myprj_ENABLE_SANITIZER_UNDEFINED
       OR myprj_ENABLE_SANITIZER_ADDRESS
       OR myprj_ENABLE_SANITIZER_THREAD
       OR myprj_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    message("${myprj_ENABLE_HARDENING} ${ENABLE_UBSAN_MINIMAL_RUNTIME} ${myprj_ENABLE_SANITIZER_UNDEFINED}")
    myprj_enable_hardening(myprj_options ON ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()
endmacro()

macro(myprj_local_options)
  if(PROJECT_IS_TOP_LEVEL)
    include(cmake/StandardProjectSettings.cmake)
  endif()

  add_library(myprj_warnings INTERFACE)
  add_library(myprj_options INTERFACE)

  include(cmake/CompilerWarnings.cmake)
  myprj_set_project_warnings(
    myprj_warnings
    ${myprj_WARNINGS_AS_ERRORS}
    ""
    ""
    ""
    "")

  if(myprj_ENABLE_USER_LINKER)
    include(cmake/Linker.cmake)
    myprj_configure_linker(myprj_options)
  endif()

  include(cmake/Sanitizers.cmake)
  myprj_enable_sanitizers(
    myprj_options
    ${myprj_ENABLE_SANITIZER_ADDRESS}
    ${myprj_ENABLE_SANITIZER_LEAK}
    ${myprj_ENABLE_SANITIZER_UNDEFINED}
    ${myprj_ENABLE_SANITIZER_THREAD}
    ${myprj_ENABLE_SANITIZER_MEMORY})

  set_target_properties(myprj_options PROPERTIES UNITY_BUILD ${myprj_ENABLE_UNITY_BUILD})

  if(myprj_ENABLE_PCH)
    target_precompile_headers(
      myprj_options
      INTERFACE
      <vector>
      <string>
      <utility>)
  endif()

  if(myprj_ENABLE_CACHE)
    include(cmake/Cache.cmake)
    myprj_enable_cache()
  endif()

  include(cmake/StaticAnalyzers.cmake)
  if(myprj_ENABLE_CLANG_TIDY)
    myprj_enable_clang_tidy(myprj_options ${myprj_WARNINGS_AS_ERRORS})
  endif()

  if(myprj_ENABLE_CPPCHECK)
    myprj_enable_cppcheck(${myprj_WARNINGS_AS_ERRORS} "" # override cppcheck options
    )
  endif()

  if(myprj_ENABLE_COVERAGE)
    include(cmake/Tests.cmake)
    myprj_enable_coverage(myprj_options)
  endif()

  if(myprj_WARNINGS_AS_ERRORS)
    check_cxx_compiler_flag("-Wl,--fatal-warnings" LINKER_FATAL_WARNINGS)
    if(LINKER_FATAL_WARNINGS)
      # This is not working consistently, so disabling for now
      # target_link_options(myprj_options INTERFACE -Wl,--fatal-warnings)
    endif()
  endif()

  if(myprj_ENABLE_HARDENING AND NOT myprj_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR myprj_ENABLE_SANITIZER_UNDEFINED
       OR myprj_ENABLE_SANITIZER_ADDRESS
       OR myprj_ENABLE_SANITIZER_THREAD
       OR myprj_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    myprj_enable_hardening(myprj_options OFF ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()

endmacro()
