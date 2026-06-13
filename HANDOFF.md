# Remote Info 交接文档

## 会话摘要

本次会话围绕一个自用的原生 macOS menu bar app 展开，用 SwiftUI + SwiftPM 实现远程 Linux 主机遥测面板。应用通过本机 `/usr/bin/ssh` 直接采集数据，不保存远程密码、私钥或 token；配置放在用户本机的 `~/.config/remote-info/hosts.json`，仓库只保留安全示例配置。

当前代码已推送到 GitHub `origin/main`，最近提交为 `951f454 Improve telemetry dashboard and packaging`。生成本交接文档前，工作区是干净的；生成后只有 `HANDOFF.md` 是新的未提交文件。

## 完成的工作

- 建成原生 macOS menu bar app，面板使用左侧主机列表 + 右侧详情卡片布局。
- 接入直接 SSH 采集，远程端无需 daemon；采集 CPU、load、内存、磁盘、uptime、kernel、SSH latency、物理网卡上下行、公网 IP/位置、Top CPU 进程、NVIDIA GPU 遥测。
- 主机采集已并发执行；启动时刷新一次，之后默认每 30 分钟刷新一次；面板打开不强制刷新，保留手动刷新按钮。
- Top CPU 显示前 5 个进程，并展示 CPU 和内存占用；进程名使用短命令名，不采集完整命令行参数。
- 网络流量聚合物理接口，排除 loopback、VPN、bridge、Docker 等虚拟接口；IP/LOC 有数据时显示，没有数据时显示占位。
- GPU 通过 `nvidia-smi --query-gpu` 采集；有 GPU 时展示 util、VRAM、power、fan、clock、temperature；无 NVIDIA 遥测时保留友好提示卡片。
- UI 已改为更紧凑的可扩展布局，支持多台主机列表；metric 使用绿色、黄色、橙色、红色等严重程度颜色。
- 新增猫头鹰主题 app icon，并把菜单栏状态图标换成同主题模板图标。
- `script/build_and_run.sh` 支持 `--mock`、`--verify`、`--install`；`--install` 会打包到 `/Applications/RemoteInfo.app` 并从 Applications 启动。
- 已安装并验证 secret 扫描工具：`gitleaks 8.30.1`、`trufflehog 3.95.5`、`detect-secrets 1.5.0`。
- 已执行并通过验证：
  - `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`，57 tests, 0 failures
  - `./script/build_and_run.sh --install`
  - `script/check_no_secrets.sh`
  - `gitleaks detect --source . --redact --verbose`
  - `trufflehog git file://$PWD --no-update --fail --results=verified,unknown,unverified --force-skip-binaries`
  - `detect-secrets scan --all-files`

## 待完成的工作

- 当前未提交变更：`HANDOFF.md`，即本交接文档。
- README 的 GPU Telemetry 段落可在下次顺手核对：代码现在对无 GPU 主机会显示友好提示卡片，而 README 仍偏向描述“无 GPU 时省略 GPU panel”的旧行为。
- 尚未做自动启动、LaunchAgent、Settings UI、主机管理 UI；当前仍通过本机配置文件管理主机。
- 尚未做正式签名、notarization 或 release 包；当前为自用安装到 `/Applications`。
- 尚未把 secret 扫描接入 Git hook 或 CI，只是本机工具已安装并可手动运行。

## 关键决策

- 这是自用 app，但 UI 目标不是简陋工具；保持原生 macOS 体验、稳定布局和可读的毛玻璃卡片风格。
- 不上架 App Store，因此暂不走 sandbox / App Store review 路线；但仍避免提交敏感信息。
- 远程采集使用 SSH key / SSH config alias，不在 app 内保存密码；`BatchMode=yes` 避免 UI 卡在密码交互。
- 仓库内禁止提交真实主机信息、IP、端口、用户名、密码、私钥路径、OpenAI/GPT token 等。真实配置只放本机用户目录。
- 采集频率偏保守：30 分钟一次；失败时保留上一次成功数据的设计可继续保留，避免短暂网络问题导致 UI 全部离线。
- UI mock 阶段使用 `REMOTE_INFO_MOCK_MODE=1`，不依赖真实服务器；正式运行读取 `~/.config/remote-info/hosts.json`。

## 重要文件

- `Sources/RemoteInfoApp/App/RemoteInfoApp.swift`：app 入口、menu bar icon、启动刷新。
- `Sources/RemoteInfoApp/Views/MenuBarPanelView.swift`：主面板布局、左侧主机列表、右侧详情区域。
- `Sources/RemoteInfoApp/Views/HostCardView.swift`：主机详情卡片和各 telemetry 卡片。
- `Sources/RemoteInfoApp/Views/HostListRowView.swift`：左侧主机列表行。
- `Sources/RemoteInfoCore/Stores/TelemetryStore.swift`：并发刷新、定时刷新、stale 状态。
- `Sources/RemoteInfoCore/Services/TelemetryCollector.swift`：远程 shell 采集脚本。
- `Sources/RemoteInfoCore/Services/TelemetryParser.swift`：采集输出解析。
- `Sources/RemoteInfoCore/Support/Formatters.swift`：显示格式化。
- `Sources/RemoteInfoCore/Support/MetricSeverity.swift`：metric 严重程度和颜色分级依据。
- `config/hosts.example.json`：安全示例配置。
- `script/build_and_run.sh`：构建、运行、安装脚本。
- `script/check_no_secrets.sh`：staged 文件 secret 扫描。
- `Resources/AppIcon.png`、`Resources/AppIcon.icns`：app 图标资源。
- `mockups/scalable-menubar-layout.html`：可视化 mockup 参考。

## 下一步建议

1. 下次开工先确认状态：

   ```bash
   git status -sb
   git log --oneline -3
   ```

2. 本机启动已安装 app：

   ```bash
   open -a RemoteInfo
   ```

3. 开发 UI 时优先用 mock 数据：

   ```bash
   ./script/build_and_run.sh --mock
   ```

4. 改采集或解析逻辑后运行测试：

   ```bash
   DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
   ```

5. 打包安装到 Applications：

   ```bash
   ./script/build_and_run.sh --install
   ```

6. 提交前做 secret 扫描：

   ```bash
   script/check_no_secrets.sh
   gitleaks detect --source . --redact --verbose
   trufflehog git file://$PWD --no-update --fail --results=verified,unknown,unverified --force-skip-binaries
   detect-secrets scan --all-files
   ```

