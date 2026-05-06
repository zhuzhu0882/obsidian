const fs = require('fs');
const path = require('path');

const root = 'C:/Users/18826/Documents/work_doc_ob/Telpo/AI笔记/插件使用经验';
const today = '2026-05-03';
const folders = fs.readdirSync(root, { withFileTypes: true })
  .filter(d => d.isDirectory())
  .map(d => d.name)
  .sort((a, b) => a.localeCompare(b, 'zh-CN'));

const categoryMap = {
  'Tasks': '任务与工作流管理',
  'Kanban': '任务与工作流管理',
  'Day Planner': '任务与工作流管理',
  'Calendar': '任务与工作流管理',
  'Recent Files': '任务与工作流管理',
  'Dataview': '查询、模板与自动化',
  'Templater': '查询、模板与自动化',
  'QuickAdd': '查询、模板与自动化',
  'Excalidraw': '可视化、图形与媒体',
  'Charts': '可视化、图形与媒体',
  'Mind Map': '可视化、图形与媒体',
  'Timelines (Revamped)': '可视化、图形与媒体',
  'Media Extended': '可视化、图形与媒体',
  'Annotator': '可视化、图形与媒体',
  'Advanced Tables': '编辑器与输入增强',
  'CodeMirror Options': '编辑器与输入增强',
  'Auto pair chinese symbol': '编辑器与输入增强',
  'Emoji Toolbar': '编辑器与输入增强',
  'Remember cursor position': '编辑器与输入增强',
  'Better Word Count': '写作辅助与语言工具',
  'Better footnote': '写作辅助与语言工具',
  'Dictionary': '写作辅助与语言工具',
  'Claudian': 'AI 与智能助手'
};

const priorityFolders = new Set(['Tasks', 'Dataview', 'Templater', 'QuickAdd', 'Excalidraw']);

function read(file) { return fs.readFileSync(file, 'utf8'); }
function write(file, content) { fs.writeFileSync(file, content, 'utf8'); }
function titleFromGuide(content) {
  const m = content.match(/^#\s+(.+)$/m);
  return m ? m[1].replace(/插件使用指南$/, '').trim() : '插件';
}
function firstLine(content, prefix) {
  const line = content.split('\n').find(l => l.startsWith(prefix));
  return line ? line.slice(prefix.length).trim() : '';
}
function pickThird(files, folder) {
  const byTemplate = files.find(f => f.endsWith('模板.md'));
  const byExample = files.find(f => f.endsWith('示例页.md'));
  if (folder === 'Tasks') return 'Tasks任务总览模板.md';
  return byTemplate || byExample || files.find(f => f !== 'index.md');
}
function yamlValue(value) {
  return String(value).replace(/:/g, '：');
}
function normalizePlatform(platformText) {
  const text = platformText || '';
  if (text.includes('仅桌面端')) return 'desktop';
  if (text.includes('桌面端与移动端都可用')) return 'both';
  if (text.includes('桌面端与移动端都可能可用')) return 'desktop_possible_mobile';
  return 'unknown';
}
function platformLabel(platformKey) {
  return {
    desktop: '仅桌面端可用',
    both: '桌面端与移动端都可用',
    desktop_possible_mobile: '桌面端优先，移动端可能可用',
    unknown: '待补充'
  }[platformKey] || '待补充';
}
function platformChoiceExpr() {
  return 'choice(platform = "both", "桌面端与移动端都可用", choice(platform = "desktop_possible_mobile", "桌面端优先，移动端可能可用", choice(platform = "desktop", "仅桌面端可用", "待补充")))';
}
function extractUseCases(content) {
  const match = content.match(/## 四、(?:用例说明|典型使用场景)\n\n([\s\S]*?)(?:\n## |$)/);
  if (!match) return [];
  return match[1]
    .split('\n')
    .map(line => line.trim())
    .filter(line => line.startsWith('- '))
    .map(line => line.slice(2).trim());
}

const pluginMeta = [];

for (const folder of folders) {
  const dir = path.join(root, folder);
  const files = fs.readdirSync(dir).filter(f => f.endsWith('.md') && f !== 'index.md');
  const guide = files.find(f => f.endsWith('插件使用指南.md'));
  const cheat = files.find(f => f.endsWith('插件速查表.md'));
  const third = pickThird(files, folder);
  if (!guide || !cheat || !third) continue;

  const guideContent = read(path.join(dir, guide));
  const title = titleFromGuide(guideContent);
  let pluginId = firstLine(guideContent, '- 插件 ID：').replace(/`/g, '');
  let version = firstLine(guideContent, '- 当前版本：');
  let author = firstLine(guideContent, '- 作者：');
  let platform = firstLine(guideContent, '- 适用平台：');
  const category = categoryMap[folder] || '插件增强';
  const thirdLabel = third.includes('示例页') ? '示例页' : '模板';
  const recommend = priorityFolders.has(folder) ? '是，建议优先学习' : '可按需要学习';
  const priorityLearning = priorityFolders.has(folder);
  const tags = ['obsidian', '插件', 'index', '导航'];

  if (folder === 'Tasks') {
    pluginId = pluginId || 'obsidian-tasks-plugin';
    version = version || '7.18.4';
    author = author || 'schemar';
    platform = platform || '桌面端与移动端都可用';
  }

  const platformKey = normalizePlatform(platform);
  const useCases = extractUseCases(guideContent);
  const useCaseSummary = useCases.slice(0, 2).join('；') || '适合在对应场景中启用插件能力';
  const guideLink = `[[AI笔记/插件使用经验/${folder}/${guide.replace(/\.md$/, '')}]]`;
  const cheatLink = `[[AI笔记/插件使用经验/${folder}/${cheat.replace(/\.md$/, '')}]]`;
  const thirdLink = `[[AI笔记/插件使用经验/${folder}/${third.replace(/\.md$/, '')}]]`;
  const indexLink = `[[AI笔记/插件使用经验/${folder}/index|${title} 卡片]]`;

  const content = `---\ntitle: ${yamlValue(title)} 插件主页\naliases:\n  - ${yamlValue(title)} index\n  - ${yamlValue(title)} 插件首页\ntags:\n  - ${tags.join('\n  - ')}\ncategory: 插件使用经验\nplugin_id: ${yamlValue(pluginId || 'unknown')}\nplugin_category: ${yamlValue(category)}\nplatform: ${platformKey}\npriority_learning: ${priorityLearning}\ncreated: ${today}\nupdated: ${today}\nstatus: 常用\n---\n\n# ${title} 插件主页\n\n> 返回总目录：[[AI笔记/插件使用经验/Obsidian插件目录]]\n\n> 文档入口：${guideLink} · ${cheatLink} · ${thirdLink}\n\n## 插件卡片\n\n- 插件名称：${title}\n- 插件分类：${category}\n- 插件 ID：\`${pluginId || 'unknown'}\`\n- 当前版本：${version || '未写入'}\n- 作者：${author || '未写入'}\n- 适用平台：${platform || '未写入'}\n- 优先学习：${recommend}\n\n## 这个文件夹里有什么\n\n### 1. 使用指南\n- 入口：${guideLink}\n- 适合先完整理解这个插件是做什么、适合哪些场景、有哪些注意事项。\n\n### 2. 速查表\n- 入口：${cheatLink}\n- 适合快速回顾核心信息、常用入口和最小实践。\n\n### 3. ${thirdLabel}\n- 入口：${thirdLink}\n- 适合直接复制、试用或观察实际效果。\n\n## 建议阅读顺序\n\n1. 先看“使用指南”\n2. 再看“速查表”\n3. 最后进入“${thirdLabel}”动手试一遍\n\n## 典型用例摘要\n\n- ${useCaseSummary}\n- 详细说明见：${guideLink}\n\n## 我的后续补充\n\n- 这里可以继续补：你自己的设置截图、真实案例、踩坑记录、推荐用法。\n- 如果这个插件以后形成稳定工作流，也可以从其他笔记反链回这篇主页。\n`;

  write(path.join(dir, 'index.md'), content);
  pluginMeta.push({ folder, title, category, platformKey, platformLabel: platformLabel(platformKey), priorityLearning, indexLink, useCaseSummary });
}

const categoryOrder = [
  '任务与工作流管理',
  '查询、模板与自动化',
  '可视化、图形与媒体',
  '编辑器与输入增强',
  '写作辅助与语言工具',
  'AI 与智能助手'
];

const priorityLines = pluginMeta
  .filter(item => item.priorityLearning)
  .sort((a, b) => a.title.localeCompare(b.title, 'zh-CN'))
  .map(item => `- ${item.indexLink} · ${item.category} · ${item.platformLabel}`)
  .join('\n');

const platformSections = [
  ['both', '#### 双端可用'],
  ['desktop_possible_mobile', '#### 桌面优先，移动端可能可用'],
  ['desktop', '#### 仅桌面端可用'],
  ['unknown', '#### 待补充']
].map(([key, heading]) => {
  const lines = pluginMeta
    .filter(item => item.platformKey === key)
    .sort((a, b) => a.title.localeCompare(b.title, 'zh-CN'))
    .map(item => `- ${item.indexLink} · ${item.category}`)
    .join('\n') || '- 暂无';
  return `${heading}\n${lines}`;
}).join('\n\n');

const cardSections = categoryOrder.map(category => {
  const lines = pluginMeta
    .filter(item => item.category === category)
    .sort((a, b) => a.title.localeCompare(b.title, 'zh-CN'))
    .map(item => `- ${item.indexLink}`)
    .join('\n');
  return `#### ${category}\n${lines}`;
}).join('\n\n');

const useCaseSections = categoryOrder.map(category => {
  const lines = pluginMeta
    .filter(item => item.category === category)
    .sort((a, b) => a.title.localeCompare(b.title, 'zh-CN'))
    .map(item => `- ${item.indexLink} · ${item.useCaseSummary}`)
    .join('\n') || '- 暂无';
  return `#### ${category}\n${lines}`;
}).join('\n\n');

const platformExpr = platformChoiceExpr();
const dirPage = path.join(root, 'Obsidian插件目录.md');
let dirContent = read(dirPage);
const statsBlock = `## 仪表盘视图\n\n### 1. Dataview 统计表\n\n\`\`\`dataview\nTABLE without id
file.folder AS 文件夹,\nchoice(file.name = "index", "主页", choice(contains(file.name, "模板"), "模板", choice(contains(file.name, "示例页"), "示例页", "说明文档"))) AS 文档类型,\nfile.mtime AS 最后修改\nFROM "AI笔记/插件使用经验"\nWHERE file.name != "Obsidian插件目录"\nSORT file.folder ASC, file.name ASC\n\`\`\`\n\n### 2. 插件主页总览\n\n\`\`\`dataview\nTABLE without id
file.link AS 插件主页,\nplugin_category AS 插件分类,\n${platformExpr} AS 适用平台,\nupdated AS 最近更新\nFROM "AI笔记/插件使用经验"\nWHERE file.name = "index"\nSORT plugin_category ASC, file.name ASC\n\`\`\`\n\n### 3. 按插件分类统计主页数量\n\n\`\`\`dataview\nTABLE length(rows) AS 插件数量\nFROM "AI笔记/插件使用经验"\nWHERE file.name = "index"\nGROUP BY plugin_category AS 插件分类\nSORT 插件分类 ASC\n\`\`\`\n\n### 4. 插件类型分布图\n\n\`\`\`chartsview\ntype: bar\nlabels: [任务与工作流, 查询与自动化, 可视化媒体, 编辑器增强, 写作语言, AI助手]\nseries:\n  - title: 插件数量\n    data: [5, 3, 6, 5, 3, 1]\n\`\`\`\n\n### 5. 模板型与示例页型占比\n\n\`\`\`chartsview\ntype: pie\nlabels: [模板型, 示例页型]\nseries:\n  - title: 数量\n    data: [12, 11]\n\`\`\`\n\n### 6. 整理时间线\n\n\`\`\`timeline\n[line-3, body-2]\n+ 2026-05-03\n  完成 Tasks 三件套规范\n+ 2026-05-03\n  为已安装插件批量生成三件套文档\n+ 2026-05-03\n  将三件套整理到各插件独立文件夹\n+ 2026-05-03\n  建立总目录页与按类型分组导航\n+ 2026-05-03\n  为每个插件补充 index 主页与统计可视化视图\n+ 2026-05-03\n  增加优先学习、平台筛选、最近更新与完整卡片入口\n+ 2026-05-03\n  建立新插件自动建档流水线\n+ 2026-05-03\n  为全部插件补充统一的用例说明与用例总览\n\`\`\`\n\n### 7. 优先学习专区\n\n\`\`\`dataview\nTABLE without id
file.link AS 插件主页,\nplugin_category AS 插件分类,\n${platformExpr} AS 适用平台,\nupdated AS 最近更新\nFROM "AI笔记/插件使用经验"\nWHERE file.name = "index" AND priority_learning = true\nSORT plugin_category ASC, file.name ASC\n\`\`\`\n\n静态速览：\n${priorityLines}\n\n### 8. 按平台筛选视图\n\n\`\`\`dataview\nTABLE without id
file.link AS 插件主页,\nplugin_category AS 插件分类,\n${platformExpr} AS 适用平台,\nupdated AS 最近更新\nFROM "AI笔记/插件使用经验"\nWHERE file.name = "index"\nSORT platform ASC, plugin_category ASC, file.name ASC\n\`\`\`\n\n${platformSections}\n\n### 9. 最近更新视图\n\n\`\`\`dataview\nTABLE without id
file.link AS 插件主页,\nplugin_category AS 插件分类,\nupdated AS 最近更新\nFROM "AI笔记/插件使用经验"\nWHERE file.name = "index"\nSORT updated DESC, file.name ASC\nLIMIT 10\n\`\`\`\n\n### 10. 插件卡片入口\n\n${cardSections}\n\n### 11. 用例总览\n\n${useCaseSections}\n\n---\n\n`;

if (/## 仪表盘视图[\s\S]*?---\n\n## 目录总览/.test(dirContent)) {
  dirContent = dirContent.replace(/## 仪表盘视图[\s\S]*?---\n\n## 目录总览/, `${statsBlock}## 目录总览`);
} else {
  dirContent = dirContent.replace('## 目录总览\n\n', `${statsBlock}## 目录总览\n\n`);
}

dirContent = dirContent.replace(/## 推荐阅读顺序[\s\S]*$/, `## 推荐阅读顺序\n\n如果你想优先整理高价值插件，建议先从上面的“优先学习专区”开始。\n\n也可以继续按下面这条经典顺序入门：\n\n1. [[AI笔记/插件使用经验/Tasks/Tasks插件使用指南]]\n2. [[AI笔记/插件使用经验/Dataview/Dataview插件使用指南]]\n3. [[AI笔记/插件使用经验/Templater/Templater插件使用指南]]\n4. [[AI笔记/插件使用经验/QuickAdd/QuickAdd插件使用指南]]\n5. [[AI笔记/插件使用经验/Excalidraw/Excalidraw插件使用指南]]\n\n这些插件通常最容易形成稳定工作流。\n`);

write(dirPage, dirContent);

console.log(`index pages refreshed for ${pluginMeta.length} folders and directory dashboard upgraded`);
