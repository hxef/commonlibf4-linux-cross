-- The xwin-clang-cl toolchain builds a 64-bit Windows DLL on Linux. It runs
-- clang-cl and lld-link, the LLVM compiler and linker that work like
-- Microsoft's, with the Microsoft headers and libraries that xwin
-- (https://github.com/Jake-Shadle/xwin) downloads:
--
--     xwin --accept-license --arch x86_64 splat --output ~/.xwin
--
-- Set XWIN_ROOT if the xwin folder is not ~/.xwin. Any xmake project uses the
-- toolchain like this:
--
--     xmake f -p windows -a x64 --toolchain=xwin-clang-cl
--     xmake build
toolchain("xwin-clang-cl")
    set_kind("standalone")
    set_homepage("https://github.com/Jake-Shadle/xwin")
    set_description("clang-cl + lld-link targeting Windows x64 from a Linux host")
    set_runtimes("MT", "MTd", "MD", "MDd")

    -- xmake's tool names: cc and cxx compile C and C++, ld links programs, sh
    -- links DLLs, ar builds static libraries and mrc compiles Windows resource
    -- files (.rc).
    set_toolset("cc", "clang-cl")
    set_toolset("cxx", "clang-cl")
    -- bin/lld-link runs lld-link and keeps the full paths of library folders
    -- out of the PDB.
    set_toolset("ld", path.join(os.scriptdir(), "bin", "lld-link"))
    set_toolset("sh", path.join(os.scriptdir(), "bin", "lld-link"))
    set_toolset("ar", "llvm-ar")
    set_toolset("mrc", "llvm-rc")

    -- xmake's own clang-cl toolchain looks for a Visual Studio install, which
    -- never exists on Linux. This toolchain only checks for the xwin folder.
    on_check(function (toolchain)
        local xwin = os.getenv("XWIN_ROOT") or path.join(os.getenv("HOME"), ".xwin")
        return os.isdir(path.join(xwin, "crt", "include"))
    end)

    on_load(function (toolchain)
        local xwin = os.getenv("XWIN_ROOT") or path.join(os.getenv("HOME"), ".xwin")

        -- Build for 64-bit Windows, the way Microsoft's compiler does.
        toolchain:add("cxflags", "--target=x86_64-pc-windows-msvc")
        -- The compiler looks for the Microsoft headers in these folders. -imsvc
        -- marks them as folders of system headers, so warnings inside those
        -- headers stay out of the build output.
        for _, dir in ipairs({
            "crt/include",
            "sdk/include/ucrt",
            "sdk/include/um",
            "sdk/include/shared"
        }) do
            toolchain:add("cxflags", "-imsvc" .. path.join(xwin, dir))
        end

        -- llvm-rc looks in these folders for the Windows headers that .rc
        -- files include.
        toolchain:add("mrcflags", "-I" .. path.join(xwin, "sdk", "include", "um"))
        toolchain:add("mrcflags", "-I" .. path.join(xwin, "sdk", "include", "shared"))

        -- lld-link finds the Microsoft .lib files in these folders.
        for _, dir in ipairs({
            "crt/lib/x86_64",
            "sdk/lib/um/x86_64",
            "sdk/lib/ucrt/x86_64"
        }) do
            toolchain:add("ldflags", "-libpath:" .. path.join(xwin, dir))
            toolchain:add("shflags", "-libpath:" .. path.join(xwin, dir))
        end

        -- The PDB, the debug file next to the DLL, ships with the plugin, and
        -- full paths in it would show the user name. So the compiler records
        -- the folder it runs in as ".", the project as ".", the xwin folder as
        -- xwin and the rest of the home folder as HOME, and leaves out its own
        -- command line. The last map that fits a path wins, so the home
        -- folder's map comes before the maps for folders inside it. Never map
        -- to ~, because clang turns a leading ~ back into the home folder in
        -- the names of lambdas.
        toolchain:add("cxflags", "/clang:-fdebug-compilation-dir=.")
        local home = os.getenv("HOME")
        if home then
            toolchain:add("cxflags", "/clang:-ffile-prefix-map=" .. home .. "=HOME")
        end
        toolchain:add("cxflags", "/clang:-ffile-prefix-map=" .. xwin .. "=xwin")
        toolchain:add("cxflags", "/clang:-ffile-prefix-map=" .. os.projectdir() .. "=.")
        toolchain:add("cxflags", "/clang:-gno-codeview-command-line")

        -- The DLL names its PDB by file name only, and lld-link keeps relative
        -- paths relative instead of putting its own folder in front.
        for _, flags in ipairs({ "ldflags", "shflags" }) do
            toolchain:add(flags, "/pdbaltpath:%_PDB%")
            toolchain:add(flags, "/pdbsourcepath:.")
        end
    end)
toolchain_end()
