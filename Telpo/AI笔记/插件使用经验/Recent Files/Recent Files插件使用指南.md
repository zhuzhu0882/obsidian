---
title: Recent Files插件使用指南
aliases:
  - Recent Files 使用指南
  - Obsidian Recent Files 插件使用指南
tags:
  - obsidian
  - 插件
  - 导航
  - 最近文件
  - 使用指南
category: 插件使用经验
created: 2026-05-03
updated: 2026-05-03
status: 常用
---

# Recent Files插件使用指南

> 相关笔记：[[AI笔记/插件使用经验/Recent Files/Recent Files插件使用指南]] · [[AI笔记/插件使用经验/Recent Files/Recent Files插件速查表]] · [[AI笔记/插件使用经验/Recent Files/Recent Files示例页]]

## 一、插件基础信息

- 插件名称：Recent Files
- 插件 ID：`recent-files-obsidian`
- 当前版本：1.7.7
- 最低 Obsidian 版本：0.16.3
- 作者：Tony Grosinger
- 适用平台：桌面端与移动端都可能可用
- 官方说明：manifest 中未提供 helpUrl

## 二、这个插件主要解决什么问题

List files by most recently opened

从当前 vault 的安装情况来看，它更适合归类为“任务与工作流管理”类插件。这个插件更适合配套“示例页”，因为它偏向界面增强、输入体验或行为优化，不一定有统一模板结构。

## 三、建议你优先关注的入口

对于 Obsidian 第三方插件，最常见的入口通常有：

1. 设置 → 第三方插件 → 对应插件设置页
2. 命令面板中搜索插件名称或相关命令
3. 编辑器右键菜单、工具栏、侧边栏或代码块语法（如果插件支持）

由于当前以本地文件为主要证据来源，具体命令名称建议以 Obsidian 中的命令面板实际显示为准。

## 四、用例说明

这个插件更适合用于“任务与工作流管理”相关流程，尤其适合下面这些真实使用场景：

- 快速回到最近编辑过的文件
- 减少来回找文件的成本

## 五、如何在当前 vault 中理解它

- 本地已安装：是
- 已检测到 manifest：是
- 已检测到 data.json：是
- 说明文档依据：manifest / 本地配置 / 当前文档规范

## 本地配置观察

从当前 vault 的本地配置可以看到，这个插件至少涉及以下设置键：

- `recentFiles`
- `omittedPaths`
- `omittedTags`
- `updateOn`
- `omitBookmarks`

这些键说明此插件已经在当前 vault 中被实际配置过；如果你后续要深入整理，可优先从这些选项入手查看插件设置页。

## 六、使用建议

1. 先打开插件设置页，对照本地配置键理解它的主要能力。
2. 再尝试本目录中的示例页，看它是否适合你当前的工作流。
3. 如果需要更深入的命令、语法或高级参数，再去看官方文档。

## 七、注意事项

- 本文优先依据本地插件文件生成，因此不会臆测未在本地看到的高级能力。
- 如果插件升级后功能变化，请同步更新 `updated` 日期和正文内容。
- 如果你已经在 vault 中形成稳定用法，建议未来把真实案例反链回这篇指南。