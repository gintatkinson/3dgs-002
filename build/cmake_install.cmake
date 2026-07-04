# Install script for directory: /Users/perkunas/jail/3dgs-002/cesium_native_bridge

# Set the install prefix
if(NOT DEFINED CMAKE_INSTALL_PREFIX)
  set(CMAKE_INSTALL_PREFIX "/usr/local")
endif()
string(REGEX REPLACE "/$" "" CMAKE_INSTALL_PREFIX "${CMAKE_INSTALL_PREFIX}")

# Set the install configuration name.
if(NOT DEFINED CMAKE_INSTALL_CONFIG_NAME)
  if(BUILD_TYPE)
    string(REGEX REPLACE "^[^A-Za-z0-9_]+" ""
           CMAKE_INSTALL_CONFIG_NAME "${BUILD_TYPE}")
  else()
    set(CMAKE_INSTALL_CONFIG_NAME "Release")
  endif()
  message(STATUS "Install configuration: \"${CMAKE_INSTALL_CONFIG_NAME}\"")
endif()

# Set the component getting installed.
if(NOT CMAKE_INSTALL_COMPONENT)
  if(COMPONENT)
    message(STATUS "Install component: \"${COMPONENT}\"")
    set(CMAKE_INSTALL_COMPONENT "${COMPONENT}")
  else()
    set(CMAKE_INSTALL_COMPONENT)
  endif()
endif()

# Is this installation the result of a crosscompile?
if(NOT DEFINED CMAKE_CROSSCOMPILING)
  set(CMAKE_CROSSCOMPILING "FALSE")
endif()

# Set path to fallback-tool for dependency-resolution.
if(NOT DEFINED CMAKE_OBJDUMP)
  set(CMAKE_OBJDUMP "/usr/bin/objdump")
endif()

if(NOT CMAKE_INSTALL_LOCAL_ONLY)
  # Include the install script for the subdirectory.
  include("/Users/perkunas/jail/3dgs-002/build/cesium-native/cmake_install.cmake")
endif()

if(CMAKE_INSTALL_COMPONENT STREQUAL "Unspecified" OR NOT CMAKE_INSTALL_COMPONENT)
  file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/lib" TYPE SHARED_LIBRARY FILES "/Users/perkunas/jail/3dgs-002/build/libcesium_native_bridge.dylib")
  if(EXISTS "$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/lib/libcesium_native_bridge.dylib" AND
     NOT IS_SYMLINK "$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/lib/libcesium_native_bridge.dylib")
    execute_process(COMMAND /usr/bin/install_name_tool
      -delete_rpath "/Users/perkunas/jail/3dgs-002/build/cesium-native/Cesium3DTilesSelection"
      -delete_rpath "/Users/perkunas/jail/3dgs-002/build/cesium-native/Cesium3DTilesContent"
      -delete_rpath "/Users/perkunas/jail/3dgs-002/build/cesium-native/CesiumQuantizedMeshTerrain"
      -delete_rpath "/Users/perkunas/jail/3dgs-002/build/cesium-native/CesiumRasterOverlays"
      -delete_rpath "/Users/perkunas/jail/3dgs-002/build/cesium-native/CesiumJsonWriter"
      -delete_rpath "/Users/perkunas/jail/3dgs-002/build/cesium-native/CesiumVectorData"
      -delete_rpath "/Users/perkunas/jail/3dgs-002/build/cesium-native/Cesium3DTilesReader"
      -delete_rpath "/Users/perkunas/jail/3dgs-002/build/cesium-native/Cesium3DTiles"
      -delete_rpath "/Users/perkunas/jail/3dgs-002/build/cesium-native/CesiumGltfContent"
      -delete_rpath "/Users/perkunas/jail/3dgs-002/build/cesium-native/CesiumGeospatial"
      -delete_rpath "/Users/perkunas/jail/3dgs-002/build/cesium-native/CesiumGeometry"
      -delete_rpath "/Users/perkunas/jail/3dgs-002/build/cesium-native/CesiumGltfReader"
      -delete_rpath "/Users/perkunas/jail/3dgs-002/build/cesium-native/CesiumAsync"
      -delete_rpath "/Users/perkunas/jail/3dgs-002/build/cesium-native/CesiumGltf"
      -delete_rpath "/Users/perkunas/jail/3dgs-002/build/cesium-native/CesiumImage"
      -delete_rpath "/Users/perkunas/jail/3dgs-002/build/cesium-native/CesiumJsonReader"
      -delete_rpath "/Users/perkunas/jail/3dgs-002/build/cesium-native/CesiumUtility"
      -add_rpath "@executable_path/../Frameworks"
      "$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/lib/libcesium_native_bridge.dylib")
    if(CMAKE_INSTALL_DO_STRIP)
      execute_process(COMMAND "/usr/bin/strip" -x "$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/lib/libcesium_native_bridge.dylib")
    endif()
  endif()
endif()

if(CMAKE_INSTALL_COMPONENT STREQUAL "Unspecified" OR NOT CMAKE_INSTALL_COMPONENT)
endif()

if(CMAKE_INSTALL_COMPONENT STREQUAL "Unspecified" OR NOT CMAKE_INSTALL_COMPONENT)
  file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/include" TYPE DIRECTORY FILES "/Users/perkunas/jail/3dgs-002/cesium_native_bridge/include/")
endif()

string(REPLACE ";" "\n" CMAKE_INSTALL_MANIFEST_CONTENT
       "${CMAKE_INSTALL_MANIFEST_FILES}")
if(CMAKE_INSTALL_LOCAL_ONLY)
  file(WRITE "/Users/perkunas/jail/3dgs-002/build/install_local_manifest.txt"
     "${CMAKE_INSTALL_MANIFEST_CONTENT}")
endif()
if(CMAKE_INSTALL_COMPONENT)
  if(CMAKE_INSTALL_COMPONENT MATCHES "^[a-zA-Z0-9_.+-]+$")
    set(CMAKE_INSTALL_MANIFEST "install_manifest_${CMAKE_INSTALL_COMPONENT}.txt")
  else()
    string(MD5 CMAKE_INST_COMP_HASH "${CMAKE_INSTALL_COMPONENT}")
    set(CMAKE_INSTALL_MANIFEST "install_manifest_${CMAKE_INST_COMP_HASH}.txt")
    unset(CMAKE_INST_COMP_HASH)
  endif()
else()
  set(CMAKE_INSTALL_MANIFEST "install_manifest.txt")
endif()

if(NOT CMAKE_INSTALL_LOCAL_ONLY)
  file(WRITE "/Users/perkunas/jail/3dgs-002/build/${CMAKE_INSTALL_MANIFEST}"
     "${CMAKE_INSTALL_MANIFEST_CONTENT}")
endif()
