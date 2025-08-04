# Qt6 ARM交叉编译更新说明

## 主要更新内容

### 1. 添加Host Qt支持

为了解决ARM交叉编译中的工具链依赖问题，所有构建脚本现在都支持自动下载和配置Host Qt。

#### 自动下载的Host Qt版本：
- **Windows**: `Qt_6.9.1-static-Release_mingw1510_64_UCRT.7z`
- **Linux**: `Qt_6.9.1-static-Release_gcc13_2_0_64_linux.tar.gz`

#### 下载来源：
```
https://github.com/yuanpeirong/buildQt/releases/download/Qt6.9.1_rev0/
```

### 2. 更新的脚本文件

#### Windows ARM交叉编译脚本：
- `build-qt6-arm64_aarch64_gcc.cmd` - 支持AArch64架构
- `build-qt6-arm32_armv7l_gcc.cmd` - 支持ARM32架构

#### Linux ARM交叉编译脚本：
- `build-qt6-arm64_aarch64_gcc.sh` - 通用ARM交叉编译脚本
- `debug-qt6-arm-config.sh` - 调试和诊断脚本

#### GitHub Actions工作流程：
- `.github/workflows/build-qt6-arm.yml` - 主要构建工作流程
- 包含Host Qt自动下载和配置

### 3. 新增功能特性

#### 自动化Host Qt管理：
- 自动检测Host Qt是否存在
- 如果不存在，自动下载预编译版本
- 下载失败时，自动构建最小Host Qt
- 验证Host Qt工具可用性

#### 改进的错误处理：
- 更详细的错误信息和诊断
- 自动重试机制
- 备用方案支持

#### 增强的配置选项：
- 添加 `-qt-host-path` 参数
- 优化的交叉编译配置
- 更好的模块裁剪

### 4. 目录结构

```
QtBuild/
├── Qt6Build/
│   ├── build-qt6-arm64_aarch64_gcc.cmd      # Windows AArch64交叉编译
│   ├── build-qt6-arm32_armv7l_gcc.cmd       # Windows ARM32交叉编译
│   ├── build-qt6-arm64_aarch64_gcc.sh       # Linux ARM交叉编译
│   ├── debug-qt6-arm-config.sh             # 调试脚本
│   ├── build-qt6-arm-all.cmd               # Windows通用启动脚本
│   ├── qt-arm.conf                         # ARM设备配置
│   ├── ARM_CROSS_COMPILE_README.md         # 详细文档
│   └── TROUBLESHOOTING.md                  # 故障排除指南
├── .github/workflows/
│   ├── build-qt6-arm.yml                   # ARM构建工作流程
│   ├── scheduled-qt6-arm.yml               # 定期构建
│   ├── test-qt6-arm.yml                    # 测试工作流程
│   └── maintenance.yml                     # 维护工作流程
```

### 5. 使用方法

#### Windows环境：
```cmd
# 使用通用启动脚本
build-qt6-arm-all.cmd 6.9.1 13.2.0 release static false aarch64

# 或直接使用具体脚本
build-qt6-arm64_aarch64_gcc.cmd 6.9.1 13.2.0 release static false aarch64
build-qt6-arm32_armv7l_gcc.cmd 6.9.1 13.2.0 release static false armv7l
```

#### Linux环境：
```bash
# 设置可执行权限
chmod +x Qt6Build/*.sh

# 运行构建
./build-qt6-arm64_aarch64_gcc.sh 6.9.1 13.2.0 release static false aarch64

# 调试配置问题
./debug-qt6-arm-config.sh 6.9.1 aarch64
```

### 6. GitHub Actions触发

#### 手动触发：
- 进入Actions页面
- 选择"Build Qt6 ARM Cross-Compilation"
- 设置参数并运行

#### 自动触发：
- 推送ARM相关脚本更改
- 每周日定期构建最新Qt版本

### 7. 故障排除

如果遇到问题，请按以下步骤排查：

1. **检查Host Qt**:
   ```bash
   ls -la /opt/QtBuild/Qt/6.9.1-host/bin/qmake
   /opt/QtBuild/Qt/6.9.1-host/bin/qmake -query QT_VERSION
   ```

2. **运行调试脚本**:
   ```bash
   ./debug-qt6-arm-config.sh 6.9.1 aarch64
   ```

3. **查看详细日志**:
   - 检查configure输出
   - 查看config.log文件
   - 验证交叉编译工具链

4. **参考文档**:
   - `TROUBLESHOOTING.md` - 常见问题解决
   - `ARM_CROSS_COMPILE_README.md` - 完整使用指南

### 8. 支持的设备

- **AArch64**: 树莓派4+, NVIDIA Jetson系列, 现代ARM开发板
- **ARMv7L**: 树莓派2/3, BeagleBone Black, 32位ARM工控机
- **ARMv6L**: 树莓派1, 旧版ARM设备

### 9. 预期构建结果

成功构建后会生成：
```
/opt/QtBuild/Qt/6.9.1-static/arm_gcc13_2_0_aarch64/
├── bin/           # Qt工具
├── lib/           # Qt库文件
├── include/       # 头文件
├── plugins/       # 插件
└── qt.conf        # 配置文件
```

可直接复制到目标ARM设备使用。

### 10. 后续计划

- 支持更多ARM架构变种
- 添加Qt6的GUI和Widgets支持选项
- 优化构建时间和产物大小
- 支持动态库构建
- 添加自动化测试用例

---

**注意**: 确保有足够的磁盘空间（推荐20GB+）和内存（推荐8GB+）进行构建。构建时间取决于硬件配置，通常需要1-3小时。
