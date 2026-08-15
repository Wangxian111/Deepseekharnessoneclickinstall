# DeepSeek Harness 一键安装（便携免安装版）

本工具为 [DeepSeek Harness](https://github.com/deepseek-ai/deepseek-harness)（`dsh`，DeepSeek 官方的开源智能体框架）提供 Windows 一键安装与启动，**免安装、绿色便携**：

- 不写注册表、不改系统全局环境变量、不装到 Program Files；
- 所有程序与数据都在本目录内，删除目录即完全卸载；
- 自动下载**便携版 Node.js**（若系统已装可用版本，可选择直接复用）；
- 自动安装 `@deepseek-ai/dsh`，并支持国内镜像（npmmirror / 华为云）自动切换。

> 官方安装方式参考：`npx @deepseek-ai/dsh web`，默认地址 `http://127.0.0.1:3080`。
> 本工具把 npx 的一键启动封装成了"下载便携 Node + 全局安装 DeepSeek Harness + 一键启动脚本"，适合网络不稳定的环境与免安装诉求。

---

## 一、系统要求

| 项目 | 要求 |
| --- | --- |
| 系统 | Windows 10 / 11（x64 或 arm64），Windows PowerShell 5.1+（系统自带） |
| 网络 | 需要能访问 npm 仓库（可自动切换国内镜像） |
| 磁盘 | 约 500 MB 可用空间 |

无需预装 Node.js / Python / Git —— 安装器会下载便携版 Node.js。

---

## 二、开始前请先准备：DeepSeek API Key

安装完成后，DeepSeek Harness 需要 **DeepSeek API Key** 才能调用大模型对话。建议在开始安装前先花 2 分钟准备好：

1. 打开 DeepSeek 开放平台：**https://platform.deepseek.com**，用手机号注册并登录；
2. 登录后点左侧菜单 **「API Keys」**，进入密钥管理页；
3. 点 **「创建 API Key」**，名称随意（如 harness），创建后**立即复制并保存**——密钥只显示一次，形如 `sk-xxxxxxxx`；
4. 确认账户**余额充足**：API 按量计费，新用户通常有赠送额度，不够可在「充值」页充值；
5. 安装完成后配置（二选一）：
   - **界面方式**：打开 Web UI → 右上角 **Settings → Models** → 在 DeepSeek 卡片里粘贴 API Key 并保存，立即生效；
   - **环境变量方式**：启动前执行 `set DEEPSEEK_API_KEY=sk-xxxxxxxx`（PowerShell：`$env:DEEPSEEK_API_KEY="sk-xxxxxxxx"`）。

> 🔒 密钥相当于密码，请勿发给他人；DeepSeek Harness 会以只写引用的形式保存在 `data\dsh\.credentials.yaml`，不会显示明文。

---

## 三、使用方法

### 0. 图形化控制面板（推荐，方案三：本地网页）

双击顶层 **`开始安装.cmd`**（或 `其他工具\panel.cmd`，两者相同），会自动打开浏览器进入控制面板（默认 `http://127.0.0.1:38765`）：

- **安装状态**一目了然：便携/系统 Node、DeepSeek Harness 版本、pnpm、Web UI 是否在运行；
- **按钮化操作**：一键安装（可选 npm 源 / 使用系统 Node / 安装 pnpm / 固定 Node 版本）、启动 Web UI（可选端口）、打开 DeepSeek Harness 命令行、升级、卸载、打开数据目录；
- **实时日志 + 进度条**：安装/升级/卸载过程在页面中实时滚动显示，并带**进度条与预计剩余时间**（分阶段估算：下载 Node → 安装 DeepSeek Harness → 验证）；卡住时可点 **⏹ 停止任务** 中断；
- **智能启动**：尚未安装 DeepSeek Harness 时点「启动 Web UI」，面板会自动先安装、装完自动启动，无需手动两步；
- 面板是纯 PowerShell 写的小型本地 HTTP 服务，只监听 `127.0.0.1`，**不需要管理员权限、不触发防火墙**；关闭面板窗口即停止面板（不影响已启动的 Web UI）。

### 1. 一键安装（推荐）

双击顶层 **`开始安装.cmd`** 会自动打开控制面板网页，点页面里的 **🚀 开始安装** 即可完成全部安装（默认值即可，无需任何选择）：

- 自动下载便携版 Node.js（系统 Node 满足要求时，可在「高级选项」勾选「使用系统 Node」免下载）；
- npm 源自动选择（npmmirror 优先，卡住自动切换）；
- 安装过程有进度条与预计剩余时间；
- 安装完成后自动启动 Web UI（端口被占用会自动换空闲端口）。

完成后目录结构大致如下：

```
DeepSeekHarness一键安装包/（解压后）
├─ 其他工具\panel.cmd          图形化控制面板（推荐入口，本地网页）
├─ 开始安装.cmd        双击打开图形化控制面板（推荐入口）
├─ 其他工具\start-web.cmd      启动 Web UI
├─ 其他工具\dsh.cmd            DeepSeek Harness 命令行入口（dsh 是它的命令名）
├─ 其他工具\update.cmd         升级 DeepSeek Harness
├─ 其他工具\uninstall.cmd      卸载（删除整个目录）
├─ README.txt          本说明
├─ webpanel/
│  └─ index.html      控制面板网页
├─ scripts/           安装/面板脚本（可自行查看）
├─ tools/
│  ├─ node/           便携版 Node.js（含 npm、dsh、pnpm）
│  └─ npm-cache/      npm 缓存
└─ data/
   └─ dsh/            用户数据（会话、配置、插件）
```

### 2. 启动 Web UI

双击 **`其他工具\start-web.cmd`**：

- **免预装**：若尚未安装 DeepSeek Harness，会自动执行安装（默认源自动切换），装完立即启动；
- 默认地址 **http://127.0.0.1:3080**，浏览器会自动打开；
- 换端口：`其他工具\start-web.cmd --port 8080`；
- 局域网访问：`其他工具\start-web.cmd --port 8080 --host 0.0.0.0`（注意安全）；
- 按 `Ctrl+C` 停止服务。

### 3. DeepSeek Harness 命令行（dsh）

双击 **`其他工具\dsh.cmd`** 进入命令行环境（`dsh` 是 DeepSeek Harness 的命令名，等价于在终端里执行 `dsh ...`）：

```bat
dsh web                      启动 Web UI
dsh --help                   查看帮助
dsh --profile headless "写一个快速排序"   一次性完成任务（无界面）
dsh plugin add <包名>        安装插件（需要 pnpm）
dsh --version                查看版本
```

> 提示：`其他工具\dsh.cmd` 会把 `tools\node` 临时加入 PATH、把 `DSH_HOME` 指向本目录 `data\dsh`，
> 所以它是完全便携的；你也可以在任何 cmd 窗口手动执行：
> `set DSH_HOME=D:\...\data\dsh` 后再调用 `tools\node\其他工具\dsh.cmd`。
> **双击（不带参数）会进入交互式命令行窗口**，可直接输入 `dsh ...` 命令，输入 `exit` 退出；
> 带参数运行（如 `其他工具\dsh.cmd --version`）则执行后立即退出。

### 4. 升级

双击 **`其他工具\update.cmd`**（或面板「📦 升级 DeepSeek Harness」），从 npm 拉取 `@deepseek-ai/dsh` 最新版。
**升级只会更新软件本体，不会动你的数据**（会话、配置在 `data\dsh` 里）。官方发布新版本后运行一次即可。

### 5. 卸载

双击 **`其他工具\uninstall.cmd`**，确认后删除**整个目录（含用户数据）**。想保留数据请先备份 `data\`。

---

## 四、可配置项（环境变量 / 参数）

| 变量 / 参数 | 作用 |
| --- | --- |
| `DSH_NODE_VERSION=22.19.0` | 固定便携 Node 版本（默认自动选最新 v22 LTS） |
| `DSH_NODE_MIRROR=npmmirror` | 固定 Node.js 下载镜像：`auto`(默认，npmmirror 优先) / `npmmirror` / `huawei` / `official` |
| `DSH_NPM_REGISTRY=https://...` | 指定 npm 源（优先级高于安装菜单） |
| `DSH_NPM_PACKAGE=@deepseek-ai/dsh` | 指定要安装的 npm 包名 |
| `DSH_USE_SYSTEM_NODE=1` | 直接用系统 Node，不询问 |
| `其他工具\panel.cmd -Port 40000` | 指定面板端口（默认 38765，被占用时自动换随机端口） |
| 面板「高级选项」 | 设置 npm 源 / 使用系统 Node / 安装 pnpm / 固定 Node 版本（也可用 DSH_* 环境变量） |

---

## 五、常见问题

**Q1: 点了「启动 Web UI」提示"未找到 DeepSeek Harness / 尚未安装"？**
新版本已做**自动安装**：无论双击 `其他工具\start-web.cmd` 还是在面板点「启动 Web UI」，只要检测到 DeepSeek Harness 未安装，都会先自动执行安装、成功后再启动。若自动安装失败，通常是网络/代理问题，见 Q2，或先手动跑一次 `开始安装.cmd` 看详细日志。

**Q2: npm 安装很慢/卡在"使用源:"？**
npm 源**npmmirror 优先**（官方源 `registry.npmjs.org` 在国内常常很慢），且单个源 30 秒超时自动切换，不会无限等待。
安装 DeepSeek Harness 包较大（含 Web 界面），首次约 1~5 分钟属正常，日志会持续滚动。
面板日志区有 **⏹ 停止任务** 按钮可中断卡住的任务。若仍失败，检查代理：
`set HTTPS_PROXY=http://127.0.0.1:7890`（示例）后重新运行 `开始安装.cmd`；
或安装时在菜单选 `4 自定义 URL` 直接填可用镜像。

**Q3: 下载 Node.js 时一直卡住/等待？**
下载默认 **npmmirror 优先**，且每个镜像最多等 60 秒自动切换下一个，不会无限等待。
若仍慢：运行 `开始安装.cmd` 时在镜像菜单选 `2 仅 npmmirror`，或先执行
`set DSH_NODE_MIRROR=npmmirror` 再启动；也可能是代理问题，见 Q2。

**Q4: 端口 3080 被占用？**
用 `其他工具\start-web.cmd --port 8080` 换端口，或关掉占用程序。

**Q5: 提示 Node 版本不满足？**
便携版默认自动下载最新 v22 LTS，满足 dsh 要求（`^22.19.0 || >=24.0.0`）。
如需固定版本：`set DSH_NODE_VERSION=22.19.0` 后重跑 `开始安装.cmd`。

**Q6: 插件管理（dsh plugin）报找不到 pnpm？**
安装时选择安装 pnpm，或手动执行 `tools\node\npm.cmd install -g pnpm`。

**Q7: 数据存在哪里？**
默认 `data\dsh`（通过环境变量 `DSH_HOME` 生效）。删除 `data\` 即清空会话与配置。

**Q8: 目录路径要注意什么？**
建议将本目录放在**不含空格与特殊字符**的路径（如 `D:\DSH`），避免个别 npm 包在中文/空格路径下异常。移动整个文件夹不影响使用（数据在 `data\` 内）。

**Q9: 控制面板打不开 / 端口冲突？**
面板默认 38765；若被占用会自动换随机端口并在面板窗口里打印实际地址。也可手动指定：`其他工具\panel.cmd -Port 40000`。面板日志文件在 `%TEMP%\dsh-panel-logs\`。

**Q10: 面板里的"卸载"点了没反应？**
卸载会启动一个后台删除任务（先关闭 Web UI / DeepSeek Harness 命令行窗口），完成后整个目录（含本面板）会被删除，面板窗口请手动关闭即可。

**Q11: 想用 Python SDK 开发插件？**
官方 Python SDK 为 `deepseek-harness-sdk`（要求 Python >= 3.10）：
```bat
pip install deepseek-harness-sdk
```
详见官方文档 [python-sdk 指南](https://github.com/deepseek-ai/deepseek-harness/blob/main/docs/user/guide/python-sdk.zh.md)。
（核心 dsh 运行**不需要** Python。）

---

## 六、从源码运行（备选，官方方式）

本工具默认走官方 npm 包路线。若你想从源码运行最新开发版：

```bat
:: 需要 Git 与 pnpm（pnpm 要求 Node ^22.19.0 || >=24.0.0）
git clone https://github.com/deepseek-ai/deepseek-harness.git
cd deepseek-harness
pnpm install
pnpm run build
pnpm dsh web
```

---

## 七、说明

- 本工具为第三方封装脚本，与 DeepSeek 官方无关联；DeepSeek Harness 本身为 [MIT 许可](https://github.com/deepseek-ai/deepseek-harness/blob/main/LICENSE)。
- 脚本仅做"下载 + 解压 + npm 安装 + 启动"操作，无任何隐藏行为，可自行审阅 `scripts\` 目录。
- 首次运行若提示 Windows SmartScreen，请选择"仍要运行"（脚本来自本目录，未签名）。
