# DeepSeek Harness 一键安装（Windows 便携免安装版）

> **DeepSeek Harness（dsh）Windows 一键安装工具**：绿色便携、免安装、自动下载便携 Node.js、支持国内镜像、自带图形控制面板。
> **One-click installer for DeepSeek Harness on Windows** — portable & green, no admin rights, auto portable Node.js, CN npm mirrors (npmmirror / Huawei Cloud), built-in web control panel.

**DeepSeek Harness** 是 DeepSeek 官方开源的智能体框架（Model + Harness = Agent，一切皆插件）。官方安装方式 
px @deepseek-ai/dsh web 在国内网络环境下容易失败，本工具把它封装成 **Windows 一键安装 + 启动**，适合网络不稳定与免安装诉求。

## ✨ 特性

- 🟢 **免安装、绿色便携**：不写注册表、不改系统环境变量、不装到 Program Files，删除目录即完全卸载
- 📦 **自动下载便携版 Node.js**（系统已装可用版本可选择复用），无需预装 Node / Python / Git
- 🌐 **自动安装 @deepseek-ai/dsh**，支持 npmmirror / 华为云国内镜像自动切换
- 🖥️ **图形化控制面板**（本地网页）：一键安装 / 启动 / 更新 / 卸载
- ⚡ 配套脚本：安装、启动 Web UI、更新、卸载全覆盖

## 🚀 快速开始

1. **下载**本仓库（Code → Download ZIP）或 git clone
2. 双击顶层 **`开始安装.cmd`**
3. 浏览器自动打开控制面板（默认 http://127.0.0.1:3080），按提示配置 **DeepSeek API Key**（platform.deepseek.com 免费注册获取）
4. 完成安装，开始使用 DeepSeek Harness！

> 详细说明（系统要求 / API Key 准备 / 使用方式 / 常见问题）见 [**README.txt**](README.txt)

## 📁 项目结构

`
scripts/        # PowerShell 核心脚本（install / start-web / update / uninstall / panel-server）
webpanel/       # 图形化控制面板（本地网页）
其他工具/        # 便捷 .cmd 入口（panel / start-web / update / uninstall / dsh）
开始安装.cmd    # 一键开始入口
`

## 🔗 相关

- 官方框架：[deepseek-ai/deepseek-harness](https://github.com/deepseek-ai/deepseek-harness)
- DSH 可转债插件：[convertible-bond-intel](https://github.com/Wangxian111/convertible-bond-intel)（转债情报局：行情早报 / 强赎监控 / 配债测算）

## 📄 License

MIT