@echo off

if /i "%~1"=="prepare" goto prepare
if /i "%~1"=="finalize_android" goto finalize_android
exit /b 1

:prepare
setlocal enabledelayedexpansion
set "driver=!CJMP_TOOL_PATH!\tools\keels_tools\utils\lto_relink.py"
if not exist "!driver!" (
    echo error: lto relink driver not found: !driver! 1>&2
    endlocal & exit /b 1
)
set "verbose_arg="
if /i "!KEELS_VERBOSE!"=="1" set "verbose_arg=--verbose"
if /i "!KEELS_VERBOSE!"=="true" set "verbose_arg=--verbose"
python "!driver!" prepare --platform "%~2" --sdk-home "!CJMP_SDK_HOME!" --output "%~3\.keels\lto\build-env.bat" --format bat !verbose_arg!
set "result=!errorlevel!"
endlocal & exit /b %result%

:finalize_android
setlocal enabledelayedexpansion
set "driver=!CJMP_TOOL_PATH!\tools\keels_tools\utils\lto_relink.py"
if not exist "!driver!" (
    echo error: lto relink driver not found: !driver! 1>&2
    endlocal & exit /b 1
)
set "verbose_arg="
if /i "!KEELS_VERBOSE!"=="1" set "verbose_arg=--verbose"
if /i "!KEELS_VERBOSE!"=="true" set "verbose_arg=--verbose"
python "!driver!" finalize-android --sdk-home "!CJMP_SDK_HOME!" --ndk "!ANDROID_NDK_DIR!" --system-string "!SYSTEM_STRING!" --entry-lib "%~2" --package-dir "%~3" --project-root "%~4" --relink-dependency "%~f0" --link-profile windows --metadata-policy error !verbose_arg!
set "result=!errorlevel!"
endlocal & exit /b %result%
