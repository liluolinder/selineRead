@echo off
cd /d "%~dp0"
set "SCRIPT_DIR=%CD%"
setlocal enabledelayedexpansion
set "LTO_HELPER=%SCRIPT_DIR%\lto_build_helper.bat"
@REM Use the same Tools source as the CLI, including profile argument parsing.
set "ACTIVE_TOOLS_SOURCE_ROOT=!KEELS_ACTIVE_TOOLS_SOURCE_ROOT!"
if not defined ACTIVE_TOOLS_SOURCE_ROOT set "ACTIVE_TOOLS_SOURCE_ROOT=!CJMP_SDK_HOME!\cjmp-tools\tools"
set "BUILD_ARGS_PARSER=!ACTIVE_TOOLS_SOURCE_ROOT!\keels_tools\utils\parse_build_args.py"
set "BUILD_ARGS_FILE=%TEMP%\keels_build_args_%RANDOM%%RANDOM%.bat"

if not exist "!BUILD_ARGS_PARSER!" (
    echo error: build argument parser not found: !BUILD_ARGS_PARSER! 1>&2
    exit /b 1
)
python "!BUILD_ARGS_PARSER!" --format bat --program "%~nx0" -- %* > "!BUILD_ARGS_FILE!"
if errorlevel 1 (
    if exist "!BUILD_ARGS_FILE!" del /f /q "!BUILD_ARGS_FILE!" >nul 2>&1
    exit /b 1
)
call "!BUILD_ARGS_FILE!"
set "build_args_result=!errorlevel!"
del /f /q "!BUILD_ARGS_FILE!" >nul 2>&1
if not "!build_args_result!"=="0" exit /b !build_args_result!

@REM Build configuration
set buildType=%1
set buildTarget=%2
set cangjieFolder=cangjie-%buildTarget%
set "use_lto=false"
if defined KEELS_LTO (
    if /i "%KEELS_LTO%"=="1" set "use_lto=true"
    if /i "%KEELS_LTO%"=="true" set "use_lto=true"
)
if /i "!ltoRequested!"=="true" (
    set "use_lto=true"
)
if /i "!use_lto!"=="true" if not exist "!LTO_HELPER!" (
    echo error: lto helper not found: !LTO_HELPER!
    exit /b 1
)

@REM Base paths
set CJMP_UI_PATH=!CJMP_SDK_HOME!\cjmp-ui
set CJMP_ENGINE_PATH=!CJMP_SDK_HOME!\ui-engine
set CJMP_TOOL_PATH=!CJMP_SDK_HOME!\cjmp-tools
set CJMP_TEST_PATH=!CJMP_SDK_HOME!\cjmp-test
set CJMP_LIBS_PATH=!CJMP_SDK_HOME!\cjmp-libs
set CJMP_TOOLS_LIBS_PATH=!CJMP_TOOL_PATH!\libs
@REM Prefer an externally configured stdx (e.g. CANGJIE_STDX_PATH) so host target sections of
@REM path dependencies validate; fall back to the CJMP bundled stdx.
if not defined CANGJIE_STDX_PATH set "CANGJIE_STDX_PATH=!CJMP_TOOL_PATH!\third_party\cangjie-stdx"

@REM Platform-specific configuration
if "%buildTarget%"=="android" (
    set cangjieTarget=aarch64-linux-android26
    set ANDROID_CJ_FRONTEND=!CJMP_UI_PATH!\android\dynamic\ohos
    set ANDROID_CJ_MACRO=!CJMP_UI_PATH!\android\macro\ohos
    if not defined ANDROID_NDK_DIR (
        echo Android NDK path was not provided by the build environment. 1>&2
        exit /b 3
    )
    if not exist "!ANDROID_NDK_DIR!\." (
        echo Android NDK directory does not exist: !ANDROID_NDK_DIR! 1>&2
        exit /b 3
    )
    set ANDROID_ENGINE_PATH=!CJMP_ENGINE_PATH!\android
    if not defined ANDROID_PROFILE_ENGINE_LIB_PATH set "ANDROID_PROFILE_ENGINE_LIB_PATH=!CJMP_ENGINE_PATH!\android\arm64-v8a\profile\libkeels_android.so"
    set ANDROID_CANGJIE_PATH=!CJMP_TOOL_PATH!\third_party\cangjie-android
    set ANDROID_CANGJIE_RUNTIME_PATH=!ANDROID_CANGJIE_PATH!\runtime\lib\linux_android_aarch64_cjnative
    set ANDROID_CANGJIE_STDX_PATH=!CJMP_TOOL_PATH!\third_party\cangjie-stdx\linux_android_aarch64_cjnative\dynamic\stdx
    set ANDROID_CJMP_LIBS_PATH=!CJMP_LIBS_PATH!\android\dynamic
    if not defined cmakeBridgePath (
        set FFI_BRIDGE=!SCRIPT_DIR!\android\app\build\intermediates\cmake\!buildType!\obj\arm64-v8a
    ) else (
        set "FFI_BRIDGE=!cmakeBridgePath!"
    )
    set lib_share_path=!ANDROID_NDK_DIR!\toolchains\llvm\prebuilt\windows-x86_64\sysroot\usr\lib\aarch64-linux-android\libc++_shared.so
    set SYSTEM_STRING=windows-x86_64
    set ANDROID_TEST_PATH=!CJMP_TEST_PATH!\android\ohos
    set SYSTEM_STRING=windows-x86_64
    set lib_share_path=!ANDROID_NDK_DIR!\toolchains\llvm\prebuilt\!SYSTEM_STRING!\sysroot\usr\lib\aarch64-linux-android\libc++_shared.so
)

if /i "!use_lto!"=="true" (
    call "!LTO_HELPER!" prepare android "!SCRIPT_DIR!"
    if errorlevel 1 exit /b 1
    call "!SCRIPT_DIR!\.keels\lto\build-env.bat"
    if errorlevel 1 exit /b 1
)

@REM Build type configuration
if "%buildType%"=="debug" (
    set cangjieExtraArgs=-g --debug
) else (
    set cangjieExtraArgs=--release
)

@REM Build cangjie libraries
set build_path=!SCRIPT_DIR!\build
set "SCRIPT_BUILD_PATH=!build_path!\!cangjieTarget!\!buildType!"
if defined KEELS_CJ_SRC_PATH (
    set src_path=!KEELS_CJ_SRC_PATH!
) else (
    set src_path=!SCRIPT_DIR!\lib
)
if defined KEELS_CJ_PACKAGE_NAME (
    set cangjiePackageName=!KEELS_CJ_PACKAGE_NAME!
) else (
    set cangjiePackageName=ohos_app_cangjie_entry
)
set featureArgs=
if defined KEELS_LTO_CJPM_ARGS set featureArgs=!featureArgs! !KEELS_LTO_CJPM_ARGS!

cd /d "!src_path!"
call "!CJMP_TOOL_PATH!\third_party\!cangjieFolder!\envsetup.bat"
if "%buildTarget%"=="android" (
    if not exist "!SCRIPT_BUILD_PATH!\java\" mkdir "!SCRIPT_BUILD_PATH!\java"
    copy /y "!ANDROID_CANGJIE_RUNTIME_PATH!\libjava.internal.so" "!SCRIPT_BUILD_PATH!\java\" >nul
    copy /y "!ANDROID_CANGJIE_PATH!\modules\linux_android_aarch64_cjnative\java.internal.cjo" "!SCRIPT_BUILD_PATH!\java\" >nul
    copy /y "!ANDROID_CANGJIE_RUNTIME_PATH!\libjava.lang.so" "!SCRIPT_BUILD_PATH!\java\" >nul
    copy /y "!ANDROID_CANGJIE_PATH!\modules\linux_android_aarch64_cjnative\java.lang.cjo" "!SCRIPT_BUILD_PATH!\java\" >nul
)

cjpm build --target-dir=!build_path! --target=!cangjieTarget! !cangjieExtraArgs! !featureArgs!
if errorlevel 1 (
    echo Error: cjpm build failed with errorlevel !errorlevel!
    exit /b 1
)
cd /d "!SCRIPT_DIR!"

set packageOutputRoot=!build_path!\!cangjieTarget!\!buildType!
set sourceSet=android
if "!KEELS_IS_TEST_BUILD!"=="true" (
    set inputDir=!packageOutputRoot!\!cangjiePackageName!
) else (
    set inputDir=!packageOutputRoot!\!cangjiePackageName!\!sourceSet!\product
)
echo Input directory: !inputDir!

if "%buildTarget%"=="android" (
    @REM output: dependency storage path
    set outputDir=!SCRIPT_DIR!\android\app\libs
    if exist "!outputDir!\" rmdir /s /q "!outputDir!"
    mkdir "!outputDir!"
    mkdir "!outputDir!\arm64-v8a"

    @REM copy: main library files

    @REM EntryEntryAbilityActivity imports cangjie.lang.LibraryLoader.
    @REM The class is provided by the standalone Cangjie Android JAR.
    if not exist "!ANDROID_CANGJIE_PATH!\lib\library-loader.jar" (
        echo error: "!ANDROID_CANGJIE_PATH!\lib\library-loader.jar" not exist 1>&2
        exit /b 1
    )
    copy /y "!ANDROID_CANGJIE_PATH!\lib\library-loader.jar" "!outputDir!\" >nul
    call :copy_libs "!ANDROID_ENGINE_PATH!" "!outputDir!" "jar"
    call :copy_package_libs "!inputDir!" "!outputDir!\arm64-v8a" "false"

    @REM copy: library dependencies
    call :analyze_dependencies "!outputDir!\arm64-v8a" "android" "!packageOutputRoot!" "!ANDROID_CANGJIE_RUNTIME_PATH!" "!ANDROID_CJ_FRONTEND!" "!ANDROID_CANGJIE_STDX_PATH!" "!ANDROID_CJMP_LIBS_PATH!" "!ANDROID_TEST_PATH!"
    call :copy_dependencies "!outputDir!\arm64-v8a" "!DEP_FILE!"

    @REM copy: additional dependencies
    if "%buildProfile%"=="true" (
        copy /y "!ANDROID_PROFILE_ENGINE_LIB_PATH!" "!outputDir!\arm64-v8a\" >nul
        copy /y "!CJMP_TOOLS_LIBS_PATH!\android\libdevtools_debugger.so" "!outputDir!\arm64-v8a\" >nul
    ) else (
        copy /y "!ANDROID_ENGINE_PATH!\arm64-v8a\libkeels_android.so" "!outputDir!\arm64-v8a\" >nul
    )
    if /i "!use_lto!"=="true" (
        call "!LTO_HELPER!" finalize_android "!inputDir!\libohos_app_cangjie_entry.so" "!outputDir!\arm64-v8a" "!SCRIPT_DIR!"
        if errorlevel 1 exit /b 1
    )
    copy /y "!lib_share_path!" "!outputDir!\arm64-v8a\" >nul
)

echo Build completed successfully!
goto :EOF

@REM ---------- Subfunctions ----------

:copy_libs
setlocal enabledelayedexpansion
set "input_dir=%~1"
set "output_dir=%~2"
shift & shift

if not exist "!input_dir!\" (
    echo error: !input_dir! not exist
    exit /b 1
)

set file_count=0

@REM Process each extension
:ext_loop
if "%~1"=="" goto ext_done
set "ext=%~1"
if "!ext:~0,1!"=="." set "ext=!ext:~1!"

@REM Search only in current directory (not subdirectories)
for %%f in ("!input_dir!\*.!ext!") do (
    if exist "%%f" (
        copy /y "%%f" "!output_dir!\" >nul
        set /a file_count+=1
    )
)
shift
goto ext_loop

:ext_done
if !file_count! gtr 0 (
    echo Copied !file_count! files to !output_dir!
) else (
    echo No matching files found in !input_dir!
)
endlocal & exit /b 0

:analyze_dependencies
setlocal enabledelayedexpansion
set "target_dir=%~1"
set "platform=%~2"
shift
shift

set "search_paths="
:path_loop
if "%~1"=="" goto path_done
set "search_paths=!search_paths! "%~1""
shift
goto path_loop

:path_done
if not exist "!target_dir!\" (
    echo Error: !target_dir! does not exist
    exit /b 1
)

set PYTHON_SCRIPT="!CJMP_TOOL_PATH!\Tools\keels_tools\utils\dependency.py"

set "dep_file=%TEMP%\cj_deps_%RANDOM%%RANDOM%.txt"
if exist "!dep_file!" del /f /q "!dep_file!" >nul 2>&1

for /f "usebackq delims=" %%i in (`
    python "!PYTHON_SCRIPT!" "!target_dir!" "!platform!" !search_paths!
`) do (
    >>"!dep_file!" echo %%i
)

endlocal & set "DEP_FILE=%dep_file%" & exit /b 0

:copy_dependencies
setlocal enabledelayedexpansion
set "output_dir=%~1"
set "dep_file=%~2"

if not exist "!output_dir!\" mkdir "!output_dir!"

set copied_count=0

if not exist "!dep_file!" (
    echo Warning: dependency list file not found: !dep_file!
    endlocal & exit /b 0
)

for /f "usebackq delims=" %%p in ("!dep_file!") do (
    set "dep_path=%%p"
    set "dep_path=!dep_path:"=!"
    if exist "!dep_path!" (
        copy /y "!dep_path!" "!output_dir!\" >nul
        set /a copied_count+=1
    )
)

if !copied_count! gtr 0 (
    echo Copied !copied_count! dependency files to !output_dir!
)

del /f /q "!dep_file!" >nul 2>&1

endlocal & exit /b 0

:copy_package_libs
setlocal enabledelayedexpansion
set "input_dir=%~1"
set "output_dir=%~2"
set "copy_cjo=%~3"

if not exist "!input_dir!\" (
    echo error: !input_dir! not exist
    exit /b 1
)

if not exist "!output_dir!\" (
    echo error: !output_dir! not exist
    exit /b 1
)

set "cache_file=!input_dir!\incremental-cache.json"
if not exist "!cache_file!" (
    echo Warning: incremental-cache.json not found, copying all files
    if /i "!copy_cjo!"=="true" (
        call :copy_libs "!input_dir!" "!output_dir!" "so" "cjo"
    ) else (
        call :copy_libs "!input_dir!" "!output_dir!" "so"
    )
    exit /b 0
)

set file_count=0

@REM Use Python to parse JSON and extract package names, then copy files directly
for /f "delims=" %%p in ('python -c "import json; data=json.load(open(r'!cache_file!')); print('\n'.join(data.get('packageInformation', {}).keys()))" 2^>nul') do (
    set "pkg_name=%%p"

    @REM Copy .so file
    set "so_file=!input_dir!\lib!pkg_name!.so"
    if exist "!so_file!" (
        copy /y "!so_file!" "!output_dir!\" >nul
        set /a file_count+=1
    )

    @REM Copy .cjo file (only if copy_cjo is true)
    if /i "!copy_cjo!"=="true" (
        set "cjo_file=!input_dir!\!pkg_name!.cjo"
        if exist "!cjo_file!" (
            copy /y "!cjo_file!" "!output_dir!\" >nul
            set /a file_count+=1
        )
    )
)

if !file_count! equ 0 (
    echo Warning: No packages found in incremental-cache.json, copying all .so files
    if /i "!copy_cjo!"=="true" (
        call :copy_libs "!input_dir!" "!output_dir!" "so" "cjo"
    ) else (
        call :copy_libs "!input_dir!" "!output_dir!" "so"
    )
) else (
    echo Copied !file_count! files to !output_dir!
)
endlocal & exit /b 0
