# MPID 与 DMFF 能量对齐及原生 CUDA 色散开发指南

## 1. 核心上下文 (Context)
本项目旨在将 DMFF 生成的力场参数导入 OpenMM MPID 插件，并实现原生的 CUDA 色散 PME 计算。
- **参考体系**: 512个水分子的 NPT 初始构型 (`02molL_init.pdb`)。
- **参考总能**: -10599.50 kJ/mol。
- **色散基准**: -41505.69 kJ/mol (已通过 Bridge 模式 100% 对齐)。

## 2. 关键开发经验 (Lessons Learned)

### A. 内存与 ABI 安全
- **严禁整文件替换**: 从主项目复制 `MPIDForce.h` 等文件会导致严重的内存崩溃。
- **增量开发**: 必须在现有稳定版基础上，外科手术式地添加色散成员变量和接口。

### B. 数据填充协议
- **四极矩布局**: 必须遵循 `[qxx, qxy, qyy, qxz, qyz, qzz]`，且迹 (Trace) 必须为 0。
- **共价图谱**: 必须通过 `setCovalentMap` 显式排除 1-2/1-3 作用，否则能量爆炸。
- **缩放因子**: DMFF 默认全屏（1-2 到 1-6 均为 0.0），仅计算长程贡献。

## 3. 待解决的难题 (Blockers)
- **静电/极化偏差**: 仍有约 6000 kJ/mol 的偏差。怀疑点：
    1. **Local Frame**: MPID 插件的 `Bisector` 轴向定义与 DMFF 可能存在向量归一化顺序的差异。
    2. **PME Alpha**: 自动计算的 Ewald alpha 值可能与 DMFF 内部使用的值不一致。

## 4. 已完成任务 (Completed)

### 4.1 原生色散 PME C++ API (✅ Done)
在 `MPIDForce.h` / `MPIDForce.cpp` 中添加了完整的色散参数接口：
- **`DispersionInfo`** 内部类: 存储每粒子 `c6`, `c8`, `c10` 参数
- **系统级参数**: `useDispersionPme`, `dispersionPmax`, `alphaDisp`, `dnx/dny/dnz`, `dispMScales[5]`
- **公共方法**: `get/setDispersionParameters`, `get/setUseDispersionPME`, `get/setDPMEParameters`, `get/setDispersionPmax`, `get/setDispMScales`
- CUDA 内核 (`MPIDCudaKernels.cpp`) 中已有的色散 PME 代码 (`pmeSpreadDispersionKernel` 等) 现在可以通过这些公共 API 正确调用

### 4.2 序列化支持 (✅ Done)
`MPIDForceProxy.cpp` 版本升级至 v2:
- 序列化: 系统级色散属性 + 每粒子 `<Dispersion C6/C8/C10>` 子节点
- 反序列化: `version >= 2` 条件守护，向后兼容 v1 格式

### 4.3 SWIG Python 绑定 (✅ Done)
`mpidplugin.i` 新增所有色散方法的 SWIG 声明，含 `%apply OUTPUT` 类型映射。

### 4.4 Python XML 解析器 (✅ Done)
支持两种 XML 格式：
1. **内联格式**: `<Multipole ... C6="..." C8="..." C10="...">` + `<MPIDForce useDispersionPME="true">`
2. **DMFF 兄弟格式**: `<ADMPDispPmeForce>` 作为 `<MPIDForce>` 的同级元素，自动合并到同一 force
3. **`class` 属性兼容**: 解析器现在同时支持 `type="380"` 和 `class="380"` 属性匹配

## 5. 后续任务栈 (Backlog)
1. **[静电对齐]**: 解决 ~6000 kJ/mol 的静电/极化偏差（Local Frame / PME Alpha）
2. **[CUDA 验证]**: 在 CUDA 平台上端到端验证色散 PME（需要 GPU 环境）
3. **[Reference 平台]**: Reference 平台尚无色散 PME 实现（仅 CUDA 有）
4. **[Reference 测试]**: `TestReferenceMPIDForce` 第 1394 行有预存失败，与色散无关
