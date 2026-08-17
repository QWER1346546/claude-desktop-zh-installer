# Claude Desktop 中文汉化一键脚本（Windows）

> 让 Claude Desktop 界面显示简体中文。每次 Claude 更新后，双击 `apply-zh.bat` 即可重新汉化。

## 原理

Claude Desktop 每次自动更新都会整体替换程序目录，导致手动写入的翻译文件丢失。本脚本把「复制翻译 → 注册语言 → 修改配置 → 重启」全流程自动化，一次双击完成。

## 文件结构

```
├── apply-zh.bat     # 双击运行：一键汉化（自动请求管理员权限）
├── restore-en.bat   # 双击运行：还原英文
├── apply.ps1        # 核心脚本（供 bat 调用，勿直接双击）
├── langpack/        # 翻译文件（需自行从上游仓库获取，见下）
│   └── translated-zh-CN/
│       └── <版本号>/
├── backup/          # 修改前的原文件备份（运行时自动生成）
└── .gitignore
```

## 使用步骤

### 1. 准备翻译文件

从上游语言包仓库获取翻译文件：

- 上游仓库：[ICERainbow666/claude-desktop-zh-cn](https://github.com/ICERainbow666/claude-desktop-zh-cn)
- 下载后，把 `translated-zh-CN` 目录（或其中你需要的版本文件夹）放到本项目的 `langpack/` 下，结构如下：

```
langpack/
└── translated-zh-CN/
    ├── 1.30096.1.0/
    │   ├── ion-dist/zh-CN.json
    │   ├── desktop-shell/zh-CN.json
    │   └── ion-dist/dynamic/zh-CN.json
    └── （可选）其他版本
```

> 脚本会自动匹配：精确版本 > 最接近的旧版本 > 最接近的新版本。

### 2. 运行

双击 `apply-zh.bat`，在弹出的 UAC 窗口点【是】，等待脚本完成并自动重启 Claude。

## 卸载 / 还原

双击 `restore-en.bat`，将界面还原为英文。

## 说明

- 本仓库**不含**翻译文件内容，翻译文件版权归上游语言包作者所有（[CC BY-NC-SA 4.0](https://creativecommons.org/licenses/by-nc-sa/4.0)）。
- 本脚本仅提供汉化流程的自动化封装。
- Claude Desktop 官方对中文支持尚不稳定（部分版本内置、部分版本移除），第三方语言包随 Claude 版本更新需重新适配，属正常现象。

## 许可

脚本部分：MIT License（见下方）。
