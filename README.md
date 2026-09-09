# RTL Namespace Manager

多项目 RTL 集成中的 module 命名空间生成工具。通过生成项目专属 RTL 副本并同步更新实例化引用，解决多个项目中同名 module 的编译冲突。原始 RTL 不会被修改。

## 核心 Features

### 1. 多项目命名空间

同一份通用 RTL 可以供多个项目使用，生成时分别加上配置的 namespace：

```text
fifo → PROJA__fifo
fifo → PROJB__fifo

PROJA__ctrl 实例化 PROJA__fifo
PROJB__ctrl 实例化 PROJB__fifo
```

自动生成名称使用双下划线 `__`。配置中的项目名称和 namespace 可以分别指定。

### 2. 递归扫描，项目输出平铺

递归扫描源目录中的 `.v`、`.sv`、`.vh`、`.svh` 文件。无论源文件有多少层子目录，项目生成结果都直接放在 `<输出目录>/<namespace>/` 下。

```text
src/ip/deep/fifo.v  → build/all/PROJA/PROJA__fifo.v
src/control/ctrl.v → build/all/PROJA/PROJA__ctrl.v
```

支持多个扫描根目录；默认跳过隐藏子目录和名为 `build` 的子目录。平铺后若不同源文件产生相同输出路径，工具会报错并列出来源，避免覆盖。

### 3. 单 module 与多 module 文件命名

| 文件类型 | 生成文件名示例 | 内容处理 |
| --- | --- | --- |
| 单个 module `fifo` | `PROJA__fifo.v` | 改写 module 声明和实例化引用 |
| `bundle.v` 内有多个 module | `PROJA__bundle.v` | 所有 module 分别改名，文件不拆分 |
| 已有 `PROJA_fifo.v` | `PROJA_fifo.v` | 保留已有项目专用实现 |
| 无 module 的 `rtl_defs.v` / `.vh` | 保留原文件名 | 宏定义不作命名空间替换 |

多 module 文件使用 namespace 加原文件名，不再出现生成文件缺少项目名前缀的问题。文件内多个 module 在 `module_map.json` 中各有记录，指向同一个生成文件。

### 4. 项目专用 RTL 优先

识别与已配置 namespace 匹配的 `<PROJECT>_<module>` 和 `<PROJECT>__<module>` 文件名。

同一源目录存在 `fifo.v` 与 `PROJA_fifo.v` 时：

- PROJA 使用已有 `PROJA_fifo.v`，不再从 `fifo.v` 生成另一份 PROJA 实现。
- PROJA 其他生成 RTL 中对 `fifo` 的实例化改为引用 `PROJA_fifo`。
- PROJB 继续从通用 `fifo.v` 生成 `PROJB__fifo.v`。
- PROJA 专用文件不会复制到 PROJB 中，也不会重复添加 namespace。

专用文件须声明与文件名对应的 module，例如 `PROJA_fifo.v` 声明 `module PROJA_fifo`。覆盖匹配限定在同一源根和相对目录；同名通用 module 位于其他目录时会报冲突。专用文件内部不作重写，其依赖需要使用已有的有效 module 名称。

### 5. 全局共享 module

通过 `common_modules` 指定所有项目共享的 module：声明和实例化引用保留原名称，文件仅生成一份。

共享文件保持 `common/<源相对目录>/` 结构，不适用项目目录的平铺规则。工具会检查共享 module 是否存在、是否重复声明，以及一个文件是否混合了共享与非共享 module。共享文件引用非共享 module 时会给出警告。

### 6. Token 级 RTL 重写

识别 `module` / `macromodule` 声明，以及普通、参数化和数组形式的 module 实例化。注释、字符串、信号名（如 `fifo_data`）、实例名（如 `u_fifo`）、参数及宏定义体不作简单字符串替换。

### 7. 生成清单与可追溯映射

```text
build/all/
├── PROJA/
│   ├── PROJA__ctrl.v
│   ├── PROJA__bundle.v
│   └── PROJA_fifo.v
├── PROJB/
│   ├── PROJB__ctrl.v
│   ├── PROJB__bundle.v
│   └── PROJB__fifo.v
├── common/rtl/shared.v
├── module_map.json
└── filelist.f
```

`module_map.json` 记录原 module 名、新名称、源文件、声明行号、生成文件路径和 namespace。`filelist.f` 列出生成文件，路径相对于工具执行时的工作目录，可供 VCS、Xcelium 或 Icarus Verilog 的文件列表参数使用；实际设计仍需配置外部依赖、include 路径和编译选项。

### 8. 校验、预览与可配置调用

生成前检查重复 module、namespace 冲突、共享 module 配置及输出路径冲突。`--check` 只校验输入与生成计划，`--dry-run` 显示改名计划，两者都不写入结果。

在项目根目录运行：

```bash
make namespace_dryrun
make namespace_check
make namespace

# 自定义扫描根目录、输出目录和配置文件
make namespace RTL_SRC=rtl,ip/rtl \
  NAMESPACE_OUT=out/rtl_namespace \
  NAMESPACE_CONFIG=config/namespace.yaml

# 不覆盖 YAML 中各项目的 source 配置
make namespace RTL_SRC=
```

| Makefile 变量 | 默认值 | 用途 |
| --- | --- | --- |
| `RTL_SRC` | `src` | 递归扫描根目录；多个目录用逗号分隔，覆盖所有项目的 source |
| `NAMESPACE_OUT` | `build/all` | 专用生成目录 |
| `NAMESPACE_CONFIG` | `config/namespace.yaml` | 项目配置文件 |
| `NAMESPACE_TOOL` | `tools/rtl_namespace.py` | 核心脚本路径 |

每次生成会清空并重建输出目录，以移除旧结果。输出目录只能用于存放可重新生成的文件，不要设为源目录或项目根目录。可选 `--header` 为普通生成文件添加来源说明；已有项目专用文件不添加该说明。

## 配置示例

```yaml
projects:
  PROJA:
    source: [src]
    namespace: PROJA
  PROJB:
    source: [src]
    namespace: PROJB

# 没有共享模块时保留空列表；需要共享时填写实际 module 名称。
common_modules: []
```

配置中的相对源路径按命令执行目录解析。当前仓库示例配置包含 `AOU_RX_CORE`，迁移时应按实际设计调整。

## 迁移到实际项目

复制 `tools/rtl_namespace.py`、`config/namespace.yaml`，并将 Makefile 的 namespace 相关变量和目标合并进实际项目。保留 `LICENSE`；将自定义生成目录加入 `.gitignore`。

运行依赖为 Python 3.9+、PyYAML 和 GNU Make（使用 Makefile 时）。无需复制本仓库的 `src/` 示例或 `build/` 生成结果；回归测试脚本和测试样例可按需保留。

## 测试

```bash
make namespace && make verify       # 当前仓库 demo 验收
make verify_overrides               # 递归扫描与项目专用覆盖
python3 scripts/verify_nomodule.py   # 无 module 的宏定义文件
make verify_flat                    # 平铺、多 module 文件名及冲突保护
bash scripts/run_p1.sh              # demo 全流程、源文件哈希及编译冒烟
```

编译验证使用 Icarus Verilog（`iverilog`）；平铺回归脚本在检测到该工具时执行编译测试。`make sim` 先生成 RTL，再调用 VCS。demo 验收只覆盖示例设计，不等同于完整实际项目的编译验证。

## 当前边界

- 尚未实现 interface、package、bind、checker 命名空间，以及完整 AST、复杂宏和 generate 语义分析。
- 尚未自动解析跨项目依赖图或修复依赖关系。
- 不改写字面量 `include` 路径。源代码引用子目录时，平铺输出后的 include 路径或编译搜索配置需要相应调整。
- `--diff` / `make namespace_diff` 目前仅保留入口，尚无实际差异报告逻辑；调用它仍会执行生成。

## License

[MIT](LICENSE)
