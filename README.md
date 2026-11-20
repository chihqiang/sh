# sh

本人常用的 shell 脚本

## 目录结构

```text
git/          Git 工具
install/      软件与环境安装
linux/        Linux 运维工具
mac/          macOS 工具
db/           MySQL 数据库工具
net/          网络工具
dev/          开发工具
```

## Git 工具

### user.sh

设置 Git 仓库的用户名和邮箱

```bash
curl -sSL https://raw.githubusercontent.com/chihqiang/sh/refs/heads/main/git/user.sh | bash -s github-actions
curl -sSL https://raw.githubusercontent.com/chihqiang/sh/refs/heads/main/git/user.sh | bash -s github
curl -sSL https://raw.githubusercontent.com/chihqiang/sh/refs/heads/main/git/user.sh | bash -s cnb
curl -sSL https://raw.githubusercontent.com/chihqiang/sh/refs/heads/main/git/user.sh | bash -s gitee
```

### commit-fixup.sh

批量修改 Git 仓库历史提交中的邮箱和用户名

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/chihqiang/sh/refs/heads/main/git/commit-fixup.sh)"
```

### cpmp.sh

Git 分支合并工具，支持切换、合并、推送和切回原分支

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/chihqiang/sh/refs/heads/main/git/cpmp.sh)"
```

### emoji-hook.sh

为 Git 提交信息自动添加 Emoji 前缀，支持 feat/fix/docs 等常用类型

```bash
curl -sSL https://raw.githubusercontent.com/chihqiang/sh/refs/heads/main/git/emoji-hook.sh | bash
```

### svn2git.sh

将 SVN 仓库迁移为 Git 仓库，支持转换 tags 和自动推送

```bash
export SVN_REPO="svn://example.com/repo"
export GIT_REMOTE_URL="https://github.com/yourname/project.git"
bash -c "$(curl -fsSL https://raw.githubusercontent.com/chihqiang/sh/refs/heads/main/git/svn2git.sh)"
```

## 环境安装

### ondrej.sh

安装 Ondrej PPA PHP 版本（Ubuntu/Debian）

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/chihqiang/sh/refs/heads/main/install/ondrej.sh)"
```

### openresty.sh

OpenResty 安装/卸载工具（支持 Ubuntu/Debian/CentOS/RHEL），交互式选择安装或卸载

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/chihqiang/sh/refs/heads/main/install/openresty.sh)"
```

### podman.sh

Podman 安装/卸载工具，支持 macOS/Ubuntu/Debian/CentOS/RHEL/Fedora，交互式选择安装或卸载

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/chihqiang/sh/refs/heads/main/install/podman.sh)"
```

### brew.sh

Homebrew 清华镜像管理工具，支持安装、切换镜像源、恢复官方源、卸载等

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/chihqiang/sh/refs/heads/main/install/brew.sh)"
```

### uv.sh

自动安装 Mac 开发环境，包括 Homebrew、UV 包管理器和代码规范工具

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/chihqiang/sh/refs/heads/main/install/uv.sh)"
```

### jmeter.sh

在 macOS 上通过 Homebrew 安装 Apache JMeter，并配置默认中文界面

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/chihqiang/sh/refs/heads/main/install/jmeter.sh)"
```

## Linux 工具

### disk.sh

云盘管理工具，支持云盘初始化挂载和云盘扩容（支持 ext4/XFS/LVM）

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/chihqiang/sh/refs/heads/main/linux/disk.sh)"
```

### syscheck.sh

Linux 系统巡检工具，检查系统信息、安全风险、性能和磁盘等

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/chihqiang/sh/refs/heads/main/linux/syscheck.sh)"
```

## macOS 工具

### wifi.sh

Wi-Fi 管理脚本，支持列出、查看密码和删除保存的 Wi-Fi 网络

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/chihqiang/sh/refs/heads/main/mac/wifi.sh)"
```

### vscode-extension.sh

VS Code 插件开发环境检查脚本，检查 Homebrew、VS Code 命令行工具、Node.js/npm、yo 脚手架和 vsce 打包工具

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/chihqiang/sh/refs/heads/main/mac/vscode-extension.sh)"
```

### cleanup.sh

macOS 清理脚本：清理过期日志与临时文件，删除已卸载应用的残留数据（默认只预览，不删除任何文件）

清理范围：

- `~/Library/Logs`、诊断报告，以及 `$TMPDIR`、`/tmp`、`/private/var/tmp` 中超过 N 天的文件
- 已卸载应用残留：`Containers`、`Group Containers`、`Preferences`、`Caches`、`HTTPStorages`、`WebKit`、`Saved Application State`、`Application Support`（按脚本内 `APP_RULES` 表）
- 失效的 `LaunchAgents` / `LaunchDaemons`、`/usr/local/bin` 死链
- `SKILL_DIRS_BLACKLIST` 中的目录（**无条件删除**，与对应 App 是否安装无关）

```bash
# 预览（默认，只打印将删除的内容）
bash -c "$(curl -fsSL https://raw.githubusercontent.com/chihqiang/sh/refs/heads/main/mac/cleanup.sh)"

# 执行清理（会先确认）
bash -c "$(curl -fsSL https://raw.githubusercontent.com/chihqiang/sh/refs/heads/main/mac/cleanup.sh)" _ --apply

# 定时任务：不确认直接执行，只清理 30 天前的文件
bash -c "$(curl -fsSL https://raw.githubusercontent.com/chihqiang/sh/refs/heads/main/mac/cleanup.sh)" _ --apply --yes --days 30
```

| 参数 | 说明 |
|---|---|
| 无参数 | 预览模式，不删除任何文件 |
| `--apply` | 执行清理，默认会二次确认 |
| `--yes` | 跳过确认，适合定时任务 |
| `--days N` | 只处理 N 天前的日志/临时文件（默认 7） |
| `--system` | 同时清理系统级 `/var/log`、`/Library/Logs`（需要 sudo） |
| `--no-color` | 关闭彩色输出 |

## 数据库

### mysql_backup.sh

MySQL 单库备份脚本，导出数据库为 SQL 文件

```bash
export LOCAL_HOST=127.0.0.1
export LOCAL_PORT=3306
export LOCAL_DB=mydb
export LOCAL_USER=root
export LOCAL_PASS=password
bash -c "$(curl -fsSL https://raw.githubusercontent.com/chihqiang/sh/refs/heads/main/db/mysql_backup.sh)"
```

### mysql_sync.sh

MySQL 数据库迁移脚本，本地导出并导入至远程数据库

```bash
export LOCAL_HOST=127.0.0.1
export LOCAL_DB=mydb
export LOCAL_USER=root
export LOCAL_PASS=123456
export REMOTE_HOST=192.168.1.100
export REMOTE_DB=mydb
export REMOTE_USER=root
export REMOTE_PASS=123456
bash -c "$(curl -fsSL https://raw.githubusercontent.com/chihqiang/sh/refs/heads/main/db/mysql_sync.sh)"
```

## 网络工具

### ping.sh

HTTP Ping 测试工具，统计成功率、最小/最大/平均延迟

```bash
export PING_HOST=www.baidu.com
export PING_COUNT=4
bash -c "$(curl -fsSL https://raw.githubusercontent.com/chihqiang/sh/refs/heads/main/net/ping.sh)"
```

## 开发工具

### init-vue.sh

自动化创建 Vue 3 项目（TypeScript + Router + Pinia + ESLint + Prettier）

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/chihqiang/sh/refs/heads/main/dev/init-vue.sh)"
```
