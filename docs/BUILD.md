# 构建与演示

## 工程入口

使用根目录 Xcode 工程中的两个共享 Scheme。macOS 最低部署版本 14.0，iOS 为 17.0。没有 Swift Package 或第三方下载步骤。`mobile-sync` 当前仅保留 iPhone 使用的数据核心和两个平台的 Info.plist；不包含旧 Prototype 或独立 Package。

所有个人 Development Team 已清空。默认 Bundle ID 为 `org.example.xuanxuan-writing.demo` 和 `.ios`，用于本地演示，发布时应改成维护者自己的唯一标识。项目不包含证书、描述文件或个人 iCloud 容器 entitlement。

## Mac

在 Xcode 选择 Mac Scheme 和 My Mac 后运行。无签名命令行构建见首页；该产物仅用于本机开发验证，未做公证和面向普通用户的分发包装。

第一次打开书架应只出现《雾港来信（虚构演示）》，共三章。默认本机数据目录为 `~/Library/Application Support/XuanxuanWritingDemo`；关闭并重开会保留编辑。不会读取旧版的数据或设置。

开发验证可通过环境变量 `XUANXUAN_DEMO_ROOT` 指定专用临时根目录；此变量不用于生产迁移。普通使用者无需设置。

## iPhone 模拟器与真机

选择 iOS Scheme 和已安装的 iPhone 模拟器后运行。示例首次自动复制到应用沙盒内的 `Library/Application Support/XuanxuanWritingDemo`，不依赖 Apple ID。

真机连接后，在 Signing & Capabilities 中选择自己的 Development Team，修改 Bundle ID，按 Xcode 提示完成安装。当前工程通过文件选择器访问用户主动授权的共享目录，不需要添加旧工程的 App 专用 iCloud 容器。不要将本项目描述为已支持 CloudKit 云数据库。

如未来改用 App 专用 iCloud 容器，需单独设计容器、entitlements、签名、迁移及真机验证；本版未包含该流程。

## 手动导入同一虚构工程

1. 复制仓库的 `Examples/DemoWorkspace` 文件夹，命名为 `XuanxuanDemoShared`。保留内部 `projects.json` 与 `projects` 并列结构。
2. 本机演示时可放在普通目录；跨设备时将这份副本放在 iCloud Drive，等文件上传完成。
3. Mac 打开本机虚构作品，从“更多 → 开启同步 → 选择共享文件夹”选择 `XuanxuanDemoShared` 根目录。
4. iPhone 在书架的同步菜单中选择同一个根目录，等文件下载，必要时下拉刷新。
5. 一台设备保存并退出章节后，再在另一台设备打开。不要同时改同一章。

连接已有文件夹不会自动复制或合并本机示例。所选目录的作品登记路径会按当前设备重定位；应用会编辑其中的索引、正文与同步记录。返回本机库后，外部文件仍留在所选目录。

默认首次导入只在本机索引不存在时执行。需要重置演示时，先退出 App，备份后将上述**演示目录**改名，再重开；不要重命名旧版私人作品目录。

## 3 分钟演示顺序

- 书架打开三章虚构作品，修改一行后保存，返回书架并重开确认。
- 命令盘搜索“角色设定”，点击“参照”，展示正文与设定并排。
- “更多 → 查找替换”，查找“收音机”，临时替换为“无线电”，检查结果后恢复。
- 打开手机预览、调整字号；导出当前章节图片到临时目录。
- 展示 iPhone 书架与轻编辑；若未完成真机测试，直接说明模拟器演示及当前验证范围。

## 已知限制

同步使用系统文件服务，不能承诺实时一致或多人并发安全。快照和备份没有无限保留承诺，也不替代使用者自己的备份。文档布局和启动截图已检查，尚无长篇压力测试、无障碍专项验证或 App Store 审核记录。
