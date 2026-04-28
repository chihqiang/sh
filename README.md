# sh

本人常用的 shell 脚本

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

### delete-current-branch.sh

交互式安全删除当前 Git 分支，自动切换到主分支，支持删除本地和远程分支

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/chihqiang/sh/refs/heads/main/git/delete-current-branch.sh)"
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

## 远程部署

### ssh.sh

自动化部署脚本，打包本地项目并上传到一台或多台远程服务器

```bash
export DEPLOY_HOSTS=ubuntu:password@192.168.1.100:22
export POST_DEPLOY_CMD="pm2 restart app"
bash -c "$(curl -fsSL https://raw.githubusercontent.com/chihqiang/sh/refs/heads/main/deploy/ssh.sh)"
```

## 容器管理

### run.sh

容器运行工具，支持 Docker/Podman，自动检测引擎

```bash
export C_IMAGE=nginx:latest
export C_PORT_MAP="8080:80"
export C_MOUNT_MAP="/data/www:/usr/share/nginx/html"
bash -c "$(curl -fsSL https://raw.githubusercontent.com/chihqiang/sh/refs/heads/main/container/run.sh)"
```

### buildrun.sh

Docker/Podman 镜像构建并运行工具

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/chihqiang/sh/refs/heads/main/container/buildrun.sh)"
```

## 环境安装

### golang.sh

安装 Go 语言环境，支持指定版本和阿里云镜像

```bash
export GO_VERSION=1.22.3
bash -c "$(curl -fsSL https://raw.githubusercontent.com/chihqiang/sh/refs/heads/main/install/golang.sh)"
```

### goinstall.sh

快速安装 Go 工具包，自动下载 Go 并安装指定包

```bash
export GO_PACKAGE="github.com/spf13/cobra-cli/cmd/cobra@latest"
bash -c "$(curl -fsSL https://raw.githubusercontent.com/chihqiang/sh/refs/heads/main/install/goinstall.sh)"
```

### golangs.sh

下载并安装 Git 仓库 release 中的二进制工具

```bash
export VERSION=v0.0.1
export GIT_DOMAIN=github.com
export GIT_USERNAME=zhiqiangwang
export GIT_REPO=tlsctl
export BIN_NAME=tlsctl
bash -c "$(curl -fsSL https://raw.githubusercontent.com/chihqiang/sh/refs/heads/main/install/golangs.sh)"
```

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

## Go 开发

### rename.sh

交互式重命名 Go Module 名称并迁移 import 路径

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/chihqiang/sh/refs/heads/main/golang/rename.sh)"
```

## Linux 工具

### disk.sh

云盘管理工具，支持云盘初始化挂载和云盘扩容（支持 ext4/XFS/LVM）

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/chihqiang/sh/refs/heads/main/liunx/disk.sh)"
```

### syscheck.sh

Linux 系统巡检工具，检查系统信息、安全风险、性能和磁盘等

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/chihqiang/sh/refs/heads/main/liunx/syscheck.sh)"
```

## Mac 工具

### wifi.sh

Wi-Fi 管理脚本，支持列出、查看密码和删除保存的 Wi-Fi 网络

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/chihqiang/sh/refs/heads/main/mac/wifi.sh)"
```

### brew.sh

Homebrew 清华镜像管理工具，支持安装、切换镜像源、恢复官方源、卸载等

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/chihqiang/sh/refs/heads/main/mac/brew.sh)"
```

### uv.sh

自动安装 Mac 开发环境，包括 Homebrew、UV 包管理器和代码规范工具

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/chihqiang/sh/refs/heads/main/mac/uv.sh)"
```

### jmeter.sh

在 macOS 上通过 Homebrew 安装 Apache JMeter，并配置默认中文界面

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/chihqiang/sh/refs/heads/main/mac/jmeter.sh)"
```

## MySQL 数据库

### backup.sh

MySQL 单库备份脚本，导出数据库为 SQL 文件

```bash
export LOCAL_HOST=127.0.0.1
export LOCAL_PORT=3306
export LOCAL_DB=mydb
export LOCAL_USER=root
export LOCAL_PASS=password
bash -c "$(curl -fsSL https://raw.githubusercontent.com/chihqiang/sh/refs/heads/main/mysql/backup.sh)"
```

### sync.sh

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
bash -c "$(curl -fsSL https://raw.githubusercontent.com/chihqiang/sh/refs/heads/main/mysql/sync.sh)"
```

## 网络工具

### ping.sh

HTTP Ping 测试工具，统计成功率、最小/最大/平均延迟

```bash
export PING_HOST=www.baidu.com
export PING_COUNT=4
bash -c "$(curl -fsSL https://raw.githubusercontent.com/chihqiang/sh/refs/heads/main/net/ping.sh)"
```

## PHP 工具

### check_syntax.sh

批量检查当前目录下所有 PHP 文件的语法（排除 vendor 和 node_modules）

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/chihqiang/sh/refs/heads/main/php/check_syntax.sh)"
```

## GitHub 工具

### del-actions.sh

批量删除 GitHub Actions 运行记录，保留最近 N 条

```bash
export GITHUB_OWNER=username
export GITHUB_REPO=my-repo
export GITHUB_TOKEN=ghp_xxx
export GITHUB_KEEP_LATEST=5
bash -c "$(curl -fsSL https://raw.githubusercontent.com/chihqiang/sh/refs/heads/main/github/del-actions.sh)"
```

## 项目工具

### init-vue.sh

自动化创建 Vue 3 项目（TypeScript + Router + Pinia + ESLint + Prettier）

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/chihqiang/sh/refs/heads/main/project/init-vue.sh)"
```
