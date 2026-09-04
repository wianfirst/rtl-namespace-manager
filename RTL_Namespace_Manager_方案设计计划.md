# RTL Namespace Manager 方案设计计划

## 1. 项目背景

当前项目通过 Perforce 管理多个 Project/版本的 RTL。不同 Project 中可能存在同名 RTL module，例如：

- PROJA/rtl/fifo.sv -> `module fifo`
- PROJB/rtl/fifo.sv -> `module fifo`

在普通 Project 中，这种情况没有问题，因为每个 Project 独立编译；但特殊的 ALL/Integration 版本需要同时消费多个 Project 的 RTL，此时同名 module 会产生编译冲突。

目标是建立一套 **RTL Namespace Manager**：

> 保留 Perforce 中原始 RTL 不变，在 ALL/Integration 构建阶段自动生成带 Project Namespace 的 RTL，并同步修改 module instantiation/reference。

例如：

```text
PROJA:
    fifo -> PROJA__fifo
    ctrl -> PROJA__ctrl

PROJB:
    fifo -> PROJB__fifo
    ctrl -> PROJB__ctrl
```

最终两个 Project 可以在同一个 VCS/Xcelium 编译环境中共存。

---

## 2. 总体架构

```text
                    Perforce
                       |
             +---------+---------+
             |         |         |
           PROJA     PROJB     PROJC
             |         |         |
             +---------+---------+
                       |
                 RTL Scanner
                       |
                Symbol Database
                       |
          +------------+------------+
          |                         |
    Namespace Engine         Dependency Graph
          |                         |
          +------------+------------+
                       |
                  RTL Rewriter
                       |
          +------------+------------+
          |            |            |
      PROJA__xxx   PROJB__xxx   PROJC__xxx
          |            |            |
          +------------+------------+
                       |
                    ALL RTL
                       |
                filelist.f / VCS
```

整体分成四层：

```text
Version Layer
    V1.0 / V2.0 / LATEST

Integration Layer
    Project A + Project B + Project C + Common

Namespace Layer
    PROJA__xxx / PROJB__xxx / PROJC__xxx

Source Layer
    Perforce Original RTL
```

---

## 3. 核心设计原则

### 3.1 不修改 Perforce 原始 RTL

原始 RTL：

```systemverilog
module fifo (...);
```

保持不变。

生成 RTL：

```systemverilog
module PROJA__fifo (...);
```

生成文件只存在于 build workspace，例如：

```text
build/all/PROJA/
```

不允许把 generated RTL 提交回 Perforce。

---

### 3.2 Namespace 命名规则

推荐：

```text
<PROJECT>__<MODULE>
```

例如：

```text
PROJA__fifo
PROJA__ctrl
PROJA__arb

PROJB__fifo
PROJB__ctrl
PROJB__arb
```

使用双下划线 `__` 的原因：

1. 清晰区分 namespace 和原始 module name
2. 降低与原始命名冲突概率
3. waveform/debug 时容易识别模块归属
4. 方便脚本反向解析

---

## 4. Namespace 策略

并不是所有 RTL 都应该按照 Project 进行 rename。

例如：

```text
PROJA/fifo
PROJB/fifo
COMMON/reset_sync
```

推荐生成：

```text
PROJA__fifo
PROJB__fifo
COMMON__reset_sync
```

如果某个模块是所有 Project 共享的公共 RTL，应定义为 COMMON，而不是分别生成：

```text
PROJA__reset_sync
PROJB__reset_sync
```

需要建立明确的 Namespace Policy。

---

## 5. 配置文件设计

推荐：

```text
config/namespace.yaml
```

示例：

```yaml
projects:

  PROJA:
    source:
      - src/PROJA
    namespace: PROJA
    rename:
      module: true
      interface: true
      package: false
      checker: true
    exclude:
      - common/**

  PROJB:
    source:
      - src/PROJB
    namespace: PROJB
    rename:
      module: true
      interface: true
      package: false
      checker: true
    exclude:
      - common/**

common:
  namespace: COMMON
```

配置文件负责决定：

- Project
- RTL source
- namespace
- module 是否 rename
- interface 是否 rename
- package 是否 rename
- checker 是否 rename
- exclude 路径
- Common RTL

---

## 6. Symbol Database

工具需要首先扫描所有 RTL，建立 Symbol Database。

建议保存：

```text
modules
interfaces
packages
checkers
```

Module 数据：

```python
@dataclass
class ModuleInfo:
    original_name: str
    generated_name: str
    owner: str
    source_file: str
    line: int
    namespace: str
```

例如：

```text
fifo
    type      = module
    owner     = PROJA
    namespace = PROJA
    generated = PROJA__fifo
```

如果存在两个 fifo：

```text
fifo
    PROJA -> PROJA__fifo
    PROJB -> PROJB__fifo
```

---

## 7. Dependency Graph

必须解决一个核心问题：

同一个 `fifo` 在不同 Project 中，到底应该引用哪一个？

例如：

```text
PROJA__ctrl
    |
    +--> PROJA__fifo
```

而：

```text
PROJB__ctrl
    |
    +--> PROJB__fifo
```

如果：

```text
PROJA__ctrl
    |
    +--> COMMON__reset_sync
```

则应该使用 Common namespace。

因此不能简单进行全局：

```text
fifo -> PROJA__fifo
```

而应该基于：

```text
owner/project
dependency
namespace policy
```

进行解析。

---

## 8. RTL Rewriter

### 8.1 Module declaration

输入：

```systemverilog
module fifo (...);
```

输出：

```systemverilog
module PROJA__fifo (...);
```

### 8.2 普通 instantiation

输入：

```systemverilog
fifo u_fifo (...);
```

输出：

```systemverilog
PROJA__fifo u_fifo (...);
```

### 8.3 Parameterized instantiation

输入：

```systemverilog
fifo #(
    .WIDTH(32)
) u_fifo (...);
```

输出：

```systemverilog
PROJA__fifo #(
    .WIDTH(32)
) u_fifo (...);
```

### 8.4 Array instantiation

输入：

```systemverilog
fifo u_fifo [3:0] (...);
```

输出：

```systemverilog
PROJA__fifo u_fifo [3:0] (...);
```

### 8.5 bind

需要支持：

```systemverilog
bind fifo fifo_assert u_assert (...);
```

转换为：

```systemverilog
bind PROJA__fifo fifo_assert u_assert (...);
```

---

## 9. 不允许简单字符串替换

不能采用：

```python
text.replace("fifo", "PROJA__fifo")
```

因为会误修改：

```text
signal_fifo
fifo_data
comment
string
macro
parameter
```

例如：

```systemverilog
logic fifo_data;
```

不应该变成：

```systemverilog
logic PROJA__fifo_data;
```

因此需要：

```text
Lexer
  ->
Token
  ->
Symbol identification
  ->
AST/语法上下文
  ->
Rewrite
```

---

## 10. Macro 处理策略

复杂情况下可能出现：

```systemverilog
`define FIFO_MODULE fifo

`FIFO_MODULE u_fifo (...);
```

或者：

```systemverilog
`ifdef PROJECT_A
fifo u_fifo (...);
`endif
```

Macro 不能进行简单的全局替换。

建议分三级：

### Level 1：自动处理

明确语法结构：

- module declaration
- 普通 module instantiation
- parameterized instantiation
- array instantiation

### Level 2：自动处理 + warning

例如：

- generate
- macro
- conditional compilation
- 特殊 SystemVerilog construct

### Level 3：无法可靠判断

直接报错：

```text
[ERROR] Ambiguous module reference
```

禁止生成不确定的 RTL。

---

## 11. Package 策略

Package 特别容易发生命名冲突。

例如：

```systemverilog
package common_pkg;
```

两个 Project 都有：

```text
common_pkg
```

不能默认全部 rename。

建议：

```yaml
package: false
```

如果两个 package 实际上不同，则配置：

```yaml
package: true
```

生成：

```text
PROJA__common_pkg
PROJB__common_pkg
```

并同步：

```systemverilog
import common_pkg::*;
```

修改为：

```systemverilog
import PROJA__common_pkg::*;
```

---

## 12. 生成文件

每次 ALL build 生成：

```text
build/all/
├── PROJA/
├── PROJB/
├── PROJC/
├── module_map.json
├── source_manifest.json
├── dependency_graph.json
├── namespace_report.txt
└── filelist.f
```

---

## 13. module_map.json

示例：

```json
{
  "PROJA": {
    "fifo": {
      "new_name": "PROJA__fifo",
      "source": "//depot/PROJA/main/rtl/fifo.sv",
      "line": 12
    }
  },
  "PROJB": {
    "fifo": {
      "new_name": "PROJB__fifo",
      "source": "//depot/PROJB/main/rtl/fifo.sv",
      "line": 15
    }
  }
}
```

用途：

```text
generated RTL
    ↓
original module
    ↓
Project
    ↓
Perforce depot path
    ↓
Perforce changelist
```

保证 debug/release 可追溯。

---

## 14. source_manifest.json

建议保存：

```json
{
  "project": "PROJA",
  "source": "//depot/PROJA/main/rtl/fifo.sv",
  "changelist": 182736,
  "generated": "PROJA__fifo",
  "tool_version": "1.0"
}
```

这样能够保证 ALL Release 可复现。

---

## 15. Perforce 集成

推荐工作流：

```text
p4 sync
    |
    v
Perforce Workspace
    |
    v
RTL Namespace Generator
    |
    v
build/all
    |
    v
VCS / Xcelium
```

不要将 namespace generation 放在 Perforce source tree 中修改文件。

---

## 16. ALL-LATEST 和 ALL-RELEASE

### ALL-LATEST

用于：

- 日常开发
- nightly regression
- integration

每个 Project 使用最新 Perforce 内容。

### ALL-RELEASE

用于：

- release
- signoff
- reproducibility

例如：

```yaml
release: V1.0

projects:
  PROJA:
    changelist: 100

  PROJB:
    changelist: 250

  PROJC:
    changelist: 310
```

因此：

```text
ALL-V1.0
ALL-V2.0
ALL-V3.0
```

都可以准确复现。

---

## 17. Makefile 集成

推荐：

```makefile
NAMESPACE_CONFIG := config/namespace.yaml
NAMESPACE_OUT    := build/all
NAMESPACE_TOOL   := tools/rtl_namespace.py

namespace:
	python3 $(NAMESPACE_TOOL) \
		--config $(NAMESPACE_CONFIG) \
		--out $(NAMESPACE_OUT)

namespace_check:
	python3 $(NAMESPACE_TOOL) \
		--config $(NAMESPACE_CONFIG) \
		--out $(NAMESPACE_OUT) \
		--check

namespace_dryrun:
	python3 $(NAMESPACE_TOOL) \
		--config $(NAMESPACE_CONFIG) \
		--out $(NAMESPACE_OUT) \
		--dry-run

sim: namespace
	vcs -f $(NAMESPACE_OUT)/filelist.f
```

---

## 18. CLI 设计

建议：

```bash
python rtl_namespace.py \
    --config config/namespace.yaml \
    --out build/all
```

Dry run：

```bash
python rtl_namespace.py \
    --config config/namespace.yaml \
    --out build/all \
    --dry-run
```

Check：

```bash
python rtl_namespace.py \
    --config config/namespace.yaml \
    --out build/all \
    --check
```

Diff：

```bash
python rtl_namespace.py \
    --config config/namespace.yaml \
    --out build/all \
    --diff
```

---

## 19. Validation

生成后至少检查：

### Duplicate module

```text
Duplicate generated module
```

### Duplicate interface

```text
Duplicate interface
```

### Duplicate package

```text
Duplicate package
```

### Unresolved reference

```text
Unresolved module reference
```

### Namespace collision

```text
Namespace collision
```

### Cross-project dependency violation

```text
Illegal cross-project dependency
```

### Macro ambiguity

```text
Ambiguous module reference inside macro
```

最后必须经过：

```text
Namespace validation
        +
VCS/Xcelium compile
```

两层验证。

---

## 20. Cache 机制

大型芯片项目可能有几千甚至上万 RTL 文件，因此需要缓存。

Cache key 可以由：

```text
source file hash
+
namespace
+
namespace config version
+
tool version
```

组成。

例如：

```text
fifo.sv
MD5=ABC123
namespace=PROJA
tool_version=1.0
```

如果内容没变：

```text
CACHE HIT
```

不再重复生成。

---

## 21. 推荐代码结构

```text
chip_project/
├── config/
│   ├── namespace.yaml
│   ├── project.yaml
│   └── release/
│       ├── V1.0.yaml
│       └── V2.0.yaml
│
├── tools/
│   └── rtl_namespace/
│       ├── main.py
│       ├── config.py
│       ├── scanner.py
│       ├── lexer.py
│       ├── parser.py
│       ├── database.py
│       ├── namespace.py
│       ├── dependency.py
│       ├── renamer.py
│       ├── rewriter.py
│       ├── validator.py
│       ├── reporter.py
│       └── cache.py
│
├── src/
│   ├── PROJA/
│   ├── PROJB/
│   └── PROJC/
│
├── build/
│   └── all/
│
├── filelist/
└── Makefile
```

---

## 22. 开发阶段规划

### P1：核心功能

目标：解决 80% 的当前问题。

实现：

- RTL scan
- module database
- namespace map
- module declaration rename
- module instantiation rename
- parameterized instantiation
- array instantiation
- duplicate check
- basic unresolved reference check
- module_map.json
- filelist.f
- dry-run
- check

### P2：SystemVerilog 完整支持

增加：

- interface
- package
- bind
- checker
- generate
- macro
- conditional compilation
- dependency graph
- cross-project dependency analysis

### P3：工程集成

增加：

- Perforce
- changelist pinning
- ALL-LATEST
- ALL-RELEASE
- Makefile
- VCS
- Xcelium
- CI

### P4：规模化

增加：

- incremental build
- cache
- parallel generation
- dependency graph visualization
- release manifest
- regression integration

---

## 23. P1 验收标准

P1 完成后必须满足：

### Case 1：同名 module

```text
PROJA/fifo
PROJB/fifo
```

可以同时编译。

### Case 2：内部引用

```text
PROJA/ctrl -> fifo
```

必须变成：

```text
PROJA__ctrl -> PROJA__fifo
```

### Case 3：另一个 Project

```text
PROJB/ctrl -> fifo
```

必须变成：

```text
PROJB__ctrl -> PROJB__fifo
```

### Case 4：signal name

```text
fifo_data
```

不能变。

### Case 5：instance name

```text
u_fifo
```

不能变。

### Case 6：parameter

```text
.WIDTH(32)
```

不能变。

### Case 7：原始 RTL

Perforce 中：

```systemverilog
module fifo;
```

必须保持不变。

### Case 8：生成结果

必须能够：

```bash
vcs -f build/all/filelist.f
```

完成编译。

---

# 24. 最终目标

最终形成：

```text
                         Perforce
                            |
              +-------------+-------------+
              |             |             |
            PROJA         PROJB         PROJC
              |             |             |
              +-------------+-------------+
                            |
                     Namespace Manager
                            |
            +---------------+---------------+
            |               |               |
        PROJA__xxx      PROJB__xxx      PROJC__xxx
            |               |               |
            +---------------+---------------+
                            |
                           ALL
                            |
                    VCS / Xcelium / Lint
```

核心思想总结：

> **Perforce 负责“代码来自哪里”，Namespace Manager 负责“代码进入 ALL 后叫什么”。**

这样可以避免复制 RTL、避免修改源代码，同时解决多个 Project 同名 module 在 ALL 集成环境中的 namespace collision。
