---
title: Templater模板
aliases:
  - Templater 模板
  - Templater 使用模板
tags:
  - obsidian
  - 插件
  - 模板
  - 脚本
  - 模板
category: 插件使用经验
created: 2026-05-03
updated: 2026-05-03
status: 常用
---

# Templater模板

> 相关笔记：[[AI笔记/插件使用经验/Templater/Templater插件使用指南]] · [[AI笔记/插件使用经验/Templater/Templater插件速查表]] · [[AI笔记/插件使用经验/Templater/Templater模板]]

这是一篇可直接复制和改造的模板页，适合你在自己的笔记里快速试用该插件。

## 适用用例

- 创建可执行模板
- 在新建笔记时插入动态日期和脚本内容

## 使用方式

复制下面的结构到新笔记中，然后根据自己的目录、标签或字段继续调整。

## 示例内容

```md
<% tp.date.now("YYYY-MM-DD") %>

# <% tp.file.title %>
```

## 结合当前 vault 的建议

- 如果你已经在某些笔记里实际使用过 **Templater**，建议把真实案例链接补到这里。
- 如果本插件偏向界面增强而非内容结构，建议把你常用的设置截图或操作步骤补成自己的经验笔记。
- 如果官方文档里有更完整的写法，可以在验证后再把正确语法同步回本页。

## 本页说明

- 插件 ID：`templater-obsidian`
- 当前版本：2.20.0
- data.json：未检测到
- 官方说明：https://silentvoid13.github.io/Templater/
