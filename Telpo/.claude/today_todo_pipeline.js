const fs = require('fs');
const path = require('path');

const args = process.argv.slice(2);
const modeIndex = args.indexOf('--mode');
const mode = modeIndex >= 0 && args[modeIndex + 1] ? args[modeIndex + 1] : 'manual';
const vaultArgIndex = args.indexOf('--vault');
const vault = vaultArgIndex >= 0 && args[vaultArgIndex + 1]
  ? path.resolve(args[vaultArgIndex + 1])
  : 'C:/Users/18826/Documents/work_doc_ob/Telpo';

const todoDir = path.join(vault, '工作笔记', '今日待办');
const statePath = path.join(vault, '.claude', 'today-todo-state.json');
const notifierPluginDataPath = path.join(vault, '.obsidian', 'plugins', 'obsidian-system-task-notifier', 'data.json');
const notifierPluginDir = path.dirname(notifierPluginDataPath);
const markdownLogPath = path.join(todoDir, '今日待办自动生成运行日志.md');
const today = new Date();
const todayDate = formatDate(today);
const yesterdayDate = formatDate(addDays(today, -1));
const todayFile = path.join(todoDir, `${todayDate}-今日待办.md`);
const yesterdayFile = path.join(todoDir, `${yesterdayDate}-今日待办.md`);
const pluginLine = '> 使用插件：[[AI笔记/插件使用经验/Tasks/index|Tasks]] · [[AI笔记/插件使用经验/Day Planner/index|Day Planner]]';
const defaultTags = ['工作笔记', '今日待办', 'tasks', 'day-planner'];

main();

function main() {
  ensureDir(path.dirname(statePath));
  ensureDir(todoDir);
  ensureDir(notifierPluginDir);
  ensureMarkdownLog();

  const state = loadState();
  const existingToday = readFileIfExists(todayFile);
  const sourceContent = readFileIfExists(yesterdayFile);
  const todayPartsPreview = existingToday ? parseSections(existingToday) : null;
  const todayPrepared = isTodayPrepared(existingToday, state, todayPartsPreview);
  if (todayPrepared) {
    if (existingToday && todayPartsPreview) {
      refreshNotifierPlan(todayFile, todayPartsPreview.dayPlannerSection, todayDate);
    }
    const summary = {
      status: 'skipped',
      reason: 'already-prepared',
      mode,
      todayDate,
      yesterdayDate,
      todayFile,
      yesterdayFile,
      markdownLogPath,
      createdTodayFile: false,
      appendedTaskCount: 0,
      plannerSectionCreated: false,
      migratedTaskFingerprints: []
    };
    saveState({
      ...state,
      lastRunAt: new Date().toISOString(),
      lastRunMode: mode,
      lastResult: summary.status,
      lastResultReason: summary.reason
    });
    appendMarkdownLog(`mode=${mode} status=${summary.status} reason=${summary.reason} today=${summary.todayDate} created=${summary.createdTodayFile} appendedTasks=${summary.appendedTaskCount} plannerCreated=${summary.plannerSectionCreated} target=${summary.todayFile} source=${summary.yesterdayFile}`);
    printSummary(summary);
    return;
  }

  const todayParts = todayPartsPreview || buildTodaySkeleton(todayDate);
  const sourceParts = sourceContent ? parseSections(sourceContent) : null;

  const targetFingerprints = new Set(extractTaskLines(todayParts.tasksSection).map(normalizeTaskFingerprint).filter(Boolean));
  const migratedFingerprints = [];
  const migratedLines = [];
  const dailyFingerprintsHandled = new Set();

  if (sourceParts) {
    const sourceTasks = extractTaskLines(sourceParts.tasksSection);
    for (const line of sourceTasks) {
      const task = classifyTask(line);
      const fingerprint = normalizeTaskFingerprint(line);
      if (!fingerprint) continue;
      if (task.isCompleted || task.isCancelled) continue;
      if (task.isRecurring) {
        if (dailyFingerprintsHandled.has(fingerprint) || targetFingerprints.has(fingerprint)) continue;
        dailyFingerprintsHandled.add(fingerprint);
        migratedLines.push(toUncheckedTask(line));
        migratedFingerprints.push(fingerprint);
        targetFingerprints.add(fingerprint);
        continue;
      }
      if (targetFingerprints.has(fingerprint)) continue;
      migratedLines.push(toUncheckedTask(line));
      migratedFingerprints.push(fingerprint);
      targetFingerprints.add(fingerprint);
    }

    const completedRecurring = sourceTasks
      .map(line => ({ line, task: classifyTask(line), fingerprint: normalizeTaskFingerprint(line) }))
      .filter(item => item.fingerprint && item.task.isRecurring && item.task.isCompleted);

    for (const item of completedRecurring) {
      if (dailyFingerprintsHandled.has(item.fingerprint) || targetFingerprints.has(item.fingerprint)) continue;
      dailyFingerprintsHandled.add(item.fingerprint);
      migratedLines.push(toUncheckedTask(item.line));
      migratedFingerprints.push(item.fingerprint);
      targetFingerprints.add(item.fingerprint);
    }
  }

  const plannerSectionCreated = !hasNonEmptySection(todayParts.dayPlannerSection);
  const mergedTasksSection = mergeTasksSection(todayParts.tasksSection, migratedLines);
  const plannerTaskLines = extractTaskLines(mergedTasksSection);
  const suggestedPlannerLines = buildSuggestedPlannerLines(plannerTaskLines);
  const plannerSection = mergePlannerSection(todayParts.dayPlannerSection, suggestedPlannerLines);
  const normalizedParts = {
    ...todayParts,
    tasksSection: mergedTasksSection,
    dayPlannerSection: plannerSection,
    notesSection: ensureNotesSection(todayParts.notesSection)
  };

  const content = renderDocument(normalizedParts, todayDate);
  fs.writeFileSync(todayFile, content, 'utf8');
  refreshNotifierPlan(todayFile, normalizedParts.dayPlannerSection, todayDate);

  const summary = {
    status: existingToday ? 'updated' : 'created',
    reason: existingToday ? 'merged-migrated-tasks' : 'created-from-yesterday',
    mode,
    todayDate,
    yesterdayDate,
    todayFile,
    yesterdayFile,
    markdownLogPath,
    createdTodayFile: !existingToday,
    appendedTaskCount: migratedLines.length,
    plannerSectionCreated,
    migratedTaskFingerprints: migratedFingerprints
  };

  saveState({
    lastSuccessDate: todayDate,
    lastRunAt: new Date().toISOString(),
    lastRunMode: mode,
    todayFile,
    sourceFile: sourceContent ? yesterdayFile : null,
    markdownLogPath,
    createdTodayFile: summary.createdTodayFile,
    appendedTaskCount: summary.appendedTaskCount,
    plannerSectionCreated: summary.plannerSectionCreated,
    migratedTaskFingerprints: migratedFingerprints,
    lastResult: summary.status,
    lastResultReason: summary.reason
  });

  appendMarkdownLog(`mode=${mode} status=${summary.status} reason=${summary.reason} today=${summary.todayDate} created=${summary.createdTodayFile} appendedTasks=${summary.appendedTaskCount} plannerCreated=${summary.plannerSectionCreated} target=${summary.todayFile} source=${summary.yesterdayFile}`);
  printSummary(summary);
}

function refreshNotifierPlan(sourceFile, dayPlannerSection, planDate) {
  const existing = loadNotifierState();
  const tasks = buildNotifierTasks(dayPlannerSection, sourceFile, planDate);
  const nextState = {
    ...existing,
    todoFolder: '工作笔记/今日待办',
    plannerHeading: '## Day Planner 今日安排',
    enableToast: existing.enableToast !== false,
    enableSound: existing.enableSound !== false,
    enableFallbackPopup: existing.enableFallbackPopup !== false,
    repeatMinutes: Array.isArray(existing.repeatMinutes) && existing.repeatMinutes.length ? existing.repeatMinutes : [2, 5, 10],
    maxNotifyCount: Number.isFinite(existing.maxNotifyCount) ? existing.maxNotifyCount : 4,
    lastRefreshAt: new Date().toISOString(),
    lastPlanDate: planDate,
    tasks
  };
  fs.writeFileSync(notifierPluginDataPath, JSON.stringify(nextState, null, 2), 'utf8');
}

function loadNotifierState() {
  if (!fs.existsSync(notifierPluginDataPath)) {
    return {};
  }
  try {
    return JSON.parse(fs.readFileSync(notifierPluginDataPath, 'utf8'));
  } catch {
    return {};
  }
}

function buildNotifierTasks(dayPlannerSection, sourceFile, planDate) {
  const lines = String(dayPlannerSection || '')
    .split('\n')
    .map((line, index) => ({ line: line.trim(), index: index + 1 }))
    .filter(item => item.line.length > 0);

  const tasks = [];
  for (const item of lines) {
    const match = item.line.match(/^- \[[ x\/\-]\]\s*(\d{2}:\d{2})\s+(.+)$/);
    if (!match) continue;
    const [, time, title] = match;
    tasks.push({
      id: `${planDate}_${time}_${item.index}_${slugify(title)}`,
      planDate,
      time,
      title: title.trim(),
      sourceFile,
      sourceLine: item.index,
      rawText: item.line,
      priority: detectPlannerPriority(title),
      status: 'pending',
      notifyCount: 0,
      lastNotifiedAt: '',
      snoozeUntil: ''
    });
  }
  return dedupeNotifierTasks(tasks);
}

function dedupeNotifierTasks(tasks) {
  const seen = new Set();
  return (tasks || []).filter(task => {
    if (!task || !task.id) return false;
    if (seen.has(task.id)) return false;
    seen.add(task.id);
    return true;
  });
}

function detectPlannerPriority(title) {
  const text = String(title || '');
  if (/重要紧急/.test(text)) return 'important-urgent';
  if (/重要不紧急/.test(text)) return 'important-not-urgent';
  if (/持续/.test(text)) return 'recurring';
  return 'normal';
}

function slugify(text) {
  const normalized = String(text || '')
    .toLowerCase()
    .replace(/ai/g, 'ai')
    .replace(/学习obsidian/g, 'study-obsidian')
    .replace(/学习更多ai知识/g, 'learn-more-ai')
    .replace(/驱动工作流/g, 'workflow-drive');

  const ascii = normalized
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '');

  return (ascii || 'task').slice(0, 48);
}

function addDays(date, days) {
  const copy = new Date(date);
  copy.setDate(copy.getDate() + days);
  return copy;
}

function formatDate(date) {
  const y = date.getFullYear();
  const m = String(date.getMonth() + 1).padStart(2, '0');
  const d = String(date.getDate()).padStart(2, '0');
  return `${y}-${m}-${d}`;
}

function ensureDir(dir) {
  fs.mkdirSync(dir, { recursive: true });
}

function ensureMarkdownLog() {
  ensureDir(path.dirname(markdownLogPath));
  if (!fs.existsSync(markdownLogPath)) {
    const initialContent = `---\ntitle: 今日待办自动生成运行日志\ntags:\n  - 工作笔记\n  - 今日待办\n  - 自动化\n  - 日志\ncreated: ${todayDate}\nupdated: ${todayDate}\nstatus: 常用\n---\n\n# 今日待办自动生成运行日志\n\n## 运行记录\n\n`;
    fs.writeFileSync(markdownLogPath, initialContent, 'utf8');
  }
}

function appendMarkdownLog(message) {
  const stamp = new Date().toISOString().replace('T', ' ').slice(0, 19);
  fs.appendFileSync(markdownLogPath, `- [${stamp}] ${message}\n`, 'utf8');
}

function loadState() {
  if (!fs.existsSync(statePath)) return {};
  try {
    return JSON.parse(fs.readFileSync(statePath, 'utf8'));
  } catch {
    return {};
  }
}

function saveState(state) {
  fs.writeFileSync(statePath, JSON.stringify(state, null, 2), 'utf8');
}

function readFileIfExists(filePath) {
  if (!fs.existsSync(filePath)) return null;
  return fs.readFileSync(filePath, 'utf8');
}

function parseSections(content) {
  const normalized = content.replace(/\r\n/g, '\n');
  const frontmatterMatch = normalized.match(/^---\n([\s\S]*?)\n---\n*/);
  const frontmatter = frontmatterMatch ? `---\n${frontmatterMatch[1]}\n---` : '';
  const body = frontmatterMatch ? normalized.slice(frontmatterMatch[0].length) : normalized;
  const titleMatch = body.match(/^#\s+(.+)$/m);
  const title = titleMatch ? titleMatch[1].trim() : '';
  const pluginMatch = body.match(/^> 使用插件：.*$/m);
  const pluginUsage = pluginMatch ? pluginMatch[0].trim() : pluginLine;

  return {
    frontmatter: frontmatter || buildFrontmatter(title || `${todayDate} 今日待办`, todayDate),
    title: title || `${todayDate} 今日待办`,
    pluginUsage,
    tasksSection: getSectionContent(body, '## Tasks 任务清单'),
    dayPlannerSection: getSectionContent(body, '## Day Planner 今日安排'),
    notesSection: getSectionContent(body, '## 备注')
  };
}

function getSectionContent(body, heading) {
  const escaped = heading.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  const regex = new RegExp(`${escaped}\\n\\n([\\s\\S]*?)(?=\\n## |$)`);
  const match = body.match(regex);
  return match ? match[1].trimEnd() : '';
}

function buildTodaySkeleton(dateText) {
  return {
    frontmatter: buildFrontmatter(`${dateText} 今日待办`, dateText),
    title: `${dateText} 今日待办`,
    pluginUsage: pluginLine,
    tasksSection: '',
    dayPlannerSection: '',
    notesSection: '- 当前采用：**Tasks + Day Planner** 组合'
  };
}

function buildSuggestedPlannerLines(taskLines) {
  const items = (taskLines || [])
    .map(line => String(line || '').trim())
    .filter(Boolean)
    .map(line => ({ raw: line, meta: parseTaskMeta(line) }))
    .filter(item => item.meta.title);

  if (!items.length) return [];

  const plannedEntries = items.flatMap(item => {
    const slot = choosePlannerSlot(item.meta);
    const entries = [];

    if (item.meta.priorityScore >= 3) {
      const bufferTime = chooseBufferTime(item.meta, slot.time);
      entries.push({
        time: bufferTime,
        order: slot.order - 0.5,
        text: `- [ ] ${bufferTime} ${item.meta.title}（重要紧急任务预留缓冲；提前准备与排除干扰）`
      });
    }

    const parts = [];
    if (item.meta.dueTime) parts.push(`截止 ${item.meta.dueTime}`);
    if (item.meta.dueDate) parts.push(`截止 ${item.meta.dueDate}`);
    if (item.meta.startDate) parts.push(`开始 ${item.meta.startDate}`);
    if (item.meta.priorityLabel) parts.push(`优先级：${item.meta.priorityLabel}`);
    if (item.meta.isRecurring) parts.push('持续任务');
    entries.push({
      time: slot.time,
      order: slot.order,
      text: `- [ ] ${slot.time} ${item.meta.title}${parts.length ? `（${parts.join('，')}）` : ''}`
    });

    return entries;
  });

  return plannedEntries
    .sort((a, b) => a.order - b.order || compareTimes(a.time, b.time))
    .map(entry => entry.text);
}

function chooseBufferTime(meta, slotTime) {
  if (meta.dueTime) return shiftTime(meta.dueTime, -30);
  return shiftTime(slotTime, -30);
}

function shiftTime(timeText, deltaMinutes) {
  const match = String(timeText || '').match(/^(\d{1,2}):(\d{2})$/);
  if (!match) return timeText || '08:30';
  const hours = Number(match[1]);
  const minutes = Number(match[2]);
  let total = hours * 60 + minutes + deltaMinutes;
  if (total < 0) total = 0;
  const nextHours = String(Math.floor(total / 60)).padStart(2, '0');
  const nextMinutes = String(total % 60).padStart(2, '0');
  return `${nextHours}:${nextMinutes}`;
}

function compareTimes(left, right) {
  const toMinutes = value => {
    const match = String(value || '').match(/^(\d{1,2}):(\d{2})$/);
    if (!match) return Number.MAX_SAFE_INTEGER;
    return Number(match[1]) * 60 + Number(match[2]);
  };
  return toMinutes(left) - toMinutes(right);
}

function parseTaskMeta(line) {
  const text = String(line || '').trim();
  const title = stripTaskDecorations(text);
  const dueTimeMatch = text.match(/⏰\s*(\d{1,2}:\d{2})/);
  const dueDateMatch = text.match(/📅\s*(\d{4}-\d{2}-\d{2})/);
  const startDateMatch = text.match(/🛫\s*(\d{4}-\d{2}-\d{2})/);
  const priority = detectPriority(text);
  const isRecurring = /🔁\s*every day/i.test(text);
  return {
    title,
    dueTime: dueTimeMatch ? dueTimeMatch[1] : '',
    dueDate: dueDateMatch ? dueDateMatch[1] : '',
    startDate: startDateMatch ? startDateMatch[1] : '',
    priorityLabel: priority.label,
    priorityScore: priority.score,
    isRecurring
  };
}

function detectPriority(text) {
  if (/#重要紧急/.test(text)) return { label: '重要紧急', score: 3 };
  if (/#重要不紧急/.test(text)) return { label: '重要不紧急', score: 2 };
  if (/#持续行为/.test(text) || /🔁\s*every day/i.test(text)) return { label: '持续行为', score: 1 };
  if (/⏫/.test(text)) return { label: '高优先级', score: 2 };
  return { label: '普通', score: 0 };
}

function choosePlannerSlot(meta) {
  if (meta.dueTime) return { time: meta.dueTime, order: 0 };
  if (meta.priorityScore >= 3) return { time: '09:00', order: 1 };
  if (meta.startDate) return { time: '14:00', order: 2 };
  if (meta.priorityScore >= 2) return { time: '15:30', order: 3 };
  if (meta.isRecurring) return { time: '20:00', order: 4 };
  return { time: '16:30', order: 5 };
}

function stripTaskDecorations(line) {
  return String(line || '')
    .replace(/^- \[[ x\/\-]\]\s*/, '')
    .replace(/\s*✅\s*\d{4}-\d{2}-\d{2}\s*/g, ' ')
    .replace(/\s*📅\s*\d{4}-\d{2}-\d{2}\s*/g, ' ')
    .replace(/\s*⏰\s*\d{1,2}:\d{2}\s*/g, ' ')
    .replace(/\s*🛫\s*\d{4}-\d{2}-\d{2}\s*/g, ' ')
    .replace(/\s*🔁\s*every day\s*/ig, ' ')
    .replace(/\s*⏫\s*/g, ' ')
    .replace(/\s+#重要紧急\b/g, ' ')
    .replace(/\s+#重要不紧急\b/g, ' ')
    .replace(/\s+#持续行为\b/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

function buildFrontmatter(title, dateText) {
  const tagLines = defaultTags.map(tag => `  - ${tag}`).join('\n');
  return `---\ntitle: ${title}\ntags:\n${tagLines}\ncreated: ${dateText}\nupdated: ${dateText}\nstatus: 进行中\n---`;
}

function extractTaskLines(sectionContent) {
  return String(sectionContent || '')
    .split('\n')
    .map(line => line.trim())
    .filter(line => /^- \[[ x\/\-]\]/.test(line));
}

function classifyTask(line) {
  const normalized = String(line || '').trim();
  return {
    isCompleted: /^- \[x\]/i.test(normalized) || /✅\s*\d{4}-\d{2}-\d{2}/.test(normalized),
    isCancelled: /^- \[-\]/.test(normalized),
    isRecurring: /🔁\s*every day/i.test(normalized)
  };
}

function normalizeTaskFingerprint(line) {
  return String(line || '')
    .replace(/^- \[[ x\/\-]\]\s*/, '')
    .replace(/\s*✅\s*\d{4}-\d{2}-\d{2}\s*/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

function toUncheckedTask(line) {
  return String(line || '')
    .replace(/^- \[[xX\/\-]\]/, '- [ ]')
    .replace(/\s*✅\s*\d{4}-\d{2}-\d{2}\s*/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

function mergeTasksSection(existingSection, migratedLines) {
  const existingLines = String(existingSection || '')
    .split('\n')
    .map(line => line.trimEnd())
    .filter(line => line.length > 0);
  const lines = [...existingLines];
  if (migratedLines.length > 0) {
    lines.push(...migratedLines);
  }
  return lines.join('\n');
}

function hasNonEmptySection(content) {
  return String(content || '').trim().length > 0;
}

function mergePlannerSection(existingSection, suggestedLines) {
  const existingLines = String(existingSection || '')
    .split('\n')
    .map(line => line.trimEnd())
    .filter(line => line.length > 0);

  const isPlaceholderOnly = existingLines.length === 1 && /自动建议安排稍后会根据迁移任务生成/.test(existingLines[0]);
  if (existingLines.length > 0 && !isPlaceholderOnly) return existingLines.join('\n');
  return suggestedLines.join('\n');
}

function ensurePlannerSection(content) {
  return hasNonEmptySection(content) ? content.trimEnd() : '';
}

function ensureNotesSection(content) {
  return hasNonEmptySection(content)
    ? content.trimEnd()
    : '- 当前采用：**Tasks + Day Planner** 组合';
}

function renderDocument(parts, dateText) {
  const notesSection = ensureNotesSection(parts.notesSection);
  const updatedFrontmatter = updateFrontmatter(parts.frontmatter, dateText);
  const plannerContent = hasNonEmptySection(parts.dayPlannerSection) ? parts.dayPlannerSection : '- 自动建议安排稍后会根据迁移任务生成';
  return `${updatedFrontmatter}\n\n# ${parts.title || `${dateText} 今日待办`}\n\n${parts.pluginUsage || pluginLine}\n\n## Tasks 任务清单\n\n${parts.tasksSection || ''}\n\n## Day Planner 今日安排\n\n${plannerContent}\n\n## 备注\n\n${notesSection}\n`;
}

function updateFrontmatter(frontmatter, dateText) {
  let result = frontmatter || buildFrontmatter(`${dateText} 今日待办`, dateText);
  if (!/\nupdated:\s*/.test(result)) {
    result = result.replace(/\nstatus:\s*.*\n?/, match => `${match}updated: ${dateText}\n`);
  }
  result = result.replace(/updated:\s*.*$/m, `updated: ${dateText}`);
  return result;
}

function isTodayPrepared(existingToday, state, todayPartsPreview) {
  if (!existingToday) return false;
  const parts = todayPartsPreview || parseSections(existingToday);
  const hasTasksHeading = existingToday.includes('## Tasks 任务清单');
  const hasPlannerHeading = existingToday.includes('## Day Planner 今日安排');
  const hasPlannerContent = hasNonEmptySection(parts.dayPlannerSection);
  const plannerStillPlaceholder = /自动建议安排稍后会根据迁移任务生成/.test(parts.dayPlannerSection || '');
  const matchesState = state && state.lastSuccessDate === todayDate;
  return hasTasksHeading && hasPlannerHeading && hasPlannerContent && !plannerStillPlaceholder && matchesState;
}

function printSummary(summary) {
  process.stdout.write(JSON.stringify(summary, null, 2));
}
