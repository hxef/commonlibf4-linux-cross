-- The spdlog package, changed so that it builds on Linux for Windows. It is
-- adapted from the spdlog package of xmake-repo
-- (https://github.com/xmake-io/xmake-repo).
--
-- xmake-repo's package compiles spdlog with cmake, and xmake's cmake support
-- (modules/package/tools/cmake.lua) stops with "vs not found!" whenever it
-- builds for Windows and finds no Visual Studio, which Linux never has. Using
-- spdlog as header only, with all of its code in the headers, fails too: its
-- os.h then includes <windows.h>, whose MAX_PATH and ERROR macros break
-- REX::W32::MAX_PATH and REX::ERROR all over CommonLibF4.
--
-- So this package compiles spdlog's few source files with xmake instead of
-- cmake. Its versions, options and defines match the xmake-repo package.
package("spdlog")
    set_homepage("https://github.com/gabime/spdlog")
    set_description("Fast C++ logging library.")
    set_license("MIT")

    add_urls("https://github.com/gabime/spdlog/archive/refs/tags/$(version).zip",
             "https://github.com/gabime/spdlog.git")

    add_versions("v1.16.0", "3d25808d2fc4db86621a46855800c99ab5734999b61c4cbf9470edf631555397")

    add_configs("header_only",     {description = "Use header only version.", default = true, type = "boolean"})
    add_configs("std_format",      {description = "Use std::format instead of fmt library.", default = false, type = "boolean"})
    add_configs("fmt_external",    {description = "Use external fmt library instead of bundled.", default = false, type = "boolean"})
    add_configs("fmt_external_ho", {description = "Use external fmt header-only library.", default = false, type = "boolean"})
    add_configs("noexcept",        {description = "Compile with -fno-exceptions.", default = false, type = "boolean"})
    add_configs("tls",             {description = "Allow spdlog to use thread local storage.", default = true, type = "boolean"})
    add_configs("thread_id",       {description = "Allow spdlog to query the thread id on each log call.", default = true, type = "boolean"})
    add_configs("wchar",           {description = "Support wchar api.", default = false, type = "boolean"})
    add_configs("wchar_filenames", {description = "Support wchar filenames.", default = false, type = "boolean"})
    add_configs("wchar_console",   {description = "Support wchar output to console.", default = false, type = "boolean"})

    on_load(function (package)
        if package:config("header_only") then
            package:set("kind", "library", {headeronly = true})
        else
            package:add("defines", "SPDLOG_COMPILED_LIB")
        end
        if package:config("std_format") then
            package:add("defines", "SPDLOG_USE_STD_FORMAT")
        end
        if package:config("wchar") then
            package:add("defines", "SPDLOG_WCHAR_TO_UTF8_SUPPORT")
        end
        if package:config("wchar_filenames") then
            package:add("defines", "SPDLOG_WCHAR_FILENAMES")
        end
    end)

    on_install(function (package)
        if package:config("header_only") then
            os.cp("include", package:installdir())
            return
        end

        local defines = {"SPDLOG_COMPILED_LIB"}
        if package:config("std_format") then
            table.insert(defines, "SPDLOG_USE_STD_FORMAT")
        end
        if package:config("wchar") then
            table.insert(defines, "SPDLOG_WCHAR_TO_UTF8_SUPPORT")
        end
        if package:config("wchar_filenames") then
            table.insert(defines, "SPDLOG_WCHAR_FILENAMES")
        end
        if package:config("wchar_console") then
            table.insert(defines, "SPDLOG_UTF8_TO_WCHAR_CONSOLE")
        end
        if not package:config("tls") then
            table.insert(defines, "SPDLOG_NO_TLS")
        end
        if not package:config("thread_id") then
            table.insert(defines, "SPDLOG_NO_THREAD_ID")
        end

        -- spdlog's own sources are C++17, but std::format needs C++20.
        local languages = package:config("std_format") and "c++20" or "c++17"

        io.writefile("xmake.lua", format([[
target("spdlog")
    set_kind("static")
    set_languages("%s")
    add_files("src/*.cpp")
    add_includedirs("include")
    add_headerfiles("include/(spdlog/**.h)")
    add_defines(%s)
    if is_plat("windows") then
        add_cxflags("/EHsc")
    end
]], languages, table.concat(
        table.imap(defines, function (_, d) return '"' .. d .. '"' end), ", ")))

        import("package.tools.xmake").install(package)
    end)
