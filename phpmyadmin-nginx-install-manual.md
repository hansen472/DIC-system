# phpMyAdmin + Nginx 安装与配置操作手册

## 适用环境

- 服务器：`sweiweb01`
- 操作系统：Ubuntu/Debian 系列
- Web 服务器：Nginx
- 数据库：MariaDB（端口 3306，数据库 `pdf_print_db`）
- 目标：通过 Web 界面管理 MariaDB 数据库

---

## 一、安装前准备

### 1.1 登录服务器

```bash
ssh hansen@sweiweb01
cd /opt/pdf-server
```

### 1.2 更新软件包列表

```bash
sudo apt update
sudo apt upgrade -y
```

### 1.3 确认 Nginx 和 PHP 已安装

```bash
nginx -v
php -v
```

如果未安装 PHP，先执行：

```bash
sudo apt install -y php-fpm php-mbstring php-zip php-gd php-json php-curl php-mysql
```

确认 php-fpm 运行状态：

```bash
sudo systemctl status php*-fpm
```

---

## 二、安装 phpMyAdmin

### 2.1 通过 apt 安装

```bash
sudo apt install -y phpmyadmin
```

安装过程中会出现配置向导：

- **Web server to reconfigure automatically**：不要勾选 Apache2（本环境使用 Nginx），直接按 `Tab` 选 `<OK>` 回车。
- **Configure database for phpmyadmin with dbconfig-common?**：选择 `<Yes>`。
- 设置 phpMyAdmin 的内部数据库密码：输入并牢记，例如 `PmaDbPass2024!`。

### 2.2 创建 Nginx 访问软链接

由于安装时未选择 Nginx，需要手动把 phpMyAdmin 链接到网站目录：

```bash
sudo ln -s /usr/share/phpmyadmin /var/www/html/phpmyadmin
```

### 2.3 创建 phpMyAdmin 专用数据库用户

不要用 MariaDB 的 `root` 账号日常登录 phpMyAdmin。创建一个仅管理 `pdf_print_db` 的专用用户：

```bash
sudo mysql -u root -p
```

在 MariaDB 提示符下执行：

```sql
CREATE USER IF NOT EXISTS 'pmaadmin'@'localhost' IDENTIFIED BY '你的强密码';
GRANT ALL PRIVILEGES ON pdf_print_db.* TO 'pmaadmin'@'localhost';
FLUSH PRIVILEGES;
EXIT;
```

> 密码建议 16 位以上，包含大小写字母、数字和特殊符号。

---

## 三、配置 Nginx

### 3.1 新建 Nginx 配置文件

```bash
sudo nano /etc/nginx/sites-available/phpmyadmin
```

写入以下内容：

```nginx
server {
    listen 80;
    server_name _;  # 允许通过 IP 访问

    root /var/www/html;
    index index.php index.html;

    location /phpmyadmin {
        alias /usr/share/phpmyadmin;

        index index.php index.html;

        location ~ ^/phpmyadmin/(.*\.php)$ {
            alias /usr/share/phpmyadmin/$1;
            fastcgi_pass unix:/run/php/php-fpm.sock;
            fastcgi_index index.php;
            fastcgi_param SCRIPT_FILENAME $request_filename;
            include fastcgi_params;
        }

        location ~* ^/phpmyadmin/.*\.(jpg|jpeg|png|gif|css|js|ico|svg|woff|woff2|ttf|eot)$ {
            expires 30d;
            access_log off;
        }
    }

    # 安全：限制仅允许内网访问
    location /phpmyadmin {
        allow 10.0.0.0/8;
        allow 172.16.0.0/12;
        allow 192.168.0.0/16;
        deny all;
    }
}
```

> 如果你的 php-fpm 监听的是 TCP 端口（如 `127.0.0.1:9000`），请把 `fastcgi_pass` 改为：
> ```nginx
> fastcgi_pass 127.0.0.1:9000;
> ```

### 3.2 启用配置

```bash
sudo ln -s /etc/nginx/sites-available/phpmyadmin /etc/nginx/sites-enabled/phpmyadmin
```

### 3.3 检查配置并重启 Nginx

```bash
sudo nginx -t
sudo systemctl restart nginx
```

---

## 四、安全加固（必须执行）

### 4.1 限制访问来源 IP

上面 3.1 的配置已经只允许内网 IP 访问。如果你需要从特定公网 IP 访问，补充：

```nginx
location /phpmyadmin {
    allow 你的公网IP/32;
    deny all;
}
```

### 4.2 修改访问路径（可选但推荐）

把默认的 `/phpmyadmin` 改成复杂路径，降低被扫描概率：

```bash
sudo rm /var/www/html/phpmyadmin
sudo ln -s /usr/share/phpmyadmin /var/www/html/pma_your_random_string
```

同时修改 Nginx 配置中的 `location /phpmyadmin` 为 `location /pma_your_random_string`。

### 4.3 启用 HTTPS（强烈推荐）

如果有域名证书，在 Nginx 配置中增加 443 监听并配置 SSL：

```nginx
server {
    listen 443 ssl;
    server_name db.yourdomain.com;

    ssl_certificate /path/to/cert.pem;
    ssl_certificate_key /path/to/key.pem;

    # 其余 location 配置同上
}

server {
    listen 80;
    server_name db.yourdomain.com;
    return 301 https://$server_name$request_uri;
}
```

### 4.4 安装 fail2ban 防止暴力破解

```bash
sudo apt install -y fail2ban
```

创建规则文件：

```bash
sudo nano /etc/fail2ban/jail.local
```

写入：

```ini
[nginx-pma-auth]
enabled = true
filter = nginx-pma-auth
logpath = /var/log/nginx/access.log
maxretry = 5
bantime = 3600
```

---

## 五、验证安装

### 5.1 浏览器访问

```
http://sweiweb01/phpmyadmin
```

或如果你修改了路径：

```
http://sweiweb01/pma_your_random_string
```

### 5.2 登录

- 用户名：`pmaadmin`
- 密码：你在 2.3 中设置的密码

### 5.3 检查数据库字段

1. 左侧选择 `pdf_print_db`。
2. 点击 `workflow_definitions` 表。
3. 查看表结构，确认存在以下字段：
   - `condition`（触发条件）
   - `priority`（匹配优先级）

---

## 六、常用维护命令

### 重启相关服务

```bash
sudo systemctl restart nginx
sudo systemctl restart php*-fpm
sudo systemctl restart mariadb
```

### 查看 Nginx 错误日志

```bash
sudo tail -f /var/log/nginx/error.log
```

### 备份 phpMyAdmin 配置

```bash
sudo cp -r /etc/phpmyadmin /etc/phpmyadmin.bak.$(date +%Y%m%d)
```

---

## 七、故障排查

### 7.1 访问 404 Not Found

- 检查软链接是否存在：`ls -la /var/www/html/phpmyadmin`
- 检查 Nginx 配置是否启用：`ls -la /etc/nginx/sites-enabled/`
- 检查 root 路径是否正确

### 7.2 访问 502 Bad Gateway

- 检查 php-fpm 是否运行：`sudo systemctl status php*-fpm`
- 检查 `fastcgi_pass` 路径或端口是否与 php-fpm 监听一致：
  ```bash
  sudo grep -E "listen =" /etc/php/*/fpm/pool.d/www.conf
  ```

### 7.3 登录提示"无法连接数据库"

- 确认 MariaDB 运行中：`sudo systemctl status mariadb`
- 确认用户存在且权限正确：
  ```bash
  sudo mysql -u root -p -e "SELECT user, host FROM mysql.user;"
  sudo mysql -u root -p -e "SHOW GRANTS FOR 'pmaadmin'@'localhost';"
  ```

### 7.4 访问被拒绝

- 检查 Nginx 中 `allow/deny` 规则是否放行了你的 IP。

---

## 八、回退方案

如需卸载 phpMyAdmin：

```bash
sudo rm /var/www/html/phpmyadmin
sudo rm /etc/nginx/sites-enabled/phpmyadmin
sudo apt remove --purge -y phpmyadmin
sudo systemctl restart nginx
```

---

## 九、相关账号信息记录

| 项目 | 值 |
|------|-----|
| 服务器 | sweiweb01 |
| 数据库 | pdf_print_db |
| phpMyAdmin 访问地址 | http://sweiweb01/phpmyadmin |
| phpMyAdmin 用户 | pmaadmin |
| phpMyAdmin 用户密码 | （请在下方填写） |
| phpMyAdmin 内部数据库密码 | （请在下方填写） |

---

*本手册最后更新日期：2026-07-17*
