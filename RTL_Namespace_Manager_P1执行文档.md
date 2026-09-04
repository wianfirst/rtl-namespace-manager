# P1 执行文档：RTL Namespace Generator

## 1. P1 目标

P1 的目标是先解决当前最核心的问题：

> 多个 Project 存在同名 RTL module，ALL 版本需要同时集成这些 RTL；脚本自动给 module 加 Project namespace，并自动修改实例化引用。

例如：

```text
PROJA:
    fifo -> PROJA__fifo
    ctrl -> PROJA__ctrl

PROJB:
    fifo -> PROJB__fifo
    ctrl -> PROJB__ctrl
```

原始 Perforce RTL 不修改、不提交。

---

## 2. P1 范围

### 支持

- module declaration
- 普通 module instantiation
- parameterized instantiation
- module array instantiation
- Project namespace
- duplicate module 检查
- module map
- generated filelist
- dry-run
- check
- generated RTL 输出到 build directory

### 暂不支持

以下功能放到 P2：

- interface namespace
- package namespace
- bind
- 复杂 macro
- 完整 generate 语义
- 完整 SystemVerilog AST
- 复杂跨 Project dependency
- Perforce changelist 自动锁定
- cache
- CI

---

## 3. 推荐目录

```text
chip_project/
├── config/
│   └── namespace.yaml
│
├── tools/
│   └── rtl_namespace.py
│
├── src/
│   ├── PROJA/
│   │   └── rtl/
│   │       ├── fifo.sv
│   │       └── ctrl.sv
│   │
│   └── PROJB/
│       └── rtl/
│           ├── fifo.sv
│           └── ctrl.sv
│
└── build/
    └── all/
```

---

## 4. 安装依赖

需要 Python 和 PyYAML。

```bash
python --version
```

建议 Python >= 3.9。

安装：

```bash
pip install pyyaml
```

Linux 环境可以：

```bash
python3 --version
python3 -m pip install pyyaml
```

---

## 5. 创建 namespace.yaml

文件：

```text
config/namespace.yaml
```

内容：

```yaml
projects:

  PROJA:
    source:
      - src/PROJA
    namespace: PROJA

  PROJB:
    source:
      - src/PROJB
    namespace: PROJB
```

以后增加 Project：

```yaml
  PROJC:
    source:
      - src/PROJC
    namespace: PROJC
```

---

## 6. P1 工具文件

文件：

```text
tools/rtl_namespace.py
```

工具需要完成：

```text
读取配置
    ↓
扫描 RTL
    ↓
建立 module database
    ↓
建立 namespace map
    ↓
rewrite module declaration
    ↓
rewrite module instantiation
    ↓
生成 RTL
    ↓
生成 module_map.json
    ↓
生成 filelist.f
    ↓
validation
```

核心 rename：

```text
fifo
  ↓
PROJA__fifo
```

但不能执行：

```python
text.replace("fifo", "PROJA__fifo")
```

必须基于 token/语法识别 module symbol。

---

## 7. 最小测试用例

### PROJA/fifo.sv

```systemverilog
module fifo #(
    parameter WIDTH = 32
)(
    input  logic             clk,
    input  logic             rst_n,
    input  logic [WIDTH-1:0] din,
    output logic [WIDTH-1:0] dout
);

    assign dout = din;

endmodule
```

### PROJA/ctrl.sv

```systemverilog
module ctrl (
    input logic clk,
    input logic rst_n
);

    fifo #(
        .WIDTH(32)
    ) u_fifo (
        .clk   (clk),
        .rst_n (rst_n),
        .din   ('0),
        .dout  ()
    );

endmodule
```

### PROJB/fifo.sv

```systemverilog
module fifo #(
    parameter WIDTH = 64
)(
    input  logic             clk,
    input  logic             rst_n,
    input  logic [WIDTH-1:0] din,
    output logic [WIDTH-1:0] dout
);

    assign dout = din;

endmodule
```

### PROJB/ctrl.sv

```systemverilog
module ctrl (
    input logic clk,
    input logic rst_n
);

    fifo #(
        .WIDTH(64)
    ) u_fifo (
        .clk   (clk),
        .rst_n (rst_n),
        .din   ('0),
        .dout  ()
    );

endmodule
```

---

## 8. 第一步：Dry Run

先不要生成文件：

```bash
python tools/rtl_namespace.py \
    --config config/namespace.yaml \
    --out build/all \
    --dry-run
```

预期看到：

```text
[INFO] Projects:
    PROJA: src/PROJA
    PROJB: src/PROJB

[INFO] Scanning RTL...

[INFO] Found 4 modules

[INFO] Module namespace:
    PROJA: ctrl -> PROJA__ctrl
    PROJA: fifo -> PROJA__fifo
    PROJB: ctrl -> PROJB__ctrl
    PROJB: fifo -> PROJB__fifo
```

并显示实际修改位置。

---

## 9. 第二步：正式生成

执行：

```bash
python tools/rtl_namespace.py \
    --config config/namespace.yaml \
    --out build/all
```

预期目录：

```text
build/all/
├── PROJA/
│   └── rtl/
│       ├── PROJA__fifo.sv
│       └── PROJA__ctrl.sv
│
├── PROJB/
│   └── rtl/
│       ├── PROJB__fifo.sv
│       └── PROJB__ctrl.sv
│
├── module_map.json
└── filelist.f
```

---

## 10. 检查生成结果

### PROJA fifo

应该从：

```systemverilog
module fifo
```

变成：

```systemverilog
module PROJA__fifo
```

### PROJA ctrl

应该从：

```systemverilog
fifo u_fifo
```

变成：

```systemverilog
PROJA__fifo u_fifo
```

### PROJB fifo

应该：

```systemverilog
module PROJB__fifo
```

### PROJB ctrl

应该：

```systemverilog
PROJB__fifo u_fifo
```

---

## 11. 特别检查不能被修改的内容

以下内容必须保持原样：

### Instance name

```text
u_fifo
```

### Signal name

```text
fifo_data
```

### Parameter

```text
WIDTH
```

### Parameter value

```text
32
64
```

### Port

```text
.clk
.rst_n
.din
.dout
```

### Comments

注释中的：

```text
fifo
```

不应该被修改。

### String

字符串中的：

```text
"fifo"
```

不应该被修改。

---

## 12. module_map.json

生成：

```json
{
  "PROJA": {
    "fifo": {
      "new_name": "PROJA__fifo",
      "source": "src/PROJA/rtl/fifo.sv",
      "line": 1
    }
  },
  "PROJB": {
    "fifo": {
      "new_name": "PROJB__fifo",
      "source": "src/PROJB/rtl/fifo.sv",
      "line": 1
    }
  }
}
```

用途：

```text
PROJA__fifo
    ↓
PROJA
    ↓
fifo
    ↓
source file
```

---

## 13. filelist.f

生成：

```text
build/all/PROJA/rtl/PROJA__ctrl.sv
build/all/PROJA/rtl/PROJA__fifo.sv
build/all/PROJB/rtl/PROJB__ctrl.sv
build/all/PROJB/rtl/PROJB__fifo.sv
```

之后 VCS：

```bash
vcs -f build/all/filelist.f
```

或者 Xcelium：

```bash
xrun -f build/all/filelist.f
```

---

## 14. Check 模式

执行：

```bash
python tools/rtl_namespace.py \
    --config config/namespace.yaml \
    --out build/all \
    --check
```

用途：

```text
不生成 RTL
只检查：
    module duplicate
    namespace collision
    基础配置错误
```

成功：

```text
[PASS] RTL namespace check passed.
```

---

## 15. Makefile 接入

建议加入：

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

以后：

```bash
make namespace
```

即可生成。

---

## 16. P1 验收测试

### Test 1：同名 module

输入：

```text
PROJA/fifo
PROJB/fifo
```

输出：

```text
PROJA__fifo
PROJB__fifo
```

必须同时存在。

---

### Test 2：module declaration

输入：

```systemverilog
module fifo;
```

输出：

```systemverilog
module PROJA__fifo;
```

---

### Test 3：普通 instantiation

输入：

```systemverilog
fifo u_fifo (...);
```

输出：

```systemverilog
PROJA__fifo u_fifo (...);
```

---

### Test 4：parameterized instantiation

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

---

### Test 5：instance name

输入：

```text
u_fifo
```

输出：

```text
u_fifo
```

不能变化。

---

### Test 6：signal name

输入：

```systemverilog
logic fifo_data;
```

输出仍然：

```systemverilog
logic fifo_data;
```

不能变成：

```systemverilog
logic PROJA__fifo_data;
```

---

### Test 7：原始 RTL

Perforce source：

```systemverilog
module fifo;
```

运行 P1 后仍必须：

```systemverilog
module fifo;
```

---

### Test 8：compile

最终：

```bash
vcs -f build/all/filelist.f
```

必须通过编译。

---

## 17. P1 完成后的工作流

最终日常工作：

```text
p4 sync
   |
   v
Original RTL
   |
   v
make namespace
   |
   v
build/all
   |
   +--> PROJA__xxx
   |
   +--> PROJB__xxx
   |
   +--> PROJC__xxx
   |
   v
filelist.f
   |
   v
VCS/Xcelium
```

---

## 18. P1 到 P2 的升级点

P1 验证通过后，再增加：

```text
interface
package
bind
checker
macro
generate
dependency graph
cross-project dependency
```

最终升级成：

```text
RTL Namespace Manager
        |
        +-- Scanner
        +-- Lexer
        +-- Parser
        +-- Symbol DB
        +-- Namespace Engine
        +-- Dependency Graph
        +-- Rewriter
        +-- Validator
        +-- Cache
        +-- Perforce Integration
        +-- Release Manifest
```

---

## 19. P1 最终判断标准

如果以下命令：

```bash
make namespace
```

能够稳定完成：

```text
PROJA/fifo
    ->
PROJA__fifo

PROJB/fifo
    ->
PROJB__fifo
```

并且：

```text
PROJA__ctrl -> PROJA__fifo
PROJB__ctrl -> PROJB__fifo
```

同时：

```text
原始 RTL 不变
signal 不变
instance 不变
parameter 不变
```

且：

```bash
vcs -f build/all/filelist.f
```

能够编译，那么 P1 即完成。
