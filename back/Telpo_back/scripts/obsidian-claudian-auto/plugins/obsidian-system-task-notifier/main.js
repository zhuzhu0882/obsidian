const { Plugin, Notice, PluginSettingTab, Setting } = require('obsidian');
const fs = require('fs');
const path = require('path');

const DEFAULT_SETTINGS = {
  todoFolder: '工作笔记/今日待办',
  plannerHeading: '## Day Planner 今日安排',
  enableToast: true,
  enableSound: true,
  enableFallbackPopup: true,
  repeatMinutes: [2, 5, 10],
  maxNotifyCount: 4,
  lastRefreshAt: '',
  lastPlanDate: '',
  tasks: []
};

module.exports = class SystemTaskNotifierPlugin extends Plugin {
  async onload() {
    this.settings = Object.assign({}, DEFAULT_SETTINGS, await this.loadData());
    this.refreshTimer = null;

    this.addCommand({
      id: 'refresh-system-task-notification-plan',
      name: '刷新系统任务提醒计划',
      callback: async () => {
        const plan = await this.refreshNotificationPlan();
        new Notice(`系统任务提醒计划已刷新：${plan.tasks.length} 项`);
      }
    });

    this.addCommand({
      id: 'create-system-task-notification-test-item',
      name: '创建 1 分钟后测试提醒',
      callback: async () => {
        const testItem = this.createTestTask();
        const tasks = this.normalizeTasks([testItem, ...(this.settings.tasks || [])]);
        this.settings.tasks = tasks;
        this.settings.lastRefreshAt = new Date().toISOString();
        this.settings.lastPlanDate = this.formatDate(new Date());
        await this.saveSettings();
        new Notice(`已创建测试提醒：${testItem.time} ${testItem.title}`);
      }
    });

    this.registerEvent(this.app.vault.on('modify', file => {
      this.scheduleRefreshForFile(file);
    }));

    this.registerEvent(this.app.vault.on('create', file => {
      this.scheduleRefreshForFile(file);
    }));

    this.registerEvent(this.app.vault.on('rename', file => {
      this.scheduleRefreshForFile(file);
    }));

    this.addSettingTab(new SystemTaskNotifierSettingTab(this.app, this));
    await this.refreshNotificationPlan({ silent: true });
  }

  onunload() {
    if (this.refreshTimer) {
      clearTimeout(this.refreshTimer);
      this.refreshTimer = null;
    }
  }

  scheduleRefreshForFile(file) {
    const target = this.resolveTodayRelativePath();
    if (!file || file.path !== target) return;

    if (this.refreshTimer) {
      clearTimeout(this.refreshTimer);
    }

    this.refreshTimer = setTimeout(() => {
      this.refreshNotificationPlan({ silent: true }).catch(error => {
        console.error('[system-task-notifier] auto refresh failed', error);
      });
    }, 600);
  }

  resolveTodayRelativePath() {
    const fileName = `${this.formatDate(new Date())}-今日待办.md`;
    const folder = this.settings.todoFolder || DEFAULT_SETTINGS.todoFolder;
    return `${folder}/${fileName}`.replace(/\\/g, '/');
  }

  async refreshNotificationPlan(options = {}) {
    const todayFile = this.resolveTodayNotePath();
    const fileExists = fs.existsSync(todayFile);
    const content = fileExists ? fs.readFileSync(todayFile, 'utf8') : '';
    const plan = this.buildNotificationPlan(content, todayFile);
    this.settings.tasks = plan.tasks;
    this.settings.lastRefreshAt = new Date().toISOString();
    this.settings.lastPlanDate = plan.planDate;
    await this.saveSettings();
    if (!options.silent) {
      console.log('[system-task-notifier] refreshed', plan);
    }
    return plan;
  }

  buildNotificationPlan(content, sourceFile) {
    const planDate = this.formatDate(new Date());
    const section = this.extractPlannerSection(content || '');
    const lines = section.split(/\r?\n/).filter(Boolean);
    const tasks = lines
      .map((line, index) => this.parsePlannerLine(line, index + 1, sourceFile, planDate))
      .filter(Boolean);

    return {
      planDate,
      sourceFile,
      tasks: this.normalizeTasks(tasks)
    };
  }

  extractPlannerSection(content) {
    const heading = this.settings.plannerHeading || DEFAULT_SETTINGS.plannerHeading;
    const escaped = heading.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
    const regex = new RegExp(`${escaped}\\n\\n([\\s\\S]*?)(?=\\n## |$)`);
    const match = String(content || '').replace(/\r\n/g, '\n').match(regex);
    return match ? match[1].trimEnd() : '';
  }

  parsePlannerLine(line, sourceLine, sourceFile, planDate) {
    const normalized = String(line || '').trim();
    const match = normalized.match(/^- \[[ x\/\-]\]\s*(\d{2}:\d{2})\s+(.+)$/);
    if (!match) return null;
    const [, time, title] = match;
    return {
      id: `${planDate}_${time}_${sourceLine}_${this.slugify(title)}`,
      planDate,
      time,
      title: title.trim(),
      sourceFile,
      sourceLine,
      rawText: normalized,
      priority: this.detectPriority(title),
      status: 'pending',
      notifyCount: 0,
      lastNotifiedAt: '',
      snoozeUntil: ''
    };
  }

  detectPriority(title) {
    if (/重要紧急/.test(title)) return 'important-urgent';
    if (/重要不紧急/.test(title)) return 'important-not-urgent';
    if (/持续/.test(title)) return 'recurring';
    return 'normal';
  }

  normalizeTasks(tasks) {
    const seen = new Set();
    return (tasks || []).filter(task => {
      if (!task || !task.id) return false;
      if (seen.has(task.id)) return false;
      seen.add(task.id);
      return true;
    });
  }

  createTestTask() {
    const now = new Date();
    now.setMinutes(now.getMinutes() + 1);
    now.setSeconds(0, 0);
    const planDate = this.formatDate(now);
    const time = `${String(now.getHours()).padStart(2, '0')}:${String(now.getMinutes()).padStart(2, '0')}`;
    const title = '系统提醒测试任务（1分钟后）';
    return {
      id: `${planDate}_${time}_test_${Date.now()}`,
      planDate,
      time,
      title,
      sourceFile: this.resolveTodayNotePath(),
      sourceLine: 0,
      rawText: `- [ ] ${time} ${title}`,
      priority: 'test',
      status: 'pending',
      notifyCount: 0,
      lastNotifiedAt: '',
      snoozeUntil: ''
    };
  }

  resolveTodayNotePath() {
    const vaultPath = this.app.vault.adapter.basePath;
    const fileName = `${this.formatDate(new Date())}-今日待办.md`;
    return path.join(vaultPath, this.settings.todoFolder || DEFAULT_SETTINGS.todoFolder, fileName);
  }

  formatDate(date) {
    const y = date.getFullYear();
    const m = String(date.getMonth() + 1).padStart(2, '0');
    const d = String(date.getDate()).padStart(2, '0');
    return `${y}-${m}-${d}`;
  }

  slugify(text) {
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

  async saveSettings() {
    await this.saveData(this.settings);
  }
};

class SystemTaskNotifierSettingTab extends PluginSettingTab {
  constructor(app, plugin) {
    super(app, plugin);
    this.plugin = plugin;
  }

  display() {
    const { containerEl } = this;
    containerEl.empty();
    containerEl.createEl('h2', { text: 'System Task Notifier 设置' });

    new Setting(containerEl)
      .setName('今日待办目录')
      .setDesc('默认从该目录读取 YYYY-MM-DD-今日待办.md')
      .addText(text => text
        .setPlaceholder('工作笔记/今日待办')
        .setValue(this.plugin.settings.todoFolder)
        .onChange(async value => {
          this.plugin.settings.todoFolder = value || DEFAULT_SETTINGS.todoFolder;
          await this.plugin.saveSettings();
        }));

    new Setting(containerEl)
      .setName('Day Planner 标题')
      .setDesc('默认读取 ## Day Planner 今日安排 区块')
      .addText(text => text
        .setPlaceholder('## Day Planner 今日安排')
        .setValue(this.plugin.settings.plannerHeading)
        .onChange(async value => {
          this.plugin.settings.plannerHeading = value || DEFAULT_SETTINGS.plannerHeading;
          await this.plugin.saveSettings();
        }));

    new Setting(containerEl)
      .setName('启用系统 Toast')
      .addToggle(toggle => toggle
        .setValue(!!this.plugin.settings.enableToast)
        .onChange(async value => {
          this.plugin.settings.enableToast = value;
          await this.plugin.saveSettings();
        }));

    new Setting(containerEl)
      .setName('启用声音提醒')
      .addToggle(toggle => toggle
        .setValue(!!this.plugin.settings.enableSound)
        .onChange(async value => {
          this.plugin.settings.enableSound = value;
          await this.plugin.saveSettings();
        }));

    new Setting(containerEl)
      .setName('启用失败兜底弹窗')
      .addToggle(toggle => toggle
        .setValue(!!this.plugin.settings.enableFallbackPopup)
        .onChange(async value => {
          this.plugin.settings.enableFallbackPopup = value;
          await this.plugin.saveSettings();
        }));

    new Setting(containerEl)
      .setName('重复提醒间隔（分钟）')
      .setDesc('使用逗号分隔，例如 2,5,10')
      .addText(text => text
        .setValue((this.plugin.settings.repeatMinutes || DEFAULT_SETTINGS.repeatMinutes).join(','))
        .onChange(async value => {
          const parsed = String(value || '')
            .split(',')
            .map(item => Number(item.trim()))
            .filter(item => Number.isFinite(item) && item > 0);
          this.plugin.settings.repeatMinutes = parsed.length ? parsed : DEFAULT_SETTINGS.repeatMinutes;
          await this.plugin.saveSettings();
        }));

    new Setting(containerEl)
      .setName('最大提醒次数')
      .addText(text => text
        .setValue(String(this.plugin.settings.maxNotifyCount || DEFAULT_SETTINGS.maxNotifyCount))
        .onChange(async value => {
          const parsed = Number(value);
          this.plugin.settings.maxNotifyCount = Number.isFinite(parsed) && parsed > 0 ? parsed : DEFAULT_SETTINGS.maxNotifyCount;
          await this.plugin.saveSettings();
        }));
  }
}
