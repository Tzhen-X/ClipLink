# ClipLink / 云剪

ClipLink（中文名：**云剪**）乃 **SyncClipboard 生态之 HarmonyOS 客户端实现**。  
本项目专注于 HarmonyOS / ArkTS / Stage Model 端之体验与适配；**并非独立协议体系**。其剪贴板同步协议、服务器部署方式、主要接口约定，皆以主项目 **SyncClipboard** 为基础。

## 项目定位

- **主项目**：[`Jeric-X/SyncClipboard`](https://github.com/Jeric-X/SyncClipboard?tab=readme-ov-file)
- **本项目**：HarmonyOS 客户端实现（ClipLink / 云剪）
- **必要依赖**：如欲实际使用本客户端，须先部署或接入上游 `SyncClipboard` 服务器

换言之：

- `SyncClipboard` 负责 **服务器、协议、跨平台生态**
- `ClipLink` 负责 **HarmonyOS 客户端实现与交互适配**

## 现有能力

- HarmonyOS 三页签结构：Home / History / Settings
- 当前剪贴板预览（文字 / 图片）
- 上传、下载、前台 Auto Sync
- 历史记录同步、图片预览、点击复制、图片保存
- 本地配置持久化
- Light / Dark / Auto 主题
- 中英文应用名显示：
  - 中文设备：**云剪**
  - 英文设备：**ClipLink**

## 使用前提

本项目 **不能脱离上游主项目单独完成服务端能力**。  
使用前，请先参考主项目 README 部署服务端：

- 上游主项目：<https://github.com/Jeric-X/SyncClipboard?tab=readme-ov-file>
- 其中服务器部署、Docker、配置说明，皆以主项目文档为准

建议阅读上游 README 中如下部分：

1. **服务器**
2. **客户端配置说明**
3. **API**

## 构建与运行

### 环境

- HarmonyOS / OpenHarmony SDK API 20
- DevEco Studio 5.x
- 已配置本地签名

> `build-profile.json5` 已改为公开仓库安全模板；构建前请先替换为你本地的签名材料。

### 本地私有签名配置

- 提交到仓库的是：`build-profile.template.json5`
- 你本地私有使用：`build-profile.local.json5`
- 实际构建读取的：`build-profile.json5`（由脚本自动生成，已加入 `.gitignore`）

首次配置可执行：

```bash
cp build-profile.template.json5 build-profile.local.json5
```

然后把 `build-profile.local.json5` 改成你机器上的真实签名材料即可。  
之后提交代码时，不再需要反复改回模板。

### CLI

推荐使用仓库内包装脚本，它会优先采用 `build-profile.local.json5`，否则回退到模板配置：

```bash
./scripts/hvigorw-local.sh assembleHap --mode module -p module=entry@default -p product=default -p buildMode=debug
```

### 安装与启动

```bash
hdc install -r entry/build/default/outputs/default/entry-default-signed.hap
hdc shell aa start -a EntryAbility -b com.xiebaiyuan.syncclipboard.harmony
```

## 项目结构

```text
AppScope/                        应用级资源
entry/src/main/ets/entryability  HarmonyOS 入口能力
entry/src/main/ets/pages/        Home / History / Settings
entry/src/main/ets/services/     服务端通信、本地存储、轮询
entry/src/main/ets/utils/        主题、剪贴板、图片等工具
entry/src/main/resources/        模块资源与本地化文案
```

## 协议与兼容性说明

本项目与上游 `SyncClipboard` 服务端接口保持兼容，主要依赖：

- `GET /SyncClipboard.json`
- `PUT /SyncClipboard.json`
- `POST /api/history/query`
- `POST /api/history`
- `GET /api/history/{profileId}`

接口字段、哈希规则、历史记录模型，以主项目文档与实现为准。  
若上游协议升级，本客户端亦需同步适配。

## 致谢与引用

本项目基于以下上游项目之协议、接口设计、服务端部署方案与整体生态而实现：

- **SyncClipboard**  
  <https://github.com/Jeric-X/SyncClipboard?tab=readme-ov-file>

特别感谢上游作者与社区维护者提供：

- 服务端实现
- Docker / 独立部署方案
- 协议与 API 说明
- 多平台客户端生态

若你因本项目受益，也请同时关注并支持上游主项目。

## License

本项目采用 **MIT License**。详见 [LICENSE](./LICENSE)。

上游主项目 `SyncClipboard` 同样采用 MIT License；本项目 README 中已明确引用并致谢其来源。

## 图标权利声明

本项目的应用图标及相关视觉标识，其权利归本项目作者所有。  
未经明确授权，不得转载、复制、分发、修改或用于其他项目、产品、宣传材料及再发布场景。
