# pdf_print_db 数据库备份操作手册（Ubuntu + MariaDB）

## 一、适用范围

本手册适用于在 Ubuntu 系统中对 MariaDB 数据库 `pdf_print_db` 进行手动全量备份，以及配置每日定时自动备份。

数据库连接信息：

| 项目 | 值 |
|------|-----|
| 主机 | `localhost` |
| 端口 | `3306` |
| 数据库名 | `pdf_print_db` |
| 用户名 | `root` |
| 密码 | `xuping662887` |

## 二、手动全量备份

### 2.1 确认 MariaDB 客户端工具可用

通过 SSH 登录到 Ubuntu 服务器，执行：

```bash
mysqldump --version
mysql --version
```

如果提示找不到命令，说明未安装 MariaDB 客户端或客户端工具不在 PATH 中。通常服务器端已自带，如未安装可执行：

```bash
sudo apt update
sudo apt install mariadb-client -y
```

### 2.2 创建备份目录

```bash
sudo mkdir -p /opt/backups/pdf_print_db
sudo chmod 755 /opt/backups/pdf_print_db
```

### 2.3 执行全量备份

执行以下命令进行全库备份：

```bash
mysqldump -h localhost -P 3306 -u root -p'xuping662887' --single-transaction --routines --triggers --events pdf_print_db > /opt/backups/pdf_print_db/pdf_print_db_manual_$(date +%Y%m%d_%H%M%S).sql
```

备份文件名示例：

```
/opt/backups/pdf_print_db/pdf_print_db_manual_20260704_143052.sql
```

> 注意：密码直接写在命令行中会有安全风险（可能出现在命令历史或进程列表中）。更安全的做法见下一节，使用 `~/.my.cnf` 配置文件。

### 2.4 使用配置文件避免密码泄露

在运行备份的 Linux 用户主目录下创建 `~/.my.cnf`：

```bash
nano ~/.my.cnf
```

内容如下：

```ini
[mysqldump]
user=root
password=xuping662887
host=localhost
port=3306
```

设置文件权限，防止其他用户读取：

```bash
chmod 600 ~/.my.cnf
```

然后执行备份时无需再写密码：

```bash
mysqldump --single-transaction --routines --triggers --events pdf_print_db > /opt/backups/pdf_print_db/pdf_print_db_manual_$(date +%Y%m%d_%H%M%S).sql
```

### 2.5 验证备份文件

备份完成后，检查文件大小是否正常，并查看文件头部是否包含数据库结构信息：

```bash
ls -lh /opt/backups/pdf_print_db/
head -n 20 /opt/backups/pdf_print_db/pdf_print_db_manual_20260704_143052.sql
```

## 三、每日定时自动备份

### 3.1 创建备份脚本

创建脚本文件：

```bash
sudo nano /opt/backups/pdf_print_db/backup_pdf_print_db.sh
```

内容如下：

```bash
#!/bin/bash

# 数据库连接信息
DB_HOST="localhost"
DB_PORT="3306"
DB_NAME="pdf_print_db"
DB_USER="root"
DB_PASS="xuping662887"

# 备份目录
BACKUP_DIR="/opt/backups/pdf_print_db"

# 保留最近 30 天的备份
KEEP_DAYS=30

# 生成带时间戳的文件名
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="${BACKUP_DIR}/pdf_print_db_auto_${TIMESTAMP}.sql"

# 记录日志
LOG_FILE="${BACKUP_DIR}/backup.log"
ERROR_LOG="${BACKUP_DIR}/backup_error.log"

# 执行备份
mysqldump -h${DB_HOST} -P${DB_PORT} -u${DB_USER} -p'${DB_PASS}' --single-transaction --routines --triggers --events ${DB_NAME} > "${BACKUP_FILE}"

if [ $? -ne 0 ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] 备份失败：${DB_NAME}" >> "${ERROR_LOG}"
    exit 1
else
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] 备份成功：${BACKUP_FILE}" >> "${LOG_FILE}"
fi

# 压缩备份文件（需要安装 gzip，通常系统已自带）
gzip "${BACKUP_FILE}"
if [ $? -eq 0 ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] 压缩成功：${BACKUP_FILE}.gz" >> "${LOG_FILE}"
fi

# 清理过期备份
find "${BACKUP_DIR}" -maxdepth 1 -name "pdf_print_db_auto_*.sql.gz" -type f -mtime +${KEEP_DAYS} -delete

echo "[$(date '+%Y-%m-%d %H:%M:%S')] 备份任务完成" >> "${LOG_FILE}"
```

脚本说明：

- `--single-transaction`：保证 InnoDB 表备份一致性。
- `--routines --triggers --events`：同时备份存储过程、触发器和事件调度器。
- 备份失败会记录到 `backup_error.log`。
- 自动使用 `gzip` 压缩 SQL 文件以节省空间。
- 默认保留最近 30 天的备份，更早的会自动删除。

赋予脚本可执行权限：

```bash
sudo chmod +x /opt/backups/pdf_print_db/backup_pdf_print_db.sh
```

### 3.2 更安全的脚本版本（使用 ~/.my.cnf）

如果你已经按 2.4 节配置了 `~/.my.cnf`，建议将脚本中的数据库连接部分改为：

```bash
#!/bin/bash

BACKUP_DIR="/opt/backups/pdf_print_db"
KEEP_DAYS=30
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="${BACKUP_DIR}/pdf_print_db_auto_${TIMESTAMP}.sql"
LOG_FILE="${BACKUP_DIR}/backup.log"
ERROR_LOG="${BACKUP_DIR}/backup_error.log"

mysqldump --single-transaction --routines --triggers --events pdf_print_db > "${BACKUP_FILE}"

if [ $? -ne 0 ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] 备份失败：pdf_print_db" >> "${ERROR_LOG}"
    exit 1
else
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] 备份成功：${BACKUP_FILE}" >> "${LOG_FILE}"
fi

gzip "${BACKUP_FILE}"
find "${BACKUP_DIR}" -maxdepth 1 -name "pdf_print_db_auto_*.sql.gz" -type f -mtime +${KEEP_DAYS} -delete
```

这样脚本中不会出现明文密码，更加安全。

### 3.3 测试脚本

手动运行一次脚本，检查是否正常生成备份文件：

```bash
sudo /opt/backups/pdf_print_db/backup_pdf_print_db.sh
ls -lh /opt/backups/pdf_print_db/
cat /opt/backups/pdf_print_db/backup.log
```

如果看到类似 `pdf_print_db_auto_20260704_143052.sql.gz` 的文件，说明脚本工作正常。

### 3.4 配置 crontab 定时任务

使用 `crontab` 配置每天凌晨 2 点自动执行备份：

```bash
sudo crontab -e
```

添加以下内容：

```cron
# 每天凌晨 2:00 备份 pdf_print_db 数据库
0 2 * * * /opt/backups/pdf_print_db/backup_pdf_print_db.sh
```

保存并退出。

### 3.5 验证定时任务

查看当前用户的定时任务列表：

```bash
sudo crontab -l
```

也可以临时将任务时间调整为几分钟后，观察是否能正常执行。确认无误后再改回 `0 2 * * *`。

另外可以检查 cron 服务是否运行：

```bash
sudo systemctl status cron
```

如果未运行，启动并设置开机自启：

```bash
sudo systemctl start cron
sudo systemctl enable cron
```

## 四、数据库恢复

### 4.1 创建或清空目标数据库

```bash
mysql -u root -p'xuping662887'
```

在 MariaDB 命令行中：

```sql
DROP DATABASE IF EXISTS pdf_print_db;
CREATE DATABASE pdf_print_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
EXIT;
```

### 4.2 导入未压缩的备份

```bash
mysql -u root -p'xuping662887' pdf_print_db < /opt/backups/pdf_print_db/pdf_print_db_manual_20260704_143052.sql
```

### 4.3 导入 gzip 压缩的备份

```bash
gunzip -c /opt/backups/pdf_print_db/pdf_print_db_auto_20260704_020000.sql.gz | mysql -u root -p'xuping662887' pdf_print_db
```

### 4.4 验证数据

```bash
mysql -u root -p'xuping662887' -e "USE pdf_print_db; SHOW TABLES; SELECT COUNT(*) AS template_count FROM templates;"
```

## 五、常见问题

### 5.1 mysqldump 命令未找到

检查 MariaDB 客户端是否安装：

```bash
which mysqldump
sudo apt install mariadb-client -y
```

### 5.2 备份文件为空或权限不足

- 确认 root 密码 `xuping662887` 正确。
- 确认 root 用户具有 `SELECT`、`LOCK TABLES`、`SHOW VIEW`、`TRIGGER` 等权限。
- 确认备份目录 `/opt/backups/pdf_print_db` 对执行脚本的用户可写。

### 5.3 定时任务没有运行

检查 cron 日志：

```bash
grep CRON /var/log/syslog
# 或
grep CRON /var/log/cron
```

也可以查看错误日志：

```bash
cat /opt/backups/pdf_print_db/backup_error.log
```

### 5.4 中文乱码

确保数据库使用 `utf8mb4`。导入时如果乱码，可尝试：

```bash
gunzip -c /opt/backups/pdf_print_db/pdf_print_db_auto_20260704_020000.sql.gz | mysql -u root -p'xuping662887' --default-character-set=utf8mb4 pdf_print_db
```

### 5.5 如何查看备份文件内容而不解压

```bash
zcat /opt/backups/pdf_print_db/pdf_print_db_auto_20260704_020000.sql.gz | head -n 20
```

## 六、备份策略建议

- 自动备份每天凌晨执行一次，避开业务高峰。
- 系统升级、批量修改数据或结构调整前，先手动执行一次全量备份。
- 定期将 `/opt/backups/pdf_print_db/` 目录中的备份复制到异地服务器、NAS 或云存储（如 AWS S3、阿里云 OSS），防止单点故障。
- 每季度进行一次恢复演练，验证备份文件是否可用。
- 考虑使用 `mysqlbackup`（企业版）或 `mariabackup`（Percona XtraBackup 兼容工具）实现热备份，进一步降低停机风险。
