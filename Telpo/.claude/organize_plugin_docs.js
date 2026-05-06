const fs = require('fs');
const path = require('path');

const root = 'C:/Users/18826/Documents/work_doc_ob/Telpo/AI笔记/插件使用经验';
const files = fs.readdirSync(root).filter(name => name.endsWith('.md'));

function wiki(base, file) {
  return `[[AI笔记/插件使用经验/${base}/${file.replace(/\.md$/, '')}]]`;
}

const pluginMap = new Map();

for (const file of files) {
  if (file.endsWith('插件使用指南.md')) {
    const base = file.replace(/插件使用指南\.md$/, '');
    pluginMap.set(base, pluginMap.get(base) || {});
    pluginMap.get(base).guide = file;
  } else if (file.endsWith('插件速查表.md')) {
    const base = file.replace(/插件速查表\.md$/, '');
    pluginMap.set(base, pluginMap.get(base) || {});
    pluginMap.get(base).cheat = file;
  }
}

for (const [base, entry] of pluginMap.entries()) {
  const templateName = `${base}模板.md`;
  const exampleName = `${base}示例页.md`;
  const tasksSpecial = `${base}任务总览模板.md`;
  if (files.includes(templateName)) entry.third = templateName;
  else if (files.includes(exampleName)) entry.third = exampleName;
  else if (files.includes(tasksSpecial)) entry.third = tasksSpecial;
}

for (const [base, entry] of pluginMap.entries()) {
  if (!entry.guide || !entry.cheat || !entry.third) continue;
  const folder = path.join(root, base);
  fs.mkdirSync(folder, { recursive: true });

  const guideLink = wiki(base, entry.guide);
  const cheatLink = wiki(base, entry.cheat);
  const thirdLink = wiki(base, entry.third);
  const related = `> 相关笔记：${guideLink} · ${cheatLink} · ${thirdLink}`;

  for (const file of [entry.guide, entry.cheat, entry.third]) {
    const src = path.join(root, file);
    const dest = path.join(folder, file);
    let content = fs.readFileSync(src, 'utf8');
    content = content.replace(/^> 相关笔记：.*$/m, related);
    fs.writeFileSync(src, content, 'utf8');
    fs.renameSync(src, dest);
  }
}

console.log(`organized ${pluginMap.size} plugin groups`);
