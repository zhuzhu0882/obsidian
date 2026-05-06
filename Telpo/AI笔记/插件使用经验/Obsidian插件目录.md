---
title: Obsidian插件目录
aliases:
  - 插件目录
  - Obsidian 第三方插件目录
tags:
  - obsidian
  - 插件
  - 导航
  - 索引
category: 插件使用经验
created: 2026-05-03
updated: 2026-05-03
status: 常用
---

# Obsidian插件目录

这是一篇总导航页，用来汇总 [[AI笔记/插件使用经验]] 下所有已整理的第三方插件说明文档。

## 使用说明

- 每个插件都单独放在自己的文件夹里
- 每个插件通常包含三篇文档：**使用指南 / 速查表 / 模板或示例页**
- 建议优先看“使用指南”，需要快速回顾时看“速查表”，需要直接复用时看“模板/示例页”
- 自动建档运行日志入口：[[AI笔记/插件使用经验/插件自动建档运行日志]]

## 快速跳转

- [[#一、任务与工作流管理]]
- [[#二、查询、模板与自动化]]
- [[#三、可视化、图形与媒体]]
- [[#四、编辑器与输入增强]]
- [[#五、写作辅助与语言工具]]
- [[#六、AI 与智能助手]]
- [[#推荐阅读顺序]]

---

## 仪表盘视图

### 1. Dataview 统计表

```dataview
TABLE without id
file.folder AS 文件夹,
choice(file.name = "index", "主页", choice(contains(file.name, "模板"), "模板", choice(contains(file.name, "示例页"), "示例页", "说明文档"))) AS 文档类型,
file.mtime AS 最后修改
FROM "AI笔记/插件使用经验"
WHERE file.name != "Obsidian插件目录"
SORT file.folder ASC, file.name ASC
```

### 2. 插件主页总览

```dataview
TABLE without id
file.link AS 插件主页,
plugin_category AS 插件分类,
choice(platform = "both", "桌面端与移动端都可用", choice(platform = "desktop_possible_mobile", "桌面端优先，移动端可能可用", choice(platform = "desktop", "仅桌面端可用", "待补充"))) AS 适用平台,
updated AS 最近更新
FROM "AI笔记/插件使用经验"
WHERE file.name = "index"
SORT plugin_category ASC, file.name ASC
```

### 3. 按插件分类统计主页数量

```dataview
TABLE length(rows) AS 插件数量
FROM "AI笔记/插件使用经验"
WHERE file.name = "index"
GROUP BY plugin_category AS 插件分类
SORT 插件分类 ASC
```

### 4. 插件类型分布图

```chartsview
type: bar
labels: [任务与工作流, 查询与自动化, 可视化媒体, 编辑器增强, 写作语言, AI助手]
series:
  - title: 插件数量
    data: [5, 3, 6, 5, 3, 1]
```

### 5. 模板型与示例页型占比

```chartsview
type: pie
labels: [模板型, 示例页型]
series:
  - title: 数量
    data: [12, 11]
```

### 6. 整理时间线

```timeline
[line-3, body-2]
+ 2026-05-03
  完成 Tasks 三件套规范
+ 2026-05-03
  为已安装插件批量生成三件套文档
+ 2026-05-03
  将三件套整理到各插件独立文件夹
+ 2026-05-03
  建立总目录页与按类型分组导航
+ 2026-05-03
  为每个插件补充 index 主页与统计可视化视图
+ 2026-05-03
  增加优先学习、平台筛选、最近更新与完整卡片入口
+ 2026-05-03
  建立新插件自动建档流水线
+ 2026-05-03
  为全部插件补充统一的用例说明与用例总览
```

### 7. 优先学习专区

```dataview
TABLE without id
file.link AS 插件主页,
plugin_category AS 插件分类,
choice(platform = "both", "桌面端与移动端都可用", choice(platform = "desktop_possible_mobile", "桌面端优先，移动端可能可用", choice(platform = "desktop", "仅桌面端可用", "待补充"))) AS 适用平台,
updated AS 最近更新
FROM "AI笔记/插件使用经验"
WHERE file.name = "index" AND priority_learning = true
SORT plugin_category ASC, file.name ASC
```

静态速览：
- [[AI笔记/插件使用经验/Dataview/index|Dataview 卡片]] · 查询、模板与自动化 · 桌面端优先，移动端可能可用
- [[AI笔记/插件使用经验/Excalidraw/index|Excalidraw 卡片]] · 可视化、图形与媒体 · 桌面端优先，移动端可能可用
- [[AI笔记/插件使用经验/QuickAdd/index|QuickAdd 卡片]] · 查询、模板与自动化 · 桌面端优先，移动端可能可用
- [[AI笔记/插件使用经验/Tasks/index|Tasks 卡片]] · 任务与工作流管理 · 桌面端优先，移动端可能可用
- [[AI笔记/插件使用经验/Templater/index|Templater 卡片]] · 查询、模板与自动化 · 桌面端优先，移动端可能可用

### 8. 按平台筛选视图

```dataview
TABLE without id
file.link AS 插件主页,
plugin_category AS 插件分类,
choice(platform = "both", "桌面端与移动端都可用", choice(platform = "desktop_possible_mobile", "桌面端优先，移动端可能可用", choice(platform = "desktop", "仅桌面端可用", "待补充"))) AS 适用平台,
updated AS 最近更新
FROM "AI笔记/插件使用经验"
WHERE file.name = "index"
SORT platform ASC, plugin_category ASC, file.name ASC
```

#### 双端可用
- 暂无

#### 桌面优先，移动端可能可用
- [[AI笔记/插件使用经验/Advanced Tables/index|Advanced Tables 卡片]] · 编辑器与输入增强
- [[AI笔记/插件使用经验/Annotator/index|Annotator 卡片]] · 可视化、图形与媒体
- [[AI笔记/插件使用经验/Better Word Count/index|Better Word Count 卡片]] · 写作辅助与语言工具
- [[AI笔记/插件使用经验/Calendar/index|Calendar 卡片]] · 任务与工作流管理
- [[AI笔记/插件使用经验/Charts/index|Charts 卡片]] · 可视化、图形与媒体
- [[AI笔记/插件使用经验/Dataview/index|Dataview 卡片]] · 查询、模板与自动化
- [[AI笔记/插件使用经验/Day Planner/index|Day Planner 卡片]] · 任务与工作流管理
- [[AI笔记/插件使用经验/Dictionary/index|Dictionary 卡片]] · 写作辅助与语言工具
- [[AI笔记/插件使用经验/Emoji Toolbar/index|Emoji Toolbar 卡片]] · 编辑器与输入增强
- [[AI笔记/插件使用经验/Excalidraw/index|Excalidraw 卡片]] · 可视化、图形与媒体
- [[AI笔记/插件使用经验/Kanban/index|Kanban 卡片]] · 任务与工作流管理
- [[AI笔记/插件使用经验/Mind Map/index|Mind Map 卡片]] · 可视化、图形与媒体
- [[AI笔记/插件使用经验/QuickAdd/index|QuickAdd 卡片]] · 查询、模板与自动化
- [[AI笔记/插件使用经验/Recent Files/index|Recent Files 卡片]] · 任务与工作流管理
- [[AI笔记/插件使用经验/Remember cursor position/index|Remember cursor position 卡片]] · 编辑器与输入增强
- [[AI笔记/插件使用经验/Tasks/index|Tasks 卡片]] · 任务与工作流管理
- [[AI笔记/插件使用经验/Templater/index|Templater 卡片]] · 查询、模板与自动化
- [[AI笔记/插件使用经验/Timelines (Revamped)/index|Timelines (Revamped) 卡片]] · 可视化、图形与媒体

#### 仅桌面端可用
- [[AI笔记/插件使用经验/Auto pair chinese symbol/index|Auto pair chinese symbol 卡片]] · 编辑器与输入增强
- [[AI笔记/插件使用经验/Better footnote/index|Better footnote 卡片]] · 写作辅助与语言工具
- [[AI笔记/插件使用经验/Claudian/index|Claudian 卡片]] · AI 与智能助手
- [[AI笔记/插件使用经验/CodeMirror Options/index|CodeMirror Options 卡片]] · 编辑器与输入增强
- [[AI笔记/插件使用经验/Media Extended/index|Media Extended 卡片]] · 可视化、图形与媒体

#### 待补充
- 暂无

### 9. 最近更新视图

```dataview
TABLE without id
file.link AS 插件主页,
plugin_category AS 插件分类,
updated AS 最近更新
FROM "AI笔记/插件使用经验"
WHERE file.name = "index"
SORT updated DESC, file.name ASC
LIMIT 10
```

### 10. 插件卡片入口

#### 任务与工作流管理
- [[AI笔记/插件使用经验/Calendar/index|Calendar 卡片]]
- [[AI笔记/插件使用经验/Day Planner/index|Day Planner 卡片]]
- [[AI笔记/插件使用经验/Kanban/index|Kanban 卡片]]
- [[AI笔记/插件使用经验/Recent Files/index|Recent Files 卡片]]
- [[AI笔记/插件使用经验/Tasks/index|Tasks 卡片]]

#### 查询、模板与自动化
- [[AI笔记/插件使用经验/Dataview/index|Dataview 卡片]]
- [[AI笔记/插件使用经验/QuickAdd/index|QuickAdd 卡片]]
- [[AI笔记/插件使用经验/Templater/index|Templater 卡片]]

#### 可视化、图形与媒体
- [[AI笔记/插件使用经验/Annotator/index|Annotator 卡片]]
- [[AI笔记/插件使用经验/Charts/index|Charts 卡片]]
- [[AI笔记/插件使用经验/Excalidraw/index|Excalidraw 卡片]]
- [[AI笔记/插件使用经验/Media Extended/index|Media Extended 卡片]]
- [[AI笔记/插件使用经验/Mind Map/index|Mind Map 卡片]]
- [[AI笔记/插件使用经验/Timelines (Revamped)/index|Timelines (Revamped) 卡片]]

#### 编辑器与输入增强
- [[AI笔记/插件使用经验/Advanced Tables/index|Advanced Tables 卡片]]
- [[AI笔记/插件使用经验/Auto pair chinese symbol/index|Auto pair chinese symbol 卡片]]
- [[AI笔记/插件使用经验/CodeMirror Options/index|CodeMirror Options 卡片]]
- [[AI笔记/插件使用经验/Emoji Toolbar/index|Emoji Toolbar 卡片]]
- [[AI笔记/插件使用经验/Remember cursor position/index|Remember cursor position 卡片]]

#### 写作辅助与语言工具
- [[AI笔记/插件使用经验/Better footnote/index|Better footnote 卡片]]
- [[AI笔记/插件使用经验/Better Word Count/index|Better Word Count 卡片]]
- [[AI笔记/插件使用经验/Dictionary/index|Dictionary 卡片]]

#### AI 与智能助手
- [[AI笔记/插件使用经验/Claudian/index|Claudian 卡片]]

### 11. 用例总览

#### 任务与工作流管理
- [[AI笔记/插件使用经验/Calendar/index|Calendar 卡片]] · 结合 Daily Notes 管理日记；从日历中快速打开某一天的笔记
- [[AI笔记/插件使用经验/Day Planner/index|Day Planner 卡片]] · 在每天笔记里安排时间块；用时间线方式查看今日安排
- [[AI笔记/插件使用经验/Kanban/index|Kanban 卡片]] · 用看板管理项目任务；将列表整理成列式工作流
- [[AI笔记/插件使用经验/Recent Files/index|Recent Files 卡片]] · 快速回到最近编辑过的文件；减少来回找文件的成本
- [[AI笔记/插件使用经验/Tasks/index|Tasks 卡片]] · 跨笔记汇总任务；管理截止日期、优先级和重复任务

#### 查询、模板与自动化
- [[AI笔记/插件使用经验/Dataview/index|Dataview 卡片]] · 跨笔记查询元数据；把笔记变成可筛选的清单和视图
- [[AI笔记/插件使用经验/QuickAdd/index|QuickAdd 卡片]] · 快速新建笔记和输入模板；通过命令面板执行自动化动作
- [[AI笔记/插件使用经验/Templater/index|Templater 卡片]] · 创建可执行模板；在新建笔记时插入动态日期和脚本内容

#### 可视化、图形与媒体
- [[AI笔记/插件使用经验/Annotator/index|Annotator 卡片]] · 在笔记中查看并标注 PDF 或 EPUB；把阅读标注与 Obsidian 笔记放在一起
- [[AI笔记/插件使用经验/Charts/index|Charts 卡片]] · 在笔记中嵌入图表块；把表格数据转成可视化结果
- [[AI笔记/插件使用经验/Excalidraw/index|Excalidraw 卡片]] · 在 vault 内直接画图；把草图、流程图和笔记放在同一处
- [[AI笔记/插件使用经验/Media Extended/index|Media Extended 卡片]] · 更好地控制音视频或媒体嵌入；在笔记里使用扩展媒体功能
- [[AI笔记/插件使用经验/Mind Map/index|Mind Map 卡片]] · 把笔记结构转成脑图；快速浏览层级关系
- [[AI笔记/插件使用经验/Timelines (Revamped)/index|Timelines (Revamped) 卡片]] · 把事件整理成时间线视图；做项目历程或人物时间轴

#### 编辑器与输入增强
- [[AI笔记/插件使用经验/Advanced Tables/index|Advanced Tables 卡片]] · 频繁编辑 Markdown 表格；希望用快捷键快速新增或对齐单元格
- [[AI笔记/插件使用经验/Auto pair chinese symbol/index|Auto pair chinese symbol 卡片]] · 中文输入时自动补全成对符号；减少手动输入引号括号的成本
- [[AI笔记/插件使用经验/CodeMirror Options/index|CodeMirror Options 卡片]] · 微调编辑器行为；按个人习惯启用或关闭编辑体验选项
- [[AI笔记/插件使用经验/Emoji Toolbar/index|Emoji Toolbar 卡片]] · 快速插入常用 emoji；为标题或状态标签添加视觉符号
- [[AI笔记/插件使用经验/Remember cursor position/index|Remember cursor position 卡片]] · 重新打开笔记时回到上次编辑位置；长文写作中断后继续接写

#### 写作辅助与语言工具
- [[AI笔记/插件使用经验/Better footnote/index|Better footnote 卡片]] · 在长文笔记中整理脚注；让脚注读写更自然
- [[AI笔记/插件使用经验/Better Word Count/index|Better Word Count 卡片]] · 统计中英文写作字数；观察长文或日报的输出量
- [[AI笔记/插件使用经验/Dictionary/index|Dictionary 卡片]] · 查单词、释义和同义词；在阅读英文资料时快速取词

#### AI 与智能助手
- [[AI笔记/插件使用经验/Claudian/index|Claudian 卡片]] · 在 Obsidian 中直接调用 Claude 助手处理笔记；把 AI 相关操作收敛在当前 vault 的上下文中

---

## 目录总览

## 一、任务与工作流管理

### Tasks
- 文件夹：[[AI笔记/插件使用经验/Tasks]]
- 使用指南：[[AI笔记/插件使用经验/Tasks/Tasks插件使用指南]]
- 速查表：[[AI笔记/插件使用经验/Tasks/Tasks插件速查表]]
- 模板：[[AI笔记/插件使用经验/Tasks/Tasks任务总览模板]]

### Kanban
- 文件夹：[[AI笔记/插件使用经验/Kanban]]
- 使用指南：[[AI笔记/插件使用经验/Kanban/Kanban插件使用指南]]
- 速查表：[[AI笔记/插件使用经验/Kanban/Kanban插件速查表]]
- 模板：[[AI笔记/插件使用经验/Kanban/Kanban模板]]

### Day Planner
- 文件夹：[[AI笔记/插件使用经验/Day Planner]]
- 使用指南：[[AI笔记/插件使用经验/Day Planner/Day Planner插件使用指南]]
- 速查表：[[AI笔记/插件使用经验/Day Planner/Day Planner插件速查表]]
- 模板：[[AI笔记/插件使用经验/Day Planner/Day Planner模板]]

### Calendar
- 文件夹：[[AI笔记/插件使用经验/Calendar]]
- 使用指南：[[AI笔记/插件使用经验/Calendar/Calendar插件使用指南]]
- 速查表：[[AI笔记/插件使用经验/Calendar/Calendar插件速查表]]
- 模板：[[AI笔记/插件使用经验/Calendar/Calendar模板]]

### Recent Files
- 文件夹：[[AI笔记/插件使用经验/Recent Files]]
- 使用指南：[[AI笔记/插件使用经验/Recent Files/Recent Files插件使用指南]]
- 速查表：[[AI笔记/插件使用经验/Recent Files/Recent Files插件速查表]]
- 示例页：[[AI笔记/插件使用经验/Recent Files/Recent Files示例页]]

## 二、查询、模板与自动化

### Dataview
- 文件夹：[[AI笔记/插件使用经验/Dataview]]
- 使用指南：[[AI笔记/插件使用经验/Dataview/Dataview插件使用指南]]
- 速查表：[[AI笔记/插件使用经验/Dataview/Dataview插件速查表]]
- 模板：[[AI笔记/插件使用经验/Dataview/Dataview模板]]

### Templater
- 文件夹：[[AI笔记/插件使用经验/Templater]]
- 使用指南：[[AI笔记/插件使用经验/Templater/Templater插件使用指南]]
- 速查表：[[AI笔记/插件使用经验/Templater/Templater插件速查表]]
- 模板：[[AI笔记/插件使用经验/Templater/Templater模板]]

### QuickAdd
- 文件夹：[[AI笔记/插件使用经验/QuickAdd]]
- 使用指南：[[AI笔记/插件使用经验/QuickAdd/QuickAdd插件使用指南]]
- 速查表：[[AI笔记/插件使用经验/QuickAdd/QuickAdd插件速查表]]
- 模板：[[AI笔记/插件使用经验/QuickAdd/QuickAdd模板]]

## 三、可视化、图形与媒体

### Excalidraw
- 文件夹：[[AI笔记/插件使用经验/Excalidraw]]
- 使用指南：[[AI笔记/插件使用经验/Excalidraw/Excalidraw插件使用指南]]
- 速查表：[[AI笔记/插件使用经验/Excalidraw/Excalidraw插件速查表]]
- 模板：[[AI笔记/插件使用经验/Excalidraw/Excalidraw模板]]

### Charts
- 文件夹：[[AI笔记/插件使用经验/Charts]]
- 使用指南：[[AI笔记/插件使用经验/Charts/Charts插件使用指南]]
- 速查表：[[AI笔记/插件使用经验/Charts/Charts插件速查表]]
- 模板：[[AI笔记/插件使用经验/Charts/Charts模板]]

### Mind Map
- 文件夹：[[AI笔记/插件使用经验/Mind Map]]
- 使用指南：[[AI笔记/插件使用经验/Mind Map/Mind Map插件使用指南]]
- 速查表：[[AI笔记/插件使用经验/Mind Map/Mind Map插件速查表]]
- 模板：[[AI笔记/插件使用经验/Mind Map/Mind Map模板]]

### Timelines (Revamped)
- 文件夹：[[AI笔记/插件使用经验/Timelines (Revamped)]]
- 使用指南：[[AI笔记/插件使用经验/Timelines (Revamped)/Timelines (Revamped)插件使用指南]]
- 速查表：[[AI笔记/插件使用经验/Timelines (Revamped)/Timelines (Revamped)插件速查表]]
- 模板：[[AI笔记/插件使用经验/Timelines (Revamped)/Timelines (Revamped)模板]]

### Media Extended
- 文件夹：[[AI笔记/插件使用经验/Media Extended]]
- 使用指南：[[AI笔记/插件使用经验/Media Extended/Media Extended插件使用指南]]
- 速查表：[[AI笔记/插件使用经验/Media Extended/Media Extended插件速查表]]
- 示例页：[[AI笔记/插件使用经验/Media Extended/Media Extended示例页]]

### Annotator
- 文件夹：[[AI笔记/插件使用经验/Annotator]]
- 使用指南：[[AI笔记/插件使用经验/Annotator/Annotator插件使用指南]]
- 速查表：[[AI笔记/插件使用经验/Annotator/Annotator插件速查表]]
- 示例页：[[AI笔记/插件使用经验/Annotator/Annotator示例页]]

## 四、编辑器与输入增强

### Advanced Tables
- 文件夹：[[AI笔记/插件使用经验/Advanced Tables]]
- 使用指南：[[AI笔记/插件使用经验/Advanced Tables/Advanced Tables插件使用指南]]
- 速查表：[[AI笔记/插件使用经验/Advanced Tables/Advanced Tables插件速查表]]
- 模板：[[AI笔记/插件使用经验/Advanced Tables/Advanced Tables模板]]

### CodeMirror Options
- 文件夹：[[AI笔记/插件使用经验/CodeMirror Options]]
- 使用指南：[[AI笔记/插件使用经验/CodeMirror Options/CodeMirror Options插件使用指南]]
- 速查表：[[AI笔记/插件使用经验/CodeMirror Options/CodeMirror Options插件速查表]]
- 示例页：[[AI笔记/插件使用经验/CodeMirror Options/CodeMirror Options示例页]]

### Auto pair chinese symbol
- 文件夹：[[AI笔记/插件使用经验/Auto pair chinese symbol]]
- 使用指南：[[AI笔记/插件使用经验/Auto pair chinese symbol/Auto pair chinese symbol插件使用指南]]
- 速查表：[[AI笔记/插件使用经验/Auto pair chinese symbol/Auto pair chinese symbol插件速查表]]
- 示例页：[[AI笔记/插件使用经验/Auto pair chinese symbol/Auto pair chinese symbol示例页]]

### Emoji Toolbar
- 文件夹：[[AI笔记/插件使用经验/Emoji Toolbar]]
- 使用指南：[[AI笔记/插件使用经验/Emoji Toolbar/Emoji Toolbar插件使用指南]]
- 速查表：[[AI笔记/插件使用经验/Emoji Toolbar/Emoji Toolbar插件速查表]]
- 示例页：[[AI笔记/插件使用经验/Emoji Toolbar/Emoji Toolbar示例页]]

### Remember cursor position
- 文件夹：[[AI笔记/插件使用经验/Remember cursor position]]
- 使用指南：[[AI笔记/插件使用经验/Remember cursor position/Remember cursor position插件使用指南]]
- 速查表：[[AI笔记/插件使用经验/Remember cursor position/Remember cursor position插件速查表]]
- 示例页：[[AI笔记/插件使用经验/Remember cursor position/Remember cursor position示例页]]

## 五、写作辅助与语言工具

### Better Word Count
- 文件夹：[[AI笔记/插件使用经验/Better Word Count]]
- 使用指南：[[AI笔记/插件使用经验/Better Word Count/Better Word Count插件使用指南]]
- 速查表：[[AI笔记/插件使用经验/Better Word Count/Better Word Count插件速查表]]
- 示例页：[[AI笔记/插件使用经验/Better Word Count/Better Word Count示例页]]

### Better footnote
- 文件夹：[[AI笔记/插件使用经验/Better footnote]]
- 使用指南：[[AI笔记/插件使用经验/Better footnote/Better footnote插件使用指南]]
- 速查表：[[AI笔记/插件使用经验/Better footnote/Better footnote插件速查表]]
- 示例页：[[AI笔记/插件使用经验/Better footnote/Better footnote示例页]]

### Dictionary
- 文件夹：[[AI笔记/插件使用经验/Dictionary]]
- 使用指南：[[AI笔记/插件使用经验/Dictionary/Dictionary插件使用指南]]
- 速查表：[[AI笔记/插件使用经验/Dictionary/Dictionary插件速查表]]
- 示例页：[[AI笔记/插件使用经验/Dictionary/Dictionary示例页]]

## 六、AI 与智能助手

### Claudian
- 文件夹：[[AI笔记/插件使用经验/Claudian]]
- 使用指南：[[AI笔记/插件使用经验/Claudian/Claudian插件使用指南]]
- 速查表：[[AI笔记/插件使用经验/Claudian/Claudian插件速查表]]
- 示例页：[[AI笔记/插件使用经验/Claudian/Claudian示例页]]

---

## 推荐阅读顺序

如果你想优先整理高价值插件，建议先从上面的“优先学习专区”开始。

也可以继续按下面这条经典顺序入门：

1. [[AI笔记/插件使用经验/Tasks/Tasks插件使用指南]]
2. [[AI笔记/插件使用经验/Dataview/Dataview插件使用指南]]
3. [[AI笔记/插件使用经验/Templater/Templater插件使用指南]]
4. [[AI笔记/插件使用经验/QuickAdd/QuickAdd插件使用指南]]
5. [[AI笔记/插件使用经验/Excalidraw/Excalidraw插件使用指南]]

这些插件通常最容易形成稳定工作流。
