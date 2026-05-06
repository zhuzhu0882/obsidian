---
title: Dataview模板
aliases:
  - Dataview 模板
  - Dataview 使用模板
tags:
  - obsidian
  - 插件
  - 查询
  - 数据库
  - 模板
category: 插件使用经验
created: 2026-05-03
updated: 2026-05-03
status: 常用
---

# Dataview模板

> 相关笔记：[[AI笔记/插件使用经验/Dataview/Dataview插件使用指南]] · [[AI笔记/插件使用经验/Dataview/Dataview插件速查表]] · [[AI笔记/插件使用经验/Dataview/Dataview模板]]

这是一篇可直接复制和改造的模板页，适合你在自己的笔记里快速试用该插件。

## 适用用例

- 跨笔记查询元数据
- 把笔记变成可筛选的清单和视图

## 使用方式

复制下面的结构到新笔记中，然后根据自己的目录、标签或字段继续调整。

## 示例内容

```dataview
TABLE file.name AS 笔记, file.cday AS 创建时间
FROM "AI笔记"
SORT file.cday DESC
```

## 结合当前 vault 的建议

- 如果你已经在某些笔记里实际使用过 **Dataview**，建议把真实案例链接补到这里。
- 如果本插件偏向界面增强而非内容结构，建议把你常用的设置截图或操作步骤补成自己的经验笔记。
- 如果官方文档里有更完整的写法，可以在验证后再把正确语法同步回本页。

## 本页说明

- 插件 ID：`dataview`
- 当前版本：0.5.68
- data.json：未检测到
- 官方说明：https://blacksmithgu.github.io/obsidian-dataview/
