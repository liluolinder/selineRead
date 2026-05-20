@echo off
cd /d "%~dp0"
set "SCRIPT_DIR=%CD%"
setlocal enabledelayedexpansion

@REM Build configuration
set buildType=%1
set buildTarget=%2
set cangjieFolder=cangjie-%buildTarget%

@REM Base paths
set CJMP_UI_PATH=!CJMP_SDK_HOME!\cjmp-ui
set CJMP_ENGINE_PATH=!CJMP_SDK_HOME!\ui-engine
set CJMP_TOOL_PATH=!CJMP_SDK_HOME!\cjmp-tools
set CJMP_LIBS_PATH=!CJMP_SDK_HOME!\cjmp-libs
set CANGJIE_STDX_PATH=!CJMP_TOOL_PATH!/third_party/cangjie-stdx

@REM Platform-specific configuration
if "%buildTarget%"=="android" (
    set cangjieTarget=aarch64-linux-android26
    set ANDROID_CJ_FRONTEND=!CJMP_UI_PATH!\android
    set ANDROID_NDK_DIR=!ANDROID_SDK_ROOT!\ndk\26.3.11579264
    set ANDROID_ENGINE_PATH=!CJMP_ENGINE_PATH!\android
    set ANDROID_CANGJIE_PATH=!CJMP_TOOL_PATH!\third_party\cangjie-android
    set ANDROID_CANGJIE_STDX_PATH=!CANGJIE_STDX_PATH!\linux_android_aarch64_cjnative\dynamic\stdx
    set ANDROID_CJMP_LIBS_PATH=!CJMP_LIBS_PATH!\android\dynamic
    set ANDROID_BRIDGE=!SCRIPT_DIR!\android\app\build\intermediates\cmake\!buildType!\obj\arm64-v8a
    set lib_share_path=!ANDROID_NDK_DIR!\toolchains\llvm\prebuilt\windows-x86_64\sysroot\usr\lib\aarch64-linux-android\libc++_shared.so
    set SYSTEM_STRING=windows-x86_64
)

@REM Build type configuration
if "%buildType%"=="debug" (
    set cangjieExtraArgs=-g
) else (
    set cangjieExtraArgs=
)

@REM Build cangjie libraries
set build_path=!SCRIPT_DIR!\build
set src_path=!SCRIPT_DIR!\lib

cd /d "!src_path!"
call "!CJMP_TOOL_PATH!\third_party\!cangjieFolder!\envsetup.bat"
cjpm build --no-feature-deduce --target-dir=!build_path! --target=!cangjieTarget! !cangjieExtraArgs!
if errorlevel 1 (
    echo Error: cjpm build failed with errorlevel !errorlevel!
    exit /b 1
)
cd /d "!SCRIPT_DIR!"

set inputDir=!build_path!\!cangjieTarget!\!buildType!\ohos_app_cangjie_entry
echo Input directory: !inputDir!

if "%buildTarget%"=="android" (
    @REM output: dependency storage path
    set outputDir=!SCRIPT_DIR!\android\app\libs

    if exist "!outputDir!\" rmdir /s /q "!outputDir!"
    mkdir "!outputDir!"
    mkdir "!outputDir!\arm64-v8a"

    @REM copy: main library files
    call :copy_libs "!ANDROID_ENGINE_PATH!" "!outputDir!" "jar"
    call :copy_libs "!inputDir!" "!outputDir!\arm64-v8a" "so" "cjo"
    call :copy_libs "!ANDROID_BRIDGE!" "!outputDir!\arm64-v8a" "so"

    @REM copy: library dependencies
    call :analyze_dependencies "!outputDir!\arm64-v8a" "android" "!ANDROID_CANGJIE_PATH!" "!ANDROID_CJ_FRONTEND!" "!ANDROID_CANGJIE_STDX_PATH!" "!ANDROID_CJMP_LIBS_PATH!"
    call :copy_dependencies "!outputDir!\arm64-v8a" "!DEP_FILE!"

    @REM copy: additional dependencies
    copy /y "!ANDROID_ENGINE_PATH!\arm64-v8a\libkeels_android.so" "!outputDir!\arm64-v8a\" >nul
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
