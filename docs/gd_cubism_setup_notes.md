# gd_cubism 换机注意事项

本项目已集成 `addons/gd_cubism`，Windows x64 运行所需的 native DLL 已放入插件目录并允许提交。

## 必须随仓库提交的文件

换电脑后要正常加载插件，仓库中需要包含以下内容：

- `addons/gd_cubism/gd_cubism.gdextension`
- `addons/gd_cubism/bin/Live2DCubismCore.dll`
- `addons/gd_cubism/bin/libgd_cubism.windows.debug.x86_64.dll`
- `addons/gd_cubism/bin/libgd_cubism.windows.release.x86_64.dll`
- `addons/gd_cubism/bin/.gitignore`
- `addons/gd_cubism/cs/`
- `addons/gd_cubism/res/`
- `addons/gd_cubism/example/`
- `GalChat.csproj`

其中 `example/` 目录当前保留，用作临时 Live2D 示例资源和测试场景。

## 新电脑拉取后的检查

1. 使用 Windows x64 环境打开项目。
2. 确认 `addons/gd_cubism/bin/` 下存在上面三个 DLL。
3. 打开 Godot 项目后，确认 GDExtension 没有提示缺少 `libgd_cubism.windows.*.dll` 或 `Live2DCubismCore.dll`。
4. 运行 `dotnet build GalChat.csproj`，确认 C# 编译通过。

## 不需要提交的文件

以下是本机构建材料或缓存，不影响换电脑运行，已清理：

- `.dbg/`
- `CubismSdkForNative-5-r.5.zip`
- gd_cubism 源码构建目录
- Live2D SDK 解压目录

如果以后需要重新构建 native DLL，再单独准备 SDK 和构建目录即可。

## 平台限制

当前只补齐了 Windows x64 的 DLL。换到以下平台时，还需要对应平台的 gd_cubism native library：

- macOS
- Linux
- Android
- iOS
- Web

仅在 Windows x64 上拉取并运行时，不需要重新编译插件。

## 重新构建说明

这次构建使用的是 `gd_cubism v0.9.1` 加 `CubismSdkForNative-5-r.5`。两者存在 API 差异，构建时对临时源码做过兼容补丁；这些补丁已经体现在生成出的 DLL 中，但没有作为源码补丁提交。

如果未来要重新生成 DLL，建议优先使用当前已提交的 DLL；只有在升级 Godot、升级 gd_cubism、或更换 Live2D SDK 时才重新构建。重新构建时需要：

- Visual Studio 2022 Build Tools C++ 工作负载
- Windows 10/11 SDK
- Python + SCons 4.7
- Live2D Cubism SDK for Native
