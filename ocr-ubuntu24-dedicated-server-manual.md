# 纸质表格识别 OCR 服务独立服务器部署手册

## 一、部署架构

本方案将 OCR 服务部署在一台独立的 Ubuntu 24.04 LTS 服务器上，现有 Node.js 服务器通过内网 HTTP 调用 OCR 接口。

```
手机/前端 → Node.js 业务服务器 → OCR 专用服务器
                         （内网调用）
```

**架构优势**：
- OCR 模型加载和图像处理不占用 Node.js/MariaDB 服务器资源
- 两台服务器可独立维护、独立扩容
- 现有生产服务器无需安装 Python、OpenCV、PaddleOCR 等依赖
- 通过内网访问可降低 OCR 服务暴露风险

## 二、服务器环境要求

### 2.1 OCR 服务器

- 操作系统：Ubuntu 24.04 LTS（64 位）
- CPU：x86_64 架构，建议 4 核及以上
- 内存：建议 8GB 及以上（PaddleOCR 模型常驻内存）
- 磁盘：至少 20GB 可用空间
- 网络：与 Node.js 服务器处于同一内网，或可互相访问
- Python：Ubuntu 24.04 系统自带 Python 3.12，可直接用于虚拟环境

### 2.2 网络规划

| 项目 | 建议 |
|------|------|
| OCR 服务监听地址 | 0.0.0.0:5000 或内网 IP:5000 |
| Node.js 到 OCR | 通过内网 IP 访问，如 http://10.0.1.20:5000 |
| 公网访问 | 不建议直接暴露 5000 端口；如需公网访问，应通过 Nginx + HTTPS + IP 白名单 |
| 防火墙 | 仅允许 Node.js 服务器 IP 访问 OCR 服务器 5000 端口 |

## 三、OCR 服务器部署

### 3.1 系统依赖安装

以 root 或 sudo 用户登录 OCR 服务器，执行：

```bash
sudo apt update
sudo apt install -y \
  python3 python3-venv python3-dev python3-pip \
  libgl1 libglib2.0-0 libsm6 libxext6 libxrender-dev \
  libgomp1 \
  wget curl
```

### 3.2 创建运行用户与目录

```bash
id ocr-service >/dev/null 2>&1 || sudo useradd -r -s /bin/false ocr-service
sudo mkdir -p /opt/ocr-service
sudo chown ocr-service:ocr-service /opt/ocr-service
```

### 3.3 上传服务代码

将以下文件上传到 `/opt/ocr-service/`：

```
app.py
align.py
ocr_engine.py
validator.py
fields.example.json
requirements.txt
```

示例命令（从本地 Windows Git Bash 或 WSL）：

```bash
scp /c/Users/Administrator/Desktop/xiugaiqian/ocr-service/*.py root@ocr-server:/opt/ocr-service/
scp /c/Users/Administrator/Desktop/xiugaiqian/ocr-service/*.txt root@ocr-server:/opt/ocr-service/
scp /c/Users/Administrator/Desktop/xiugaiqian/ocr-service/*.json root@ocr-server:/opt/ocr-service/
```

设置权限：

```bash
sudo chown -R ocr-service:ocr-service /opt/ocr-service
sudo chmod -R u=rwX,go=rX /opt/ocr-service
```

### 3.4 创建虚拟环境并安装依赖

```bash
cd /opt/ocr-service
sudo -u ocr-service python3 -m venv .venv
sudo -u ocr-service .venv/bin/pip install --upgrade pip
sudo -u ocr-service .venv/bin/pip install -r requirements.txt
```

> 说明：`requirements.txt` 中已锁定 `numpy==1.26.4`，避免 PaddlePaddle 2.6.2 与 numpy 2.x 的 ABI 不兼容问题。请勿安装 `numpy>=2.0`。

验证安装：

```bash
sudo -u ocr-service .venv/bin/python -c "import cv2; import paddleocr; print('cv2:', cv2.__version__, 'paddleocr:', paddleocr.__version__)"
```

### 3.5 字段配置

根据真实纸质表格创建字段配置：

```bash
cd /opt/ocr-service
sudo -u ocr-service cp fields.example.json fields.json
sudo -u ocr-service nano fields.json
```

配置说明：
- `x`、`y`、`w`、`h` 为相对矫正后表格正视图的 0~1 比例坐标
- `validation` 支持 `required`、`type`、`min`、`max`、`min_length`、`max_length`、`pattern`、`options`

坐标标定方法：先用一张标准正视图调用接口并开启 `debug=true`，服务会保存矫正后的正视图，再用图像工具量取各字段相对位置。

### 3.6 配置 systemd 服务

```bash
sudo tee /etc/systemd/system/ocr-service.service > /dev/null << 'EOF'
[Unit]
Description=Local OCR Service (PaddleOCR + Flask)
After=network.target

[Service]
Type=simple
User=ocr-service
Group=ocr-service
WorkingDirectory=/opt/ocr-service
Environment=OCR_SERVICE_PORT=5000
Environment=PYTHONUNBUFFERED=1
ExecStart=/opt/ocr-service/.venv/bin/python /opt/ocr-service/app.py
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
```

启动服务：

```bash
sudo systemctl daemon-reload
sudo systemctl enable ocr-service
sudo systemctl start ocr-service
```

查看状态：

```bash
sudo systemctl status ocr-service --no-pager
sudo journalctl -u ocr-service -f
```

### 3.7 健康检查

```bash
curl http://127.0.0.1:5000/health
```

正常返回：

```json
{"status":"ok"}
```

### 3.8 测试识别接口

准备一张真实样张 `/tmp/sample.jpg`，执行：

```bash
curl -s -X POST http://127.0.0.1:5000/recognize \
  -F "image=@/tmp/sample.jpg" \
  -F "config=/opt/ocr-service/fields.json" \
  -F "debug=true" | python3 -m json.tool
```

首次调用会下载 OCR 模型，耗时 1~5 分钟。

## 四、Node.js 服务器对接

### 4.1 安装依赖

在现有 Node.js 项目根目录执行：

```bash
npm install multer axios form-data
```

### 4.2 配置环境变量

将 OCR 服务器内网地址写入 `.env`：

```bash
OCR_SERVICE_URL=http://10.0.1.20:5000/recognize
```

### 4.3 接口调用

前端上传图片到 Node.js 的 `/api/ocr/recognize`，Node.js 代理转发到 OCR 服务器。

示例请求：

```bash
curl -X POST http://your-node-server/api/ocr/recognize \
  -H "Cookie: session=your-session-cookie" \
  -F "image=@/tmp/sample.jpg" \
  -F "config=/opt/ocr-service/fields.json" \
  -F "debug=true"
```

## 五、网络安全配置

### 5.1 OCR 服务器防火墙

仅允许 Node.js 服务器 IP 访问 OCR 服务端口：

```bash
# 假设 Node.js 服务器内网 IP 为 10.0.1.10
sudo ufw allow from 10.0.1.10 to any port 5000 proto tcp comment 'Allow Node.js server to OCR'

# 拒绝其他来源访问 5000 端口
sudo ufw deny 5000/tcp

# 启用防火墙（如尚未启用）
sudo ufw enable
```

### 5.2 绑定内网地址（可选）

如果 OCR 服务器只有内网网卡需要监听，可在 `app.py` 中将 `host` 改为具体内网 IP：

```python
app.run(host='10.0.1.20', port=port, debug=False)
```

或保持 `0.0.0.0` 并通过防火墙限制来源。

### 5.3 Nginx 反向代理（可选）

如需通过域名或 HTTPS 访问 OCR 服务，在 OCR 服务器上配置 Nginx：

```nginx
server {
    listen 443 ssl;
    server_name ocr.your-domain.com;

    client_max_body_size 20M;

    # 仅允许 Node.js 服务器 IP
    allow 10.0.1.10;
    deny all;

    location / {
        proxy_pass http://127.0.0.1:5000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_read_timeout 120s;
    }
}
```

## 六、目录结构参考

```
/opt/ocr-service/
├── .venv/                 # Python 3.12 虚拟环境
├── app.py                 # Flask 服务入口
├── align.py               # 四角检测与透视矫正
├── ocr_engine.py          # PaddleOCR 封装
├── validator.py           # 字段校验规则
├── fields.example.json    # 示例配置
├── fields.json            # 真实表格配置
└── debug/                 # debug=true 时保存的矫正后图片
```

## 七、常见问题排查

### 7.1 Node.js 无法访问 OCR 服务

- 检查 OCR 服务是否启动：`curl http://127.0.0.1:5000/health`
- 检查防火墙是否放行 Node.js 服务器 IP
- 检查 OCR 服务是否监听 `0.0.0.0`，或绑定的内网 IP 是否正确
- 从 Node.js 服务器直接 `curl` OCR 服务器内网地址测试连通性

### 7.2 识别准确率低

- 确认字段坐标精确覆盖目标单元格
- 提高拍摄清晰度，避免阴影和反光
- 对关键字段在 `validation` 中设置 `type: integer` 等强校验规则

### 7.3 模型下载慢或失败

- 在国内服务器可配置 PaddleOCR 镜像源
- 或手动下载模型后放到 `~/.paddleocr/` 对应目录

#### 离线部署模型步骤（Windows 下载后上传）

在能访问外网的 Windows 机器上，使用 Python 3.12 虚拟环境安装与本服务一致的依赖：

```cmd
python -m venv ocr-download
ocr-download\Scripts\activate
pip install -r requirements.txt
```

然后执行一次初始化，触发 PaddleOCR 自动下载模型：

```cmd
python -c "from paddleocr import PaddleOCR; ocr=PaddleOCR(use_angle_cls=True, lang='ch'); print('done')"
```

下载完成后，模型会保存在当前用户目录下：

```
C:\Users\Administrator\.paddleocr\
```

将其打包并上传到 OCR 服务器：

```bash
# 在 Windows 上打包（PowerShell 或 7-zip）
Compress-Archive -Path C:\Users\Administrator\.paddleocr -DestinationPath C:\Users\Administrator\paddleocr-models.zip

# 上传到 OCR 服务器
scp C:\Users\Administrator\paddleocr-models.zip root@ocr-server:/tmp/
```

在 OCR 服务器上解压到运行用户主目录：

```bash
sudo mkdir -p /home/ocr-service/.paddleocr
sudo unzip -o /tmp/paddleocr-models.zip -d /home/ocr-service/
sudo chown -R ocr-service:ocr-service /home/ocr-service/.paddleocr
sudo systemctl restart ocr-service
```

> 注意：模型目录必须属于 `ocr-service` 用户，否则服务运行时无法读取。

### 7.4 四角检测失败

- 确保表格四角明显、背景对比度高
- 传入 `expected_aspect` 参数辅助检测
- 启用 `debug=true` 查看矫正效果

## 八、后续优化建议

1. **高可用**：为 OCR 服务配置进程守护和日志轮转
2. **负载均衡**：高并发场景可部署多台 OCR 服务器，通过 Nginx 负载均衡
3. **GPU 加速**：如 OCR 服务器有 NVIDIA GPU，可安装 `paddlepaddle-gpu`
4. **HTTPS 与认证**：公网访问建议配置 SSL 证书和 Basic Auth 或 Token 认证
5. **监控**：为 OCR 服务添加响应时间、识别成功率、资源占用等监控
