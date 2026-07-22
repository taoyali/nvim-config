# Lualine Git 状态刷新优化设计

## 目标

保留状态栏中的 Git ahead/behind 信息，同时消除状态栏每次渲染都执行 `git fetch origin` 导致的高频 Gerrit SSH 连接。

## 现状

`get_git_ahead_behind_info()` 在每次 lualine 渲染时调用 `async_git_status_update()`。后者无条件执行 `git fetch origin`。lualine 每秒定时刷新，其他 UI 事件也会触发渲染，因此可能每秒建立一次甚至多次 SSH 连接。

## 设计

### 缓存

缓存保存：

- 本地分支领先提交数；
- 本地分支落后提交数；
- fetch 是否正在运行；
- 最近一次 fetch 尝试时间。

状态栏组件只读取领先、落后数量并格式化，不启动任何外部进程。

### 本地状态更新

后台更新器每 30 秒运行两条本地命令：

```bash
git rev-list --count HEAD..@{upstream}
git rev-list --count @{upstream}..HEAD
```

命令失败时将对应数量置为 0，兼容非 Git 目录、没有 upstream 的分支和已删除的引用。

### 远程状态更新

Nvim 启动后执行一次 `git fetch origin`，随后每 100 分钟最多执行一次。

fetch 启动前立即记录尝试时间，并设置运行中标记。因此：

- 状态栏重复渲染不会启动 fetch；
- 上一次 fetch 未结束时不会并发执行；
- fetch 失败后也等待 100 分钟，避免远程故障产生重试风暴。

fetch 完成后立即重新计算本地 ahead/behind 缓存。

### 生命周期

使用 Neovim 定时器驱动后台更新。定时器随 Nvim 进程退出而释放，不创建跨进程常驻任务。

## 错误处理

- fetch 失败：保留现有提交数量，不弹窗，不阻塞编辑；
- rev-list 失败：对应数量归零；
- 所有 Git 命令继续通过 `vim.system` 异步执行。

## 验证

1. 启动 Nvim 打开 Git 仓库中的文件；
2. 确认启动阶段最多出现一次 `git fetch origin`；
3. 连续观察超过一分钟，确认不再每秒建立 Gerrit SSH 连接；
4. 确认状态栏仍能显示 `↑[n]` 和 `↓[n]`；
5. 在没有 upstream 的分支或非 Git 目录启动 Nvim，确认无报错。

## 范围

仅修改 `lua/config/lualine.lua`。不修改已有的 `plugin/command.lua` 工作区变更和未跟踪文件 `abx`。
