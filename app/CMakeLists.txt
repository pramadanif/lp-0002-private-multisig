cmake_minimum_required(VERSION 3.16)
project(PrivateMultisig VERSION 1.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)

# Concurrent is deliberately absent: Basecamp does not ship QtConcurrent, and a plugin linking a
# framework the host lacks cannot be loaded — the module installs and never appears.
find_package(Qt6 REQUIRED COMPONENTS Core Gui Widgets Qml Quick QuickWidgets)

# ── FFI shared library (built by build-basecamp.sh / check-basecamp-contract.sh) ──────────────
# The extension is not hardcoded: the same tree is configured on Linux by CI, where naming a .dylib
# fails to link with an error that says nothing about the platform.
if(APPLE)
    set(PMSIG_FFI_SUFFIX "dylib")
else()
    set(PMSIG_FFI_SUFFIX "so")
endif()
add_library(private_multisig_ffi SHARED IMPORTED)
set_target_properties(private_multisig_ffi PROPERTIES
    IMPORTED_LOCATION "${CMAKE_CURRENT_SOURCE_DIR}/lib/libpmsig_ffi.${PMSIG_FFI_SUFFIX}"
)

# ── Plugin (loaded by Basecamp) ────────────────────────────────────────────
add_library(PrivateMultisigPlugin SHARED
    src/PrivateMultisigBackend.cpp
    src/PrivateMultisigPlugin.cpp
)

# Resource name "private_multisig_qml" must match Q_INIT_RESOURCE(private_multisig_qml) in PrivateMultisigPlugin.cpp
qt_add_resources(PrivateMultisigPlugin "private_multisig_qml"
    PREFIX "/"
    FILES qml/Main.qml
)

target_link_libraries(PrivateMultisigPlugin PRIVATE
    Qt6::Core Qt6::Gui Qt6::Widgets Qt6::Qml Qt6::Quick Qt6::QuickWidgets
    private_multisig_ffi
)

# Output name must match manifest.json "main" value (lib<name>_plugin.so)
set_target_properties(PrivateMultisigPlugin PROPERTIES OUTPUT_NAME "private_multisig_plugin")

# ── Standalone preview app ─────────────────────────────────────────────────
add_executable(PrivateMultisigApp
    src/main.cpp
    src/PrivateMultisigBackend.cpp
    src/PrivateMultisigPlugin.cpp
)

# Same resource name as the plugin so Q_INIT_RESOURCE resolves in both targets
qt_add_resources(PrivateMultisigApp "private_multisig_qml"
    PREFIX "/"
    FILES qml/Main.qml
)

target_link_libraries(PrivateMultisigApp PRIVATE
    Qt6::Core Qt6::Gui Qt6::Widgets Qt6::Qml Qt6::Quick Qt6::QuickWidgets
    private_multisig_ffi
)

set_target_properties(PrivateMultisigApp PROPERTIES
    BUILD_RPATH "${CMAKE_CURRENT_SOURCE_DIR}/lib"
)

# ── Basecamp contract test ─────────────────────────────────────────────────
#
# Checks that this module still satisfies what Basecamp actually requires of it: the plugin object
# publishes the API (a QtRemoteObjects replica sees properties, signals and public slots), and
# Main.qml resolves that object through `logos.module()` rather than a context property only the
# standalone app provides. Run by scripts/check-basecamp-contract.sh.
add_executable(PrivateMultisigContractTest tests/module_contract_test.cpp)
target_link_libraries(PrivateMultisigContractTest PRIVATE
    Qt6::Core Qt6::Gui Qt6::Qml Qt6::Quick
)
