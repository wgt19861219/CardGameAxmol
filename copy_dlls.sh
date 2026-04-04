#!/bin/bash
# 编译后自动复制 DLL 到输出目录
ENGINE_ROOT="D:/workspace/projects/AxmolEngine"
BUILD_DIR="D:/workspace/projects/CardGameAxmol/build"

copy_dlls() {
    local config=$1  # Debug or Release
    local dest="$BUILD_DIR/bin/CardGame/$config"
    local bin_src="$BUILD_DIR/bin/$config"
    local engine_libs="$ENGINE_ROOT/3rdparty"
    
    if [ ! -d "$dest" ]; then
        echo "目录不存在: $dest"
        return 1
    fi
    
    echo "复制 DLL 到 $dest ..."
    
    # 从 Release/Debug bin 目录复制编译产物
    cp "$bin_src/plainlua.dll" "$dest/" 2>/dev/null
    
    # 第三方 DLL（Debug/Release 通用）
    cp "$BUILD_DIR/bin/CardGame/Debug/OpenAL32.dll" "$dest/" 2>/dev/null
    cp "$BUILD_DIR/bin/CardGame/Debug/WebView2Loader.dll" "$dest/" 2>/dev/null
    
    # Angle (OpenGL ES -> D3D11)
    cp "$engine_libs/angle/_x/lib/win32/x64/libGLESv2.dll" "$dest/" 2>/dev/null
    cp "$engine_libs/angle/_x/lib/win32/x64/libEGL.dll" "$dest/" 2>/dev/null
    
    # d3dcompiler_47
    cp "/c/Program Files (x86)/Windows Kits/10/bin/10.0.26100.0/x64/d3dcompiler_47.dll" "$dest/" 2>/dev/null
    
    # OpenSSL
    cp "$engine_libs/openssl/_x/lib/win32/x64/libssl-3-x64.dll" "$dest/" 2>/dev/null
    cp "$engine_libs/openssl/_x/lib/win32/x64/libcrypto-3-x64.dll" "$dest/" 2>/dev/null
    
    # curl
    cp "$engine_libs/curl/_x/lib/win32/x64/libcurl.dll" "$dest/" 2>/dev/null
    
    # zlib
    cp "$engine_libs/zlib/_x/lib/win32/x64/zlib1.dll" "$dest/" 2>/dev/null
    
    echo "DLL 复制完成: $dest"
    ls "$dest/"*.dll 2>/dev/null
}

# 根据参数复制对应配置的 DLL
if [ "$1" = "both" ] || [ -z "$1" ]; then
    copy_dlls "Release"
    copy_dlls "Debug"
else
    copy_dlls "$1"
fi
