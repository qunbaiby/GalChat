# GalChat AI Gateway

官方托管 AI 模式的最小网关。供应商 API Key 仅从服务端环境变量读取，不会返回给客户端。

## 本地启动

```powershell
cd backend/ai_gateway
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
$env:GALCHAT_JWT_SECRET = "replace-with-at-least-32-random-characters"
$env:DEEPSEEK_API_KEY = "your-server-side-deepseek-key"
uvicorn app:app --host 127.0.0.1 --port 8787
```

正式服务器将 `GALCHAT_ENVIRONMENT` 设为 `production` 后，Gateway 会在启动时拒绝不安全配置：JWT Secret 和管理员令牌必须至少 32 字符，Fernet 主密钥必须有效，数据库必须使用明确的持久化路径，验证码邮件不能使用 `console` 模式，SMTP 主机、端口、发件人和认证信息必须完整。负载均衡存活探针使用 `/health`，就绪探针使用 `/ready`；后者会验证数据库可写、HTTP 客户端状态和邮件配置，并返回 schema 版本。

## 正式服务器部署

推荐在反向代理后使用容器运行，Gateway 端口只绑定服务器回环地址。先在 `backend/ai_gateway` 目录创建不会提交到 Git 的 `.env`，填入 `.env.example` 中的生产值，然后执行：

```bash
docker compose --env-file .env -f compose.production.yml config
docker compose --env-file .env -f compose.production.yml build
docker compose --env-file .env -f compose.production.yml up -d
docker compose --env-file .env -f compose.production.yml exec gateway python -c "import urllib.request; print(urllib.request.urlopen('http://127.0.0.1:8787/ready').read().decode())"
docker compose --env-file .env -f compose.production.yml exec gateway python preflight.py
```

`preflight.py` 不调用供应商或发送邮件；它检查公开探针、SMTP 静态就绪状态、管理员鉴权边界，并创建经过完整性检查的在线备份。成功时输出 `{"status": "passed", ...}`，任一检查失败时退出码为 1。

容器以非 root 用户运行、使用只读根文件系统、移除 Linux capabilities，并限制 CPU、内存和进程数；`/data` 保存到命名卷。Nginx、Caddy 或云负载均衡器负责 HTTPS，只向公网暴露 443；不要直接公开 8787。若代理不在可信内网，应收紧 Dockerfile 中 Uvicorn 的 `--forwarded-allow-ips`，不要信任任意来源的转发头。

## 数据库备份与恢复

在线备份使用 SQLite Backup API，可在 Gateway 运行时生成一致快照：

```bash
python maintenance.py backup --database /data/ai_gateway.db --output /data/backups/ai_gateway.db
python maintenance.py inspect /data/backups/ai_gateway.db
```

恢复必须先停止 Gateway，工具会检查完整性与 schema 兼容性，并将恢复前数据库保留为 `.before-restore-<UTC时间>`：

```bash
docker compose --env-file .env -f compose.production.yml stop gateway
python maintenance.py restore /data/backups/ai_gateway.db --database /data/ai_gateway.db --confirm
docker compose --env-file .env -f compose.production.yml start gateway
```

数据库备份和 `GALCHAT_SECRETS_MASTER_KEY` 必须分开保存。建议每天备份，至少保留 7 个日备份和 4 个周备份，并定期在隔离环境执行真实恢复演练。

## 上线检查表

- 域名 HTTPS 证书有效，HTTP 强制跳转 HTTPS。
- 8787 仅监听回环或私有网络，管理后台限制来源 IP 或置于 VPN。
- JWT、管理员令牌、Fernet Key 与 SMTP 密码均由 Secret Manager 注入。
- `/health` 与 `/ready` 均返回 200，`/ready` schema 版本符合当前程序且 `email_configured` 为 `true`。
- 容器内执行 `python preflight.py`，结果为 `passed`，并将生成的备份复制到独立存储。
- 使用真实账号分别完成 Chat、TTS、ASR、Embedding、Vision 和 Image 调用。
- 验证错误 Key、Token 过期、额度耗尽、供应商超时和图片下载失败。
- 执行一次在线备份、完整性检查和隔离恢复演练。
- 日志平台可按 `request_id` 查询，且日志中没有 Token、提示词、音频、图片或供应商 Key。

客户端设置：

- AI 服务来源：`官方托管`
- 官方服务地址：`http://127.0.0.1:8787/v1/game`
- 玩家通过邮箱验证码注册，之后使用用户名或邮箱和密码登录。
- 登录成功后使用短期 JWT 调用网关，并通过可轮换 Refresh Token 恢复会话。

## 开发测试账号

开发环境默认创建无需注册的测试账号。需要覆盖凭据或禁用时，可设置以下环境变量：

```powershell
$env:GALCHAT_ENVIRONMENT = "development"
$env:GALCHAT_DEV_TEST_ACCOUNT_ENABLED = "true"
$env:GALCHAT_DEV_TEST_USERNAME = "galchat_test"
$env:GALCHAT_DEV_TEST_EMAIL = "test@galchat.local"
$env:GALCHAT_DEV_TEST_PASSWORD = "GalChatTest2026!"
```

禁用测试账号：

```powershell
$env:GALCHAT_DEV_TEST_ACCOUNT_ENABLED = "false"
```

默认测试凭据：

- 用户名：`galchat_test`
- 密码：`GalChatTest2026!`

## 管理控制台

管理控制台用于查看 Gateway 服务状态、账号、会话和每日 AI 额度。默认本地地址：

```text
http://127.0.0.1:8787/admin
```

### 使用一键启动脚本

在项目根目录双击 `start_backend.bat`。如果没有配置固定管理员令牌，脚本会为本次启动生成一个 64 位临时令牌，并在窗口中显示：

```text
Admin console: http://127.0.0.1:8787/admin
Admin token: <本次启动生成的管理员令牌>
```

保持后端窗口开启，在浏览器访问控制台地址并输入窗口中的令牌。关闭后端后，本次临时令牌随进程失效；下次启动会生成新令牌。

### 手动启动

后台默认关闭。启动前必须配置独立管理员令牌：

```powershell
$env:GALCHAT_ENVIRONMENT = "development"
$env:GALCHAT_JWT_SECRET = "replace-with-at-least-32-random-characters"
$env:DEEPSEEK_API_KEY = "your-server-side-deepseek-key"
$env:GALCHAT_ADMIN_TOKEN = "replace-with-a-random-token-at-least-32-characters"
uvicorn app:app --host 127.0.0.1 --port 8787
```

未设置 `GALCHAT_ADMIN_TOKEN` 时，`/admin` 页面仍可加载，但所有 `/admin/api/*` 管理接口都会返回 `503`，无法读取后台数据。

### 配置固定管理员令牌

本地开发需要跨启动保留同一个管理员令牌时，可在 Windows PowerShell 5.1 中生成强随机令牌并保存为当前用户环境变量：

```powershell
$bytes = New-Object byte[] 32
$rng = [Security.Cryptography.RandomNumberGenerator]::Create()
$rng.GetBytes($bytes)
$rng.Dispose()
$token = ([BitConverter]::ToString($bytes) -replace '-', '').ToLowerInvariant()

[Environment]::SetEnvironmentVariable(
	'GALCHAT_ADMIN_TOKEN',
	$token,
	'User'
)
```

设置后需要重新启动后端。不要将令牌写入 Git、截图、日志或公开聊天记录。生产环境应使用云平台 Secret Manager 注入固定强随机令牌。

删除本地固定令牌：

```powershell
[Environment]::SetEnvironmentVariable('GALCHAT_ADMIN_TOKEN', $null, 'User')
```

### 当前功能

控制台提供：

- 供应商是否已配置、服务环境、模型白名单和限流状态。
- 输入新的供应商 API Key、Base URL 和模型白名单，并由服务端测试后加密保存。
- 分别配置 TTS、ASR、向量、图片生成和多模态的 API Key、Base URL、模型与资源 ID。
- 删除控制台保存的加密配置，并回退到服务器环境变量。
- 注册账号、有效会话、今日请求和今日活跃账号统计。
- 分页账号列表、脱敏邮箱、今日用量、剩余额度和有效会话数。
- 查看不包含密钥内容的供应商配置操作审计记录。

管理接口：

- `GET /admin/api/overview`：账号、调用、能力状态与分能力 Token 运行统计。
- `GET /admin/api/users?limit=50&offset=0`：分页账号和额度摘要。
- `GET /admin/api/provider`：供应商配置状态，不返回 API Key。
- `POST /admin/api/provider/test`：测试候选供应商配置，不保存。
- `PUT /admin/api/provider`：服务端测试成功后加密保存并立即生效。
- `DELETE /admin/api/provider/key`：删除加密配置并回退到环境变量。
- `GET /admin/api/capability-providers`：查看 TTS、ASR、向量、生图和多模态的脱敏配置状态。
- `PUT /admin/api/capability-providers/{capability}`：加密保存指定能力配置并立即热更新。
- `DELETE /admin/api/capability-providers/{capability}`：删除指定能力配置并回退到环境变量。
- `GET /admin/api/audit-logs`：查看管理操作审计记录。

管理接口使用独立的 `Authorization: Bearer <GALCHAT_ADMIN_TOKEN>`，玩家 Access Token 无法访问。

### 安全边界

控制台遵循以下限制：

- 不显示或返回 `DEEPSEEK_API_KEY`。
- 不返回密码哈希、Refresh Token 或 Refresh Token 哈希。
- 邮箱只显示脱敏结果。
- 管理员令牌与玩家 JWT 完全独立。
- 管理员令牌只保存在浏览器当前标签页的 `sessionStorage` 中，关闭标签页后自动清除。
- 后台只允许测试、替换或删除供应商配置；账号、密码、会话和玩家认证凭证保持只读且不可修改。
- 生产环境必须通过 HTTPS 暴露后台，并在反向代理或防火墙层进一步限制管理端访问来源。

### 供应商密钥加密存储

从控制台保存的供应商 API Key 使用 Fernet 对称加密后写入 SQLite。数据库只保存密文；加密主密钥来自 `GALCHAT_SECRETS_MASTER_KEY`，不会写入数据库。

一键启动脚本会在首次启动时生成本地主密钥，并保存到 Git 已忽略的文件：

```text
backend/ai_gateway/data/.secrets-master-key
```

该文件必须与数据库分开备份。丢失或更换主密钥后，已有密文无法解密，需要删除旧加密配置并重新输入供应商 API Key。不要提交或公开该文件。

手动启动时可生成 Fernet 主密钥：

```powershell
& 'E:\GalChat\GalChat\.venv\Scripts\python.exe' -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())"
```

将输出通过环境变量注入：

```powershell
$env:GALCHAT_SECRETS_MASTER_KEY = "生成的 Fernet 主密钥"
```

生产环境必须通过 Secret Manager 注入 `GALCHAT_SECRETS_MASTER_KEY`，并为其配置备份和轮换策略。DeepSeek Chat 的控制台保存操作会先由 Gateway 使用候选 Key 发起最小供应商请求；只有测试成功后才会覆盖当前配置。TTS、ASR、向量、生图和多模态配置不会在后台自动发起可能计费的合成或生成请求，保存后立即生效且不需要重启 Gateway。游戏客户端已通过官方代理消费 TTS、ASR、向量、生图和多模态配置。

其他官方能力也可以通过环境变量提供兜底配置：

```text
GALCHAT_TTS_API_KEY / GALCHAT_TTS_BASE_URL / GALCHAT_TTS_MODEL / GALCHAT_TTS_RESOURCE_ID
GALCHAT_ASR_API_KEY / GALCHAT_ASR_BASE_URL / GALCHAT_ASR_MODEL
GALCHAT_EMBEDDING_API_KEY / GALCHAT_EMBEDDING_BASE_URL / GALCHAT_EMBEDDING_MODEL
GALCHAT_IMAGE_API_KEY / GALCHAT_IMAGE_BASE_URL / GALCHAT_IMAGE_MODEL
GALCHAT_VISION_API_KEY / GALCHAT_VISION_BASE_URL / GALCHAT_VISION_MODEL
```

各能力拥有独立的玩家每日额度。环境变量作为初始默认值，未配置时回退 `GALCHAT_DAILY_REQUEST_LIMIT`：

```text
GALCHAT_CHAT_DAILY_LIMIT
GALCHAT_TTS_DAILY_LIMIT
GALCHAT_ASR_DAILY_LIMIT
GALCHAT_EMBEDDING_DAILY_LIMIT
GALCHAT_VISION_DAILY_LIMIT
GALCHAT_IMAGE_DAILY_LIMIT
```

管理控制台的“分能力用量”可以即时修改并持久化这些限额；控制台保存值优先于环境变量，修改会写入审计日志。账号接口继续保留旧的顶层 `limit`、`used`、`remaining`，并新增 `capabilities` 分项，兼容旧版客户端。

测试账号只会在 `GALCHAT_ENVIRONMENT=development` 时创建。生产环境即使误设 `GALCHAT_DEV_TEST_ACCOUNT_ENABLED=true` 也不会创建。

生产环境必须使用 HTTPS，并将 `DEEPSEEK_API_KEY` 放入云平台 Secret Manager。不要提交 `.env`。

## 接口

- `GET /health`
- `POST /v1/auth/device/register`
- `POST /v1/auth/device/login`
- `POST /v1/auth/refresh`
- `POST /v1/auth/logout`
- `POST /v1/auth/logout-all`
- `POST /v1/auth/email/code`
- `POST /v1/auth/email/register`
- `POST /v1/auth/email/login`
- `POST /v1/auth/password/reset/code`
- `POST /v1/auth/password/reset`
- `GET /v1/account/quota`
- `GET /v1/account/profile`
- `POST /v1/game/chat/completions`
- `POST /v1/game/tts/speech`
- `POST /v1/game/asr/transcriptions`
- `POST /v1/game/embeddings`
- `POST /v1/game/vision/responses`
- `POST /v1/game/images/generations`

聊天接口兼容客户端当前的 OpenAI Chat Completions JSON 和 SSE 格式。网关会拒绝额外字段、非白名单模型、超长消息和超额请求。

TTS 接口接收文本、音色 ID、音频格式、采样率、语速和音量参数。供应商 URL、API Key、模型与 Resource ID 始终由 Gateway 注入，客户端不能覆盖。文本最多 2000 个字符，仅支持 `mp3` 和 `wav`；供应商超时返回 `504`，未配置官方 TTS 时返回 `503`。

ASR 接口接收 16kHz 单声道 WAV 的纯 Base64 内容，编码后最多 800 万字符。供应商 URL、API Key、模型和音频 data URL 前缀由 Gateway 注入；供应商超时返回 `504`，未配置官方 ASR 时返回 `503`。官方模式下 Godot 使用玩家 Access Token，个人模式仍直接使用玩家自己的 DashScope Key。

Embedding 接口只接收单段文本，最长 20000 个字符。供应商 URL、API Key、Endpoint ID/模型和 `encoding_format` 由 Gateway 注入，客户端不能覆盖。官方模式下记忆系统使用玩家 Access Token；个人模式继续读取玩家本地的豆包向量 Key 和 Endpoint。供应商失败不会消耗玩家额度。

Vision 接口接收系统提示、用户提示、纯 Base64 图片和明确的媒体类型，仅支持 JPEG 与 PNG。供应商 URL、API Key 和模型由 Gateway 注入，客户端不能覆盖；供应商超时或请求失败时会回滚本次玩家额度。

Image 接口只接收生成提示词，模型、尺寸、水印、响应格式和供应商凭据均由 Gateway 注入。Gateway 会验证并下载供应商临时 HTTPS 图片，或接收供应商 Base64 响应，最终统一返回经过格式检查的图片 Base64；上游失败、图片下载失败或图片格式无效时会回滚本次玩家额度。

Gateway 会记录各能力的请求状态、HTTP 状态、延迟和负载单位，用于后台统计。Chat、TTS 与 Embedding 的单位为文本字符数，ASR 与 Vision 为近似输入字节数，Image 为生成张数。事件记录不包含提示词、文本内容、音频、图片、玩家 Token 或供应商密钥。

## 认证与额度

邮箱账号登录会签发短期 Access JWT 和可轮换的 Refresh Token。密码使用 Argon2 保存，验证码和 Refresh Token 只保存哈希。聊天请求按 UTC 日期扣减玩家每日额度，达到上限后返回 `429`。

`GALCHAT_PLAYER_TOKENS` 仅用于兼容开发工具，不应在生产环境配置。单实例部署可使用 SQLite；多实例生产部署应迁移到 PostgreSQL，并将限流状态迁移到 Redis。
