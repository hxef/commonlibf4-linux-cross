-- A CommonLibF4 plugin includes this file from its own xmake.lua when it builds
-- on Linux. It adds what a Linux build of the Windows DLL needs on top of the
-- plugin itself, and README.md says what to install and why each part is here.

-- The xwin-clang-cl toolchain, which builds the Windows DLL on Linux
includes("xwin-clang-cl.lua")

-- The repo/ folder, whose spdlog package builds with xmake instead of cmake
add_repositories("linux-cross repo", { rootdir = os.scriptdir() })
