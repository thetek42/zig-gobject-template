#!/usr/bin/env sh
set -xe

mkdir -p windows/gtk/
pushd windows/gtk/
wget https://github.com/wingtk/gvsbuild/releases/download/2024.9.0/GTK4_Gvsbuild_2024.9.0_x64.zip --output-document gvsbuild.zip
unzip gvsbuild.zip
rm gvsbuild.zip
popd

mkdir -p windows/vulkan/lib/
pushd windows/vulkan/lib/
wget https://github.com/xfitgd/zig-game-engine-project/raw/2fb8d63dbc681a3a038fa8ef03066379057a7178/lib/windows/vulkan.lib --output-document vulkan.lib
popd
