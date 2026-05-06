const fs = require('fs');
const path = require('path');

const vault = 'C:/Users/18826/Documents/work_doc_ob/Telpo';
const pluginDir = path.join(vault, '.obsidian', 'plugins');
const outDir = path.join(vault, 'AI笔记', '插件使用经验');
const today = '2026-05-03';
const pluginIds = JSON.parse(fs.readFileSync(path.join(vault, '.obsidian', 'community-plugins.json'), 'utf8'));

const categoryMap = {
  'claudian': 'AI 与智能助手',
  'table-editor-obsidian': '编辑器与输入增强',
  'obsidian-annotator': '可视化、图形与媒体',
  'obsidian-auto-pair-chinese-symbol': '编辑器与输入增强',
  'better-fn': '写作辅助与语言工具',
  'better-word-count': '写作辅助与语言工具',
  'calendar': '任务与工作流管理',
  'obsidian-charts': '可视化、图形与媒体',
  'obsidian-codemirror-options': '编辑器与输入增强',
  'dataview': '查询、模板与自动化',
  'obsidian-day-planner': '任务与工作流管理',
  'obsidian-dictionary-plugin': '写作辅助与语言工具',
  'obsidian-emoji-toolbar': '编辑器与输入增强',
  'obsidian-excalidraw-plugin': '可视化、图形与媒体',
  'obsidian-kanban': '任务与工作流管理',
  'media-extended': '可视化、图形与媒体',
  'obsidian-mind-map': '可视化、图形与媒体',
  'quickadd': '查询、模板与自动化',
  'recent-files-obsidian': '任务与工作流管理',
  'remember-cursor-position': '编辑器与输入增强',
  'templater-obsidian': '查询、模板与自动化',
  'timelines-revamped': '可视化、图形与媒体',
  'obsidian-tasks-plugin': '任务与工作流管理'
};

const typeMap = {
  'claudian': 'example',
  'table-editor-obsidian': 'template',
  'obsidian-annotator': 'example',
  'obsidian-auto-pair-chinese-symbol': 'example',
  'better-fn': 'example',
  'better-word-count': 'example',
  'calendar': 'template',
  'obsidian-charts': 'template',
  'obsidian-codemirror-options': 'example',
  'dataview': 'template',
  'obsidian-day-planner': 'template',
  'obsidian-dictionary-plugin': 'example',
  'obsidian-emoji-toolbar': 'example',
  'obsidian-excalidraw-plugin': 'template',
  'obsidian-kanban': 'template',
  'media-extended': 'example',
  'obsidian-mind-map': 'template',
  'quickadd': 'template',
  'recent-files-obsidian': 'example',
  'remember-cursor-position': 'example',
  'templater-obsidian': 'template',
  'timelines-revamped': 'template',
  'obsidian-tasks-plugin': 'template'
};

const extraTags = {
  'claudian': ['ai', '助手'],
  'table-editor-obsidian': ['表格', 'markdown'],
  'obsidian-annotator': ['pdf', '批注'],
  'obsidian-auto-pair-chinese-symbol': ['中文输入', '符号'],
  'better-fn': ['脚注'],
  'better-word-count': ['字数统计'],
  'calendar': ['日历', 'daily-notes'],
  'obsidian-charts': ['图表', '可视化'],
  'obsidian-codemirror-options': ['编辑器'],
  'dataview': ['查询', '数据库'],
  'obsidian-day-planner': ['时间管理', '日程'],
  'obsidian-dictionary-plugin': ['翻译', '词典'],
  'obsidian-emoji-toolbar': ['emoji', '工具栏'],
  'obsidian-excalidraw-plugin': ['绘图', '白板'],
  'obsidian-kanban': ['看板', '项目管理'],
  'media-extended': ['音视频', '媒体'],
  'obsidian-mind-map': ['脑图', '可视化'],
  'quickadd': ['快速输入', '自动化'],
  'recent-files-obsidian': ['导航', '最近文件'],
  'remember-cursor-position': ['光标', '编辑器'],
  'templater-obsidian': ['模板', '脚本'],
  'timelines-revamped': ['时间线', '可视化'],
  'obsidian-tasks-plugin': ['tasks', '任务']
};

const sceneMap = {
  'claudian': ['在 Obsidian 中直接调用 Claude 助手处理笔记', '把 AI 相关操作收敛在当前 vault 的上下文中'],
  'table-editor-obsidian': ['频繁编辑 Markdown 表格', '希望用快捷键快速新增或对齐单元格'],
  'obsidian-annotator': ['在笔记中查看并标注 PDF 或 EPUB', '把阅读标注与 Obsidian 笔记放在一起'],
  'obsidian-auto-pair-chinese-symbol': ['中文输入时自动补全成对符号', '减少手动输入引号括号的成本'],
  'better-fn': ['在长文笔记中整理脚注', '让脚注读写更自然'],
  'better-word-count': ['统计中英文写作字数', '观察长文或日报的输出量'],
  'calendar': ['结合 Daily Notes 管理日记', '从日历中快速打开某一天的笔记'],
  'obsidian-charts': ['在笔记中嵌入图表块', '把表格数据转成可视化结果'],
  'obsidian-codemirror-options': ['微调编辑器行为', '按个人习惯启用或关闭编辑体验选项'],
  'dataview': ['跨笔记查询元数据', '把笔记变成可筛选的清单和视图'],
  'obsidian-day-planner': ['在每天笔记里安排时间块', '用时间线方式查看今日安排'],
  'obsidian-dictionary-plugin': ['查单词、释义和同义词', '在阅读英文资料时快速取词'],
  'obsidian-emoji-toolbar': ['快速插入常用 emoji', '为标题或状态标签添加视觉符号'],
  'obsidian-excalidraw-plugin': ['在 vault 内直接画图', '把草图、流程图和笔记放在同一处'],
  'obsidian-kanban': ['用看板管理项目任务', '将列表整理成列式工作流'],
  'media-extended': ['更好地控制音视频或媒体嵌入', '在笔记里使用扩展媒体功能'],
  'obsidian-mind-map': ['把笔记结构转成脑图', '快速浏览层级关系'],
  'quickadd': ['快速新建笔记和输入模板', '通过命令面板执行自动化动作'],
  'recent-files-obsidian': ['快速回到最近编辑过的文件', '减少来回找文件的成本'],
  'remember-cursor-position': ['重新打开笔记时回到上次编辑位置', '长文写作中断后继续接写'],
  'templater-obsidian': ['创建可执行模板', '在新建笔记时插入动态日期和脚本内容'],
  'timelines-revamped': ['把事件整理成时间线视图', '做项目历程或人物时间轴'],
  'obsidian-tasks-plugin': ['跨笔记汇总任务', '管理截止日期、优先级和重复任务']
};

function slugAlias(name){ return `Obsidian ${name}`; }
function safeReadJson(file){ if (!fs.existsSync(file)) return null; try { return JSON.parse(fs.readFileSync(file,'utf8')); } catch { return null; } }
function yamlList(items, indent='  '){ return items.map(v => `${indent}- ${v}`).join('\n'); }
function makeFrontmatter(title, aliases, tags){ return `---\ntitle: ${title}\naliases:\n${yamlList(aliases)}\ntags:\n${yamlList(tags)}\ncategory: 插件使用经验\ncreated: ${today}\nupdated: ${today}\nstatus: 常用\n---`; }
function linkLine(folderName, baseName, type) { const guide=`[[AI笔记/插件使用经验/${folderName}/${baseName}插件使用指南]]`; const cheat=`[[AI笔记/插件使用经验/${folderName}/${baseName}插件速查表]]`; const thirdName=type==='template' ? `${baseName}${baseName === 'Tasks' ? '任务总览模板' : '模板'}` : `${baseName}示例页`; const third=`[[AI笔记/插件使用经验/${folderName}/${thirdName}]]`; return `> 相关笔记：${guide} · ${cheat} · ${third}`; }
function configSection(data){ if (!data || typeof data !== 'object') return '## 本地配置观察\n\n当前插件目录下没有可直接读取的 `data.json`，因此这里不推测个性化设置，建议以插件设置页和官方文档为准。'; const keys=Object.keys(data); const top=keys.slice(0,12); const bullets=top.map(k=>`- \`${k}\``).join('\n'); return `## 本地配置观察\n\n从当前 vault 的本地配置可以看到，这个插件至少涉及以下设置键：\n\n${bullets}\n\n这些键说明此插件已经在当前 vault 中被实际配置过；如果你后续要深入整理，可优先从这些选项入手查看插件设置页。`; }
function getUseCases(pluginId){ return sceneMap[pluginId] || ['在对应场景中启用插件功能', '结合你的笔记流程逐步尝试']; }
function renderUseCases(pluginId, mode='full'){ const items=getUseCases(pluginId); const picked=mode==='compact' ? items.slice(0,2) : items; return picked.map(item=>`- ${item}`).join('\n'); }
function renderUseCaseLead(manifest, category){ return `这个插件更适合用于“${category}”相关流程，尤其适合下面这些真实使用场景：`; }
function guideContent(folderName, baseName, manifest, data, type, category){ const title=`${baseName}插件使用指南`; const desktop=manifest.isDesktopOnly ? '仅桌面端可用' : '桌面端与移动端都可能可用'; const useCaseLead=renderUseCaseLead(manifest, category); const useCases=renderUseCases(manifest.id, 'full'); const help=manifest.helpUrl ? `[官方文档](${manifest.helpUrl})` : 'manifest 中未提供 helpUrl'; const templateNote=type==='template' ? '这个插件适合配套“模板页”，因为它通常可以沉淀出固定写法、代码块、页面布局或可复用结构。' : '这个插件更适合配套“示例页”，因为它偏向界面增强、输入体验或行为优化，不一定有统一模板结构。'; return `${makeFrontmatter(title,[`${baseName} 使用指南`,slugAlias(`${baseName} 插件使用指南`)],['obsidian','插件',...(extraTags[manifest.id]||[]),'使用指南'])}\n\n# ${title}\n\n${linkLine(folderName, baseName, type)}\n\n## 一、插件基础信息\n\n- 插件名称：${manifest.name}\n- 插件 ID：\`${manifest.id}\`\n- 当前版本：${manifest.version}\n- 最低 Obsidian 版本：${manifest.minAppVersion || 'manifest 未声明'}\n- 作者：${manifest.author || 'manifest 未声明'}\n- 适用平台：${desktop}\n- 官方说明：${help}\n\n## 二、这个插件主要解决什么问题\n\n${manifest.description || 'manifest 中没有提供描述。'}\n\n从当前 vault 的安装情况来看，它更适合归类为“${category}”类插件。${templateNote}\n\n## 三、建议你优先关注的入口\n\n对于 Obsidian 第三方插件，最常见的入口通常有：\n\n1. 设置 → 第三方插件 → 对应插件设置页\n2. 命令面板中搜索插件名称或相关命令\n3. 编辑器右键菜单、工具栏、侧边栏或代码块语法（如果插件支持）\n\n由于当前以本地文件为主要证据来源，具体命令名称建议以 Obsidian 中的命令面板实际显示为准。\n\n## 四、用例说明\n\n${useCaseLead}\n\n${useCases}\n\n## 五、如何在当前 vault 中理解它\n\n- 本地已安装：是\n- 已检测到 manifest：是\n- 已检测到 data.json：${data ? '是' : '否'}\n- 说明文档依据：manifest / 本地配置 / 当前文档规范\n\n${configSection(data)}\n\n## 六、使用建议\n\n1. 先打开插件设置页，对照本地配置键理解它的主要能力。\n2. 再尝试本目录中的${type === 'template' ? '模板页' : '示例页'}，看它是否适合你当前的工作流。\n3. 如果需要更深入的命令、语法或高级参数，再去看官方文档。\n\n## 七、注意事项\n\n- 本文优先依据本地插件文件生成，因此不会臆测未在本地看到的高级能力。\n- 如果插件升级后功能变化，请同步更新 \`updated\` 日期和正文内容。\n- 如果你已经在 vault 中形成稳定用法，建议未来把真实案例反链回这篇指南。`; }
function cheatContent(folderName, baseName, manifest, data, type, category){ const title=`${baseName}插件速查表`; const dataKeys=data&&typeof data==='object' ? Object.keys(data).slice(0,10).map(k=>`- \`${k}\``).join('\n') : '- 未检测到 `data.json`'; return `${makeFrontmatter(title,[`${baseName} 速查表`,slugAlias(`${baseName} 插件速查表`)],['obsidian','插件',...(extraTags[manifest.id]||[]),'速查表'])}\n\n# ${title}\n\n${linkLine(folderName, baseName, type)}\n\n## 1. 基本信息\n\n- 名称：${manifest.name}\n- ID：\`${manifest.id}\`\n- 版本：${manifest.version}\n- 作者：${manifest.author || 'manifest 未声明'}\n- 平台：${manifest.isDesktopOnly ? '仅桌面端' : '桌面端 / 可能支持移动端'}\n- 分类：${category}\n\n## 2. 你最应该先做的事\n\n1. 打开设置页看插件选项\n2. 打开命令面板搜索插件名称\n3. 对照本地配置键确认当前 vault 已启用的能力\n4. 结合同目录的${type === 'template' ? '模板页' : '示例页'}试用\n\n## 3. 本地可见配置项\n\n${dataKeys}\n\n## 4. 用例速览\n\n${renderUseCases(manifest.id, 'compact')}\n\n## 5. 信息来源\n\n- \`manifest.json\`\n- ${data ? '`data.json`' : '未检测到 `data.json`'}\n- ${manifest.helpUrl ? `[官方说明页](${manifest.helpUrl})` : 'manifest 未提供 helpUrl'}\n\n## 6. 最小可用实践\n\n- 先在测试笔记中验证插件基本行为\n- 再决定是否要纳入正式工作流\n- 若涉及代码块、模板或可视化页面，可直接参考同目录配套文档`; }
function exampleBlock(id, name){ const blocks={ 'dataview':'```dataview\nTABLE file.name AS 笔记, file.cday AS 创建时间\nFROM "AI笔记"\nSORT file.cday DESC\n```', 'templater-obsidian':'```md\n<% tp.date.now("YYYY-MM-DD") %>\n\n# <% tp.file.title %>\n```', 'quickadd':'```md\n- [ ] 通过 QuickAdd 快速捕获一个想法\n```', 'calendar':'```md\n# {{date:YYYY-MM-DD}}\n\n## 今日记录\n- [ ] 今日重点\n```', 'obsidian-kanban':'```md\n---\nkanban-plugin: basic\n---\n\n## 待办\n- [ ] 任务 A\n\n## 进行中\n- [ ] 任务 B\n\n## 已完成\n- [ ] 任务 C\n```', 'obsidian-charts':'```chartsview\ntype: bar\nlabels: [周一, 周二, 周三]\nseries:\n  - title: 输出量\n    data: [3, 5, 4]\n```', 'obsidian-day-planner':'```md\n- [ ] 09:00 晨间规划\n- [ ] 10:30 处理重点任务\n- [ ] 14:00 文档整理\n```', 'obsidian-excalidraw-plugin':'```md\n![[白板.excalidraw]]\n```', 'obsidian-mind-map':'```md\n# 项目主题\n## 分支一\n### 细节 A\n## 分支二\n### 细节 B\n```', 'timelines-revamped':'```timeline\n[line-3, body-2]\n+ 2026-05-01\n  项目启动\n+ 2026-05-03\n  完成第一版整理\n```', 'table-editor-obsidian':'```md\n| 字段 | 说明 |\n| --- | --- |\n| 名称 | 示例 |\n| 状态 | 进行中 |\n```' }; return blocks[id] || `- 这里建议创建一篇测试笔记，手动体验 **${name}** 的主要能力，再记录你的实际操作步骤。`; }
function thirdFileName(baseName, type, pluginId){ if (type === 'template') { return pluginId === 'obsidian-tasks-plugin' ? `${baseName}任务总览模板` : `${baseName}模板`; } return `${baseName}示例页`; }
function thirdContent(folderName, baseName, manifest, data, type){ const thirdTitle=thirdFileName(baseName, type, manifest.id); const aliases=type==='template' ? [`${baseName} 模板`, `${baseName} 使用模板`] : [`${baseName} 示例`, `${baseName} 演示页`]; const roleTag=type==='template' ? '模板' : '示例页'; const intro=type==='template' ? '这是一篇可直接复制和改造的模板页，适合你在自己的笔记里快速试用该插件。' : '这是一篇演示/示例页，适合你观察这个插件在实际笔记中的可能用法。'; const note=type==='template' ? '复制下面的结构到新笔记中，然后根据自己的目录、标签或字段继续调整。' : '建议你先在 Obsidian 中打开这篇示例页，再结合插件设置页和命令面板一起观察效果。'; return `${makeFrontmatter(thirdTitle,aliases,['obsidian','插件',...(extraTags[manifest.id]||[]),roleTag])}\n\n# ${thirdTitle}\n\n${linkLine(folderName, baseName, type)}\n\n${intro}\n\n## 适用用例\n\n${renderUseCases(manifest.id, 'compact')}\n\n## 使用方式\n\n${note}\n\n## 示例内容\n\n${exampleBlock(manifest.id, manifest.name)}\n\n## 结合当前 vault 的建议\n\n- 如果你已经在某些笔记里实际使用过 **${manifest.name}**，建议把真实案例链接补到这里。\n- 如果本插件偏向界面增强而非内容结构，建议把你常用的设置截图或操作步骤补成自己的经验笔记。\n- 如果官方文档里有更完整的写法，可以在验证后再把正确语法同步回本页。\n\n## 本页说明\n\n- 插件 ID：\`${manifest.id}\`\n- 当前版本：${manifest.version}\n- data.json：${data ? '已检测到' : '未检测到'}\n- 官方说明：${manifest.helpUrl ? manifest.helpUrl : 'manifest 未提供'}\n`; }

for (const pid of pluginIds) {
  const manifest = safeReadJson(path.join(pluginDir, pid, 'manifest.json'));
  if (!manifest) continue;
  const data = safeReadJson(path.join(pluginDir, pid, 'data.json'));
  const baseName = manifest.name;
  const folderName = baseName;
  const folderPath = path.join(outDir, folderName);
  const category = categoryMap[manifest.id] || '插件增强';
  const type = typeMap[pid] || 'example';
  fs.mkdirSync(folderPath, { recursive: true });
  const files = [
    { name: `${baseName}插件使用指南.md`, content: guideContent(folderName, baseName, manifest, data, type, category) },
    { name: `${baseName}插件速查表.md`, content: cheatContent(folderName, baseName, manifest, data, type, category) },
    { name: `${thirdFileName(baseName, type, manifest.id)}.md`, content: thirdContent(folderName, baseName, manifest, data, type) }
  ];
  for (const f of files) {
    fs.writeFileSync(path.join(folderPath, f.name), f.content, 'utf8');
  }
}
console.log('generated', pluginIds.length, 'plugins');
