# CommonLibF4 Linux cross build

Builds a [CommonLibF4](https://github.com/libxse/commonlibf4) plugin on Linux.
An F4SE plugin is a 64-bit Windows DLL that has to be built the way Microsoft's
compiler builds it, even on Linux. So this is a cross build, which means the DLL
is built on Linux for Windows. It uses clang-cl, a version of the clang compiler
that works like Microsoft's, and F4SE then loads the DLL into Fallout 4 running
under Proton.

## Adding it to a plugin

A plugin laid out like the
[CommonLibF4 template](https://github.com/libxse/commonlibf4-template) adds this
repository as a git submodule, which is a repository kept inside another one:

```sh
git submodule add https://github.com/hxef/commonlibf4-linux-cross.git contrib/linux-cross
```

Then the plugin's `xmake.lua` includes it right after CommonLibF4, and only when
it builds on Linux:

```lua
-- include subprojects
includes("lib/commonlibf4")

if is_host("linux") then
    includes("contrib/linux-cross")
end
```

A Windows build never reads this repository, so it stays exactly like the
template's build. A Linux build needs the submodule downloaded, which
`git clone --recurse-submodules` does. Without it, xmake warns that
`includes("contrib/linux-cross")` finds no files, and the build fails.

## Setup

Install LLVM 19 or newer and make sure `clang-cl`, `lld-link`, `llvm-ar` and
`llvm-rc` are on `PATH`. The Microsoft C++ standard library that xwin downloads
stops the build with an error on an older clang.

Then download the Microsoft headers and libraries once with
[xwin](https://github.com/Jake-Shadle/xwin). They are Microsoft's C and C++
standard libraries (the CRT) and the Windows SDK. `--accept-license` says that
you accept the Visual Studio license they come with:

```sh
xwin --accept-license --arch x86_64 splat --output ~/.xwin
```

This fills `~/.xwin`, the xwin folder. If you put it somewhere else, set
`XWIN_ROOT` to that folder.

## Building

From the plugin's top folder:

```sh
xmake f -p windows -a x64 -m releasedbg --toolchain=xwin-clang-cl
xmake build
```

Pass the same flags whenever you run `xmake f` again. Without them, xmake sets
the build up for Linux instead.

## What is in here

`xmake.lua` is the file the plugin includes. It loads the xwin-clang-cl
toolchain and adds `repo/` as a package repository, a folder where xmake looks
for packages.

`xwin-clang-cl.lua` is the xwin-clang-cl toolchain, which tells xmake what
compiler, linker and flags to use. It points clang-cl and lld-link at the
Microsoft headers and libraries in the xwin folder, because xmake's own clang-cl
toolchain looks for a Visual Studio install, which never exists on Linux.

`repo/` holds 1 package, spdlog, which xmake uses in place of the one from
[xmake-repo](https://github.com/xmake-io/xmake-repo), xmake's official package
collection. CommonLibF4 needs spdlog as a compiled library. The xmake-repo
package compiles it with cmake, and xmake's cmake support stops with an error
whenever it builds for Windows and finds no Visual Studio:

```lua
-- xmake/modules/package/tools/cmake.lua
local msvc = package:toolchain("msvc")
assert(msvc:check(), "vs not found!")
```

Linux never has Visual Studio, so this check always fails there. Using spdlog as
header only, where all of its code sits in the header files, does not work
either. In that mode, spdlog's `os.h` includes `os-inl.h`, which includes
`<windows.h>`. That file defines `MAX_PATH` and `ERROR` as macros, which are
names the compiler swaps for a value before it reads the code. They break
`REX::W32::MAX_PATH` and `REX::ERROR` all over CommonLibF4.

So the spdlog package in `repo/` compiles spdlog's few source files with xmake
instead of cmake. It is adapted from the spdlog package of xmake-repo, and its
versions, options and defines match that package.

## License

Apache-2.0, the same license as xmake-repo, because the spdlog package in
`repo/` is adapted from xmake-repo's. See [LICENSE](LICENSE) and
[NOTICE](NOTICE).
