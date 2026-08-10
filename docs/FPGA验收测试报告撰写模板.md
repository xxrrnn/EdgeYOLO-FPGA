密级：

# 国家重点研发计划项目

## 基于三维堆叠 DRAM 的超高带宽互连工艺

### 课题三“基于 HBM 近存的高性能智能计算架构研究及未来互连工艺预研”

（课题编号：2023YFB4404603）

# 测试报告

［测试完成日期］

---

## 目录

一．课题概述<br>
二．样品信息<br>
三．任务书规定测试项目与考核指标对照<br>
四、测试方法<br>
五、测试仪器设备与环境<br>
六、测试人员、时间<br>
七、测试结果与结论<br>
八、测试原始数据及处理结果

---

# 一．课题概述

本课题开展基于HBM的高性能智能近存计算架构研究及未来互连工艺预研，从国家超算战略应用的角度开展HBM架构研究并对未来互连工艺提出构想，为整体项目提供面向人工智能和高性能计算的系统验证框架和应用参数反馈。其中高性能智能近存计算架构由北京大学承担，未来互连工艺预研由长鑫存储技术有限公司完成。

# 二．样品信息

“基于HBM近存的高性能智能计算架构研究及未来互连工艺预研”课题三顺利进行，目前已完成面向HBM近存架构的AI处理器RTL设计、FPGA原型实现和配套验证软件开发，并完成SRAM存内计算核心引擎在FPGA上的等效功能映射。FPGA原型采用AMD/Xilinx VCU128开发板，板载器件为Virtex UltraScale+ HBM FPGA，具体型号为xcvu37p-fsvh2892-2L-e。

FPGA原型配置1个HBM堆栈，容量为4GB。处理器计算部分由8个DCIM Tile组成，并集成VPU、指令译码器、片上输入输出缓冲区、AXI CDMA以及控制寄存器。系统主时钟频率为250MHz，HBM AXI接口时钟频率为450MHz；主机通过PCIe x8 XDMA接口访问HBM、片上缓冲区、指令存储器和控制寄存器。

当前固定测试样品的发布版本为c1773f6，FPGA烧录文件为`bitstream/edgeyolo_c1773f6_w8a8_w16a16w.bit`。与该硬件样品配套的软件包括完整网络编译器、Windows XDMA运行时、FPGA输出与Golden结果比对程序以及主机端网络后处理程序。当前样品支持YOLOv5n和ResNet18网络，支持INT8和widened INT16两种数据通路。

# 三．任务书规定测试项目与考核指标对照

表 1. 课题任务完成情况

| 课题 | 指标名称 | 中期指标要求 | 验收指标要求 | 完成情况 |
|---|---|---|---|---|
| 课题 3 | 1．面向 HBM 近存架构的 AI 处理器芯片 | 支持单层神经网络 | 支持 ResNet、YOLO 等主流深度神经网络 | ［依据第七章实测结果填写］ |
| 课题 3 | 2．计算精度 | 支持 8bit | 支持 8/16bit | ［依据第七章实测结果填写；16bit 须注明为 widened INT16］ |
| 课题 3 | 3．核心计算引擎峰值能效 | ≥5 TOPS/W@INT8 | ≥10 TOPS/W@INT8 | 本次不测试，不给出测试结论 |
| 课题 3 | 4．处理器峰值算力 | ≥1 TOPS@INT8 | ≥2 TOPS@INT8 | ［依据 VCS/FSDB 实测结果填写］ |

# 四、测试方法

## 1. AI处理器芯片功能（支持ResNet、YOLO等主流深度神经网络）

使用项目顶层目录中的 `run.py` 作为AI处理器FPGA实物测试的统一入口。`run.py` 中的 `run_acceptance_suite` 函数按照数据集清单和计算精度逐项建立测试用例，再调用 `run_one_shot_fpga` 函数完成单张图片的程序下发、FPGA执行、结果读回、Golden比对和主机端网络后处理。FPGA硬件顶层为 `lite_wrapper`，工程采用AMD/Xilinx VCU128开发板和 `xcvu37p-fsvh2892-2L-e` 器件，处理器内部配置8个DCIM Tile，并集成VPU、指令译码器、AXI CDMA、片上输入输出缓冲区、HBM和XDMA主机接口。正式测试前在Vivado Hardware Manager中连接VCU128开发板，选择项目顶层目录 `bitstream` 文件夹下的 `edgeyolo_c1773f6_w8a8_w16a16w.bit` 进行Program Device。烧录完成后重启主机或重新枚举PCIe，在Windows设备管理器中确认XDMA设备正常启动，再使用项目顶层目录 `tests/bin` 文件夹下的 `xdma_info.exe` 检查XDMA通道，使用 `xdma_rw.exe c2h_0 read 0x0 -l 16` 检查C2H读通道是否能够访问。

图1. AI处理器FPGA原型系统结构图

测试输入分别取自项目顶层目录 `examples/coco` 和 `examples/imagenet`。`examples/coco/manifest.json` 记录20张COCO val2017图片，用于YOLOv5n测试；`examples/imagenet/manifest.json` 记录20张ImageNet图片及其synset、类别编号和类别名称，用于ResNet18测试。每张图片分别执行INT8和widened INT16两种数据通路，因此YOLOv5n形成40个用例，ResNet18形成40个用例，共执行80个FPGA实测用例。YOLOv5n使用320×320输入，ResNet18使用224×224输入。

神经网络编译程序位于项目顶层目录 `tests/chip/compiler` 文件夹中，使用 `compile.py` 将解析后的网络和量化参数编译成FPGA可以执行的指令及数据。YOLOv5n INT8编译输入位于 `model/yolov5n_coco50k_qat/parsed_int8`，widened INT16编译输入位于 `model/yolov5n_coco50k_qat/parsed_int16_widened`；ResNet18 INT8编译输入位于 `model/resnet18/parsed_vai`，widened INT16编译输入位于 `model/resnet18/parsed_vai_int16_widened`。每个解析目录中均使用 `network.json` 描述网络结构、输入尺寸、层信息和量化参数，使用 `weights` 文件夹下各层的NPZ文件保存量化权重、激活scale、DQA scale和bias等数据。

在项目顶层目录执行以下命令生成四组正式测试产物：

```text
python tests/chip/compiler/compile.py --network yolov5n --mode int8 --full --parsed model/yolov5n_coco50k_qat/parsed_int8 --out artifacts/c1773f6/yolo_coco_int8
python tests/chip/compiler/compile.py --network yolov5n --mode int16 --full --parsed model/yolov5n_coco50k_qat/parsed_int16_widened --out artifacts/c1773f6/yolo_coco_int16_widened
python tests/chip/compiler/compile.py --network resnet18 --mode int8 --full --parsed model/resnet18/parsed_vai --out artifacts/c1773f6/resnet18_int8
python tests/chip/compiler/compile.py --network resnet18 --mode int16 --full --parsed model/resnet18/parsed_vai_int16_widened --out artifacts/c1773f6/resnet18_int16_widened
```

`compile.py` 首先读取 `tests/chip/compiler/lowering/hw_caps.yaml` 中的硬件约束，并在 `--full` 模式下调用 `compiler/lowering/lower_full.py` 对完整FPGA主体网络进行lowering。该过程把卷积、maxpool、upsample、concat和residual add等网络操作转换为处理器指令序列，完成各层输入输出缓冲区和HBM地址规划。随后使用权重打包程序把各层NPZ中的量化权重写入连续的 `weights.bin`，把scale和bias等数据写入 `wb.bin`，并在执行计划中插入从HBM加载权重的操作。最后使用指令编码程序把执行计划编码为32bit指令，生成 `program.hex` 和小端格式的 `program.bin`。编译目录同时保存 `plan.json`、`weights_layout.json`、`wb_layout.json` 和 `memory_map.md`，分别记录执行计划、权重偏移、scale/bias偏移和存储地址。若指令数量超过单段指令存储空间，编译器按指令存储器容量生成 `program_manifest.json` 和 `program_segments` 文件夹；当前ResNet18 widened INT16程序使用两个程序段，其余三组程序使用一个程序段。

正式测试默认使用项目顶层目录 `artifacts/c1773f6` 中已经固定的四组编译产物，不在测试过程中重新生成网络参数。`run.py` 根据网络和精度自动选择 `yolo_coco_int8`、`yolo_coco_int16_widened`、`resnet18_int8` 或 `resnet18_int16_widened` 目录，并把目录路径传给 `tests/chip/runtime/hw_runner_win.py`。`hw_runner_win.py` 首先读取编译目录中的 `plan.json`，从 `address_map` 和 `host_io` 字段取得存储基地址、输入偏移、输出偏移、输出形状、数据类型和程序段信息。

对于YOLOv5n输入，`hw_runner_win.py` 中的 `make_yolo_input` 函数调用 `tests/chip/unit-tb/run.py` 中的图像读取和letterbox预处理程序，将原始图片等比例缩放并填充到320×320。INT8模式调用 `preprocess_yolov5n`，按照 `network.json` 中的输入激活scale完成量化；widened INT16模式把归一化后的浮点像素除以相同激活scale，执行round和clip后保存为INT16。对于ResNet18输入，`make_resnet_input` 函数调用 `tests/chip/unit-tb/resnet_e2e.py` 中的 `configure_resnet_precision` 和 `preprocess_resnet18`，选择 `parsed_vai` 或 `parsed_vai_int16_widened` 参数目录并生成INT8或INT16输入。由于硬件 `im2col_unit` 按每个像素16字节对齐读取输入，`_pad_nhwc_input` 函数还会把三通道NHWC输入补零到16字节对齐的像素步长，再交给XDMA写入。

Windows XDMA访问程序位于项目顶层目录 `tests/chip/unit-tb` 文件夹下的 `xdma_win.py`。该程序调用 `tests/bin/xdma_rw.exe`，写数据时执行 `xdma_rw.exe h2c_0 write 地址 -b -f 文件 -l 长度`，读数据时执行 `xdma_rw.exe c2h_0 read 地址 -b -f 文件 -l 长度`。FPGA地址空间中，HBM基地址为 `0x00000000000`；8个Tile的IBUF从 `0x100000000` 开始，每个Tile占512KB；8个Tile的OBUF从 `0x101000000` 开始，每个Tile占256KB；VPU_BUF基地址为 `0x102000000`，容量8MB；WB基地址为 `0x103000000`；指令存储器INST基地址为 `0x104000000`；控制寄存器REGS基地址为 `0x105000000`。运行时把 `weights.bin` 一次性写入HBM的 `0x200000` 偏移，把 `wb.bin` 写入 `plan.json` 指定的VPU_BUF scratch位置，把预处理后的输入写入 `host_io.input_obuf_off` 指定的VPU_BUF位置。大文件按默认1MB写块分段写入，每次写入完成后读回末尾最多16字节，用于使XDMA写缓冲完成提交。

程序和数据写入完成后，`hw_runner_win.py` 使用 `load_programs` 函数读取单段 `program.bin`，或按照 `program_manifest.json` 顺序读取多个程序段。每个程序段均写入 `0x104000000` 指令存储器。程序启动前先读取 `0x105000040` 的DECODER_STATUS；若bit0为1，表示解码器仍处于busy状态，本次运行停止。启动时把当前程序段的32bit指令字数写入 `0x10500003C` 的INST_COUNT寄存器，再向 `0x105000038` 的DECODER_CTRL寄存器依次写1和0产生启动脉冲。程序运行期间每2ms读取一次DECODER_STATUS，bit1为1表示本段执行完成，bit31为1表示解码器报告错误；超过设定时间仍未完成则记录timeout。多段程序按照相同方法依次下发和执行，所有中间结果均保留在编译器规划的FPGA缓冲区中。

图2. XDMA下发、FPGA执行和结果读回流程图

FPGA执行完成后，`hw_runner_win.py` 按照 `plan.json` 中 `host_io.outputs` 给出的偏移、形状和数据类型，通过C2H通道从VPU_BUF分块读回结果。YOLOv5n读回三组FP32特征：PAN_P3为40×40×64、PAN_P4为20×20×128、PAN_P5为10×10×256；三组特征分别保存为 `features/PAN_P3.bin`、`features/PAN_P4.bin` 和 `features/PAN_P5.bin`。ResNet18读回GAP之前的7×7×512特征，INT8模式按INT8保存，widened INT16模式按INT16保存。每张图片的主输出文件名包含图片名称、网络名称、精度和 `fpga_oneshot` 标志；各程序段的上传时间、执行时间、权重上传时间、输入上传时间和结果读回时间写入同名的 `*_timing.json`。

每次读回后，`run.py` 调用项目顶层目录 `tests/chip/runtime` 文件夹下的 `compare_one_shot.py` 进行数值验证，再调用同一文件夹下的 `one_shot_host_head.py` 完成主机端网络头。YOLOv5n在FPGA中完成backbone、FPN/PAN、卷积、池化、上采样和拼接，主机端读取PAN_P3、PAN_P4和PAN_P5，使用 `DetectHead` 执行Detect head、decode和NMS，再把检测框映射回原图尺寸，保存检测JSON和画框图片。ResNet18在FPGA中完成全部卷积、stem maxpool、残差相加并输出GAP前特征，主机端对7×7×512特征求均值完成GAP，乘以最后一层激活scale，再加载FC权重和bias计算logits，最后排序得到Top-k类别并保存分类JSON和结果图片。因此，本报告中的端到端测试是从输入图片开始，经过FPGA主体网络计算和主机端网络头，最终输出检测框或分类结果的完整运行流程。

在Windows FPGA主机的项目顶层目录执行 `python run.py --acceptance --vcs skip`，即可顺序执行20张COCO图片和20张ImageNet图片的INT8、widened INT16测试。YOLOv5n结果保存在 `output/acceptance/yolo_coco/one_shot_int8` 和 `output/acceptance/yolo_coco/one_shot_int16`，ResNet18结果保存在 `output/acceptance/resnet/one_shot_int8` 和 `output/acceptance/resnet/one_shot_int16`。全部用例结束后，`run.py` 在 `output/acceptance` 中生成 `acceptance_report.json` 和 `acceptance_report.md`，记录每张图片的网络、精度、PASS/FAIL、检测数量或Top-1类别及运行时间。正式测试时同时保存终端输出，用于保留每个输出特征的Golden数值比对结果。

## 2. 计算精度

计算精度使用上述80个FPGA实测用例进行验证。INT8模式使用 `artifacts/c1773f6/yolo_coco_int8` 和 `artifacts/c1773f6/resnet18_int8` 中的native W8A8编译产物，输入、权重和量化中间数据按INT8数据通路执行。widened INT16模式使用 `artifacts/c1773f6/yolo_coco_int16_widened` 和 `artifacts/c1773f6/resnet18_int16_widened` 中的编译产物，把INT8量化模型的数值和scale保持不变，并把量化值扩展到INT16数据通路中存储、传输和计算。该模式用于验证16bit数据通路能够运行，不等同于独立训练和量化的原生W16A16网络。

FPGA输出的Golden验证程序为项目顶层目录 `tests/chip/runtime/compare_one_shot.py`。对于YOLOv5n，程序读取对应解析目录中的 `network.json` 和各层NPZ权重，按照 `YOLOV5N_SCHEDULE` 依次执行conv、save、load、concat、upsample、maxpool和add操作。卷积部分使用与硬件相同的im2col、整数矩阵乘、DQA scale、bias和激活处理，分别生成PAN_P3、PAN_P4和PAN_P5三组参考特征。对于ResNet18，程序读取 `parsed_vai` 或 `parsed_vai_int16_widened` 中的网络和权重，依次执行stem卷积、3×3 stride-2 maxpool、各BasicBlock卷积、downsample和residual add，生成与FPGA输出位置相同的7×7×512参考特征。Golden计算根据 `plan.json` 中的mode、输出数据类型和实际编译层数选择对应数值语义。

`compare_one_shot.py` 按照 `plan.json` 中记录的输出形状和数据类型读取FPGA二进制结果，将FPGA输出和Golden输出转换为FP32后逐元素相减，分别计算最大绝对误差 `max_abs`、平均绝对误差 `mean_abs` 和均方根误差 `rmse`。YOLOv5n对PAN_P3、PAN_P4、PAN_P5逐一计算并输出误差；ResNet18对最终7×7×512特征计算误差。命令行参数 `--atol` 的默认值为 `1e-3`，只要任一应比对输出的 `max_abs` 大于 `1e-3`，程序即以非零状态退出，`run.py` 将该图片和精度组合记录为FAIL；所有应比对输出均不超过阈值时，该用例记录为PASS。

计算精度测试同时检查INT8和widened INT16路径是否能够完成图片预处理、权重和程序下发、FPGA计算、特征读回以及主机端网络头。检测框数量、YOLO类别、ResNet18 Top-1类别和样本标签匹配情况作为端到端运行结果记录，FPGA计算数值正确性的自动判定以FPGA特征和Golden特征的逐元素比对为准。测试完成后，从保存的终端日志中整理四组测试的 `max_abs`、`mean_abs`、`rmse` 和PASS/FAIL，并把代表性检测图片、分类图片以及对应特征比对结果放入第八章。

## 3. 核心计算引擎峰值能效

本次测试不开展核心计算引擎峰值能效测试，不采集供电端口电压、电流、功率或能量数据，不计算TOPS/W，也不在测试结果中给出该项结论。

## 4. 处理器峰值算力

处理器峰值算力使用项目顶层目录 `rtl/tb/lite_bd/module_tb` 中的VCS Testbench进行仿真验证。Testbench文件为 `tb_lite_bd_module.sv`，其中例化Vivado Block Design顶层 `lite_wrapper`；主时钟 `CLK_PERIOD_NS` 设置为4ns，对应250MHz。峰值用例由同一目录中的 `golden_module_tb.py` 生成，用例名称为 `peak_int8_all_tiles`，模块类型为 `dcim_matmul`。该用例取YOLOv5n的 `model.9.cv2.conv` 层参数，固定矩阵规模M=1、K=512、N=128，并使8个DCIM Tile全部参与INT8计算。

VCS仿真前需要使用Vivado把当前Block Design导出为可供VCS编译的仿真工程。在项目顶层目录 `rtl/tb/lite_bd/module_tb` 中执行 `make export SIMULATOR=vcs`，Makefile调用项目顶层目录 `scripts/chip-lite/export_sim.tcl` 中的 `export_simulation` 命令，把导出文件写入项目顶层目录 `sim/lite_bd_export`。VCS导出脚本位于 `sim/lite_bd_export/vcs/lite/vcs/lite.sh`；Makefile的 `check-export` 目标会检查该文件以及DCIM module reference仿真wrapper是否存在，缺少任一文件时停止仿真。

导出完成后，在 `rtl/tb/lite_bd/module_tb` 目录执行 `make peak-int8`，或在项目顶层目录执行 `python3 run.py --vcs-only`。`run.py` 最终执行 `make -C rtl/tb/lite_bd/module_tb peak-int8`。Makefile固定设置 `MODULE_CASE=dcim_matmul`、`MODULE_VARIANT=peak_int8_all_tiles`、`MODULE_VERIFY_WORDS=0`、`MODULE_QUANT=int8`、`FSDB=1` 和 `PEAK_INT8=1`，并调用 `sim/run_module_sim.sh`。其中 `MODULE_VERIFY_WORDS=0` 表示对用例定义的全部输出字进行验证，不进行抽样。

`sim/run_module_sim.sh` 首先调用 `golden_module_tb.py --module dcim_matmul --case peak_int8_all_tiles --verify-words 0 --quant int8`，在 `rtl/tb/lite_bd/module_tb/sim/run_peak_int8_all_tiles` 中生成 `inst.hex`、`preload.txt`、`checks.txt`、`expected.hex`、`manifest.txt` 和 `module_manifest.svh`。`inst.hex` 保存测试指令，`preload.txt` 和各权重文件描述仿真开始前写入存储器的数据，`expected.hex` 保存Golden计算结果，`checks.txt` 描述结果地址和需要比对的全部字数，`manifest.txt` 保存M、K、N、acc_depth和峰值用例标志，`module_manifest.svh` 供Testbench编译时取得用例参数。

生成输入和Golden结果后，`run_module_sim.sh` 使用导出目录中的 `lite.sh` 编译Vivado Block Design及Xilinx仿真库，使用Vlogan把 `rtl/chip`、`rtl/vpu`、`rtl/common` 中的用户RTL、HBM快速仿真stub、`host_axi_master_bfm.sv` 和 `tb_lite_bd_module.sv` 编译到仿真库，再使用VCS对 `tb_lite_bd_module`、`lite` 和 `glbl` 进行elaborate，生成共享可执行文件 `rtl/tb/lite_bd/module_tb/sim/build_shared/simv`。FSDB模式在VCS编译参数中加入 `-debug_access+all`、`-kdb`、`-lca` 和 `+vcs+fsdbon`，运行时加入 `+FSDB` 和 `+PEAK_INT8`，在用例目录生成 `tb_lite_bd_module.fsdb` 和 `sim.log`。

Testbench从 `inst.hex` 和预加载文件写入指令、输入和权重，启动设计并从指定输出缓冲区读出实际结果，再按照 `checks.txt` 与 `expected.hex` 逐字比较。全部输出字一致时，`sim.log` 输出 `MODULE CHECK PASSED`；出现任一MISMATCH、FATAL或 `MODULE CHECK FAILED` 时，用例判定失败。该Golden比对用于先确认峰值用例的矩阵乘计算结果正确，避免仅根据计算活动信号推算算力。

为验证8个DCIM Tile同时工作，`tb_lite_bd_module.sv` 通过层次路径把每个Tile内部的 `compute_phase_fire` 引出为8bit测试信号 `peak_int8_compute_fire[7:0]`。监测逻辑在 `dut.lite_i.dcim_array_0.inst.u_dcim_array.start` 拉高且 `tile_mask` 全1时开始记录事务；只要任一Tile进入计算阶段就累计 `any_cycles`，8个Tile同时进入计算阶段时累计 `all_cycles`，仅部分Tile计算时累计 `skew_cycles`。每个计算周期同时在 `sim.log` 中输出 `PEAK_INT8_EVENT` 及当时的tile mask，事务结束时输出包含tiles、any_cycles、all_cycles、skew_cycles、transaction_cycles、first_time和last_time的 `PEAK_INT8_METRIC`。

仿真完成后，在 `rtl/tb/lite_bd/module_tb` 目录执行 `verdi -ssf sim/run_peak_int8_all_tiles/tb_lite_bd_module.fsdb -nologo` 打开波形。波形图中显示 `dut.lite_i.dcim_array_0.inst.clk`、`u_dcim_array.start`、`u_dcim_array.tile_mask`、`peak_int8_compute_fire[7:0]` 和 `u_dcim_array.done`。总体波形用于标出start至done的完整事务，放大波形用于标出有效计算窗口。在有效计算窗口中，`peak_int8_compute_fire[7:0]` 应连续为 `8'hFF`，`any_cycles` 应等于 `all_cycles`，`skew_cycles` 应为0，从而证明用于峰值计算的每个周期均由8个Tile同时执行。

图3. VCS峰值算力仿真总体波形

图4. 8个Tile/DCIM同时计算的FSDB放大波形

仿真结束后，Makefile调用同一目录中的 `report_peak_int8.py`。该程序读取用例目录中的 `manifest.txt` 和 `sim.log`，计算逻辑MAC数M×K×N=1×512×128=65,536；按一次乘法和一次加法分别计数，操作数为2×65,536=131,072。INT8矩阵乘需要两个计算phase，K=512对应acc_depth=8，因此期望全Tile有效计算周期为1×8×2=16个周期。主时钟周期为4ns，若FSDB和日志实测 `all_cycles=16`，则有效计算时间为16×4ns=64ns，处理器峰值算力为131,072÷64ns=2.048TOPS@INT8。

`report_peak_int8.py` 只有在VCS Golden比对通过、Tile数为8、`any_cycles=all_cycles`、`skew_cycles=0`、全部 `PEAK_INT8_EVENT` 的mask均为 `0xFF`、有效周期等于16并且计算结果不低于2TOPS时，才把峰值测试状态写为PASS。完整事务还包括输入和权重加载、控制及结果写回，其时间由 `transaction_cycles` 计算并单独记录为 `transaction_effective_tops`，不用于替代峰值计算窗口。最终原始数据保存在 `rtl/tb/lite_bd/module_tb/sim/run_peak_int8_all_tiles`，其中包括 `sim.log`、`tb_lite_bd_module.fsdb`、`peak_int8_report.json`、`peak_int8_report.md` 和 `peak_int8_waveform.svg`。只有这些VCS和FSDB实测文件实际生成且满足上述条件后，报告中才能给出2.048TOPS@INT8的结论。

# 五、测试仪器设备与环境

## 1. 测试平台

表 2. FPGA 实物测试环境

| 项目 | 实际配置 |
|---|---|
| FPGA 板卡及器件 | AMD/Xilinx VCU128；Virtex UltraScale+ HBM FPGA xcvu37p-fsvh2892-2L-e |
| Vivado board part | `xilinx.com:vcu128:part0:1.0` |
| JTAG 接口 | VCU128 板卡 JTAG 接口 |
| FPGA 主机 | ［填写 CPU、内存和主板/PCIe 插槽］ |
| 主机操作系统 | Windows［填写版本］ |
| XDMA 驱动 | ［填写驱动版本］ |
| XDMA 工具 | `tests/bin/xdma_rw.exe` |
| Vivado | v2024.2.2，Build 6060944（当前发布 bitstream 的实现工具版本） |
| Python | ［填写版本］ |
| 烧录文件 | `bitstream/edgeyolo_c1773f6_w8a8_w16a16w.bit` |

表 3. VCS/FSDB 仿真环境

| 项目 | 实际配置 |
|---|---|
| 服务器 | 北大杭研院 NCC 服务器［按实际填写节点］ |
| 操作系统 | Linux［填写发行版与版本］ |
| CPU/内存 | ［填写］ |
| VCS | ［填写版本］ |
| Verdi | ［填写版本］ |
| Vivado 导出仿真文件版本 | Vivado 2024.2.2 工程 |
| 仿真顶层 | `rtl/tb/lite_bd/module_tb/tb_lite_bd_module.sv` |
| 峰值用例 | `peak_int8_all_tiles` |
| 仿真时钟 | 4ns，250MHz |

## 2. 关键测试条件

FPGA 实物测试前，应确认 bitstream 已烧录、PCIe 已重新枚举、XDMA 设备正常启动，且 `h2c_0` 和 `c2h_0` 可访问。VCS 测试前，应确认 VCS、Verdi 许可证可用，且 Vivado 导出的 VCS 仿真工程存在。

# 六、测试人员、时间

表 4. 测试人员和时间

| 任务 | 测试人员 | 测试时间 |
|---|---|---|
| FPGA 烧录和 XDMA 设备确认 | ［填写］ | ［填写］ |
| YOLOv5n INT8/widened INT16 端到端实测 | ［填写］ | ［填写］ |
| ResNet18 INT8/widened INT16 端到端实测 | ［填写］ | ［填写］ |
| VCS/FSDB 处理器峰值算力测试 | ［填写］ | ［填写］ |
| 结果复核和报告整理 | ［填写］ | ［填写］ |

# 七、测试结果与结论

## 1. 核心计算引擎测试结果与结论

本次不测试核心计算引擎峰值能效，因此不填写 TOPS/W 结果。本节只汇总 VCS/FSDB 峰值算力用例中与计算正确性和全 Tile 并行有关的结果。

表 5. VCS/FSDB 峰值算力结果

| 项目 | 实测结果 | 判定 |
|---|---:|---|
| VCS Golden 比对 | ［填写 MODULE CHECK PASSED/FAILED］ | ［填写］ |
| Tile 数 | ［填写；期望 8］ | ［填写］ |
| any_cycles | ［填写］ | — |
| all_cycles | ［填写；期望 16］ | ［填写］ |
| skew_cycles | ［填写；期望 0］ | ［填写］ |
| 有效计算时间 | ［填写］ns | — |
| 处理器峰值算力 | ［填写］TOPS@INT8 | 与 ≥2 TOPS@INT8 对照 |

可直接在实测完成后按下列句式填写：

> VCS 仿真日志显示［MODULE CHECK PASSED/FAILED］。FSDB 波形显示峰值计算窗口内 8 个 Tile/DCIM 的 `compute_phase_fire`［均为 1/未能全部同时为 1］，`all_cycles=`［填写］，`skew_cycles=`［填写］。按 250MHz 时钟和实际有效计算周期计算，处理器峰值算力为［填写］TOPS@INT8，［满足/不满足］验收指标“≥2 TOPS@INT8”。

## 2. AI 处理器测试结果与结论

表 6. FPGA 端到端实测汇总

| 网络 | 精度 | 图片数 | PASS | FAIL | 最大 max_abs | 最终输出 |
|---|---|---:|---:|---:|---:|---|
| YOLOv5n | INT8 | 20 | ［填写］ | ［填写］ | ［填写］ | 检测 JSON 和画框图片 |
| YOLOv5n | widened INT16 | 20 | ［填写］ | ［填写］ | ［填写］ | 检测 JSON 和画框图片 |
| ResNet18 | INT8 | 20 | ［填写］ | ［填写］ | ［填写］ | Top-k JSON 和结果图片 |
| ResNet18 | widened INT16 | 20 | ［填写］ | ［填写］ | ［填写］ | Top-k JSON 和结果图片 |
| 合计 | — | 80 | ［填写］ | ［填写］ | — | — |

图 9 放置 1～2 张具有代表性的 YOLOv5n INT8 检测结果。<br>
图 10 放置相同输入的 YOLOv5n widened INT16 检测结果。<br>
图 11 放置 1～2 张具有代表性的 ResNet18 INT8 Top-k 结果。<br>
图 12 放置相同输入的 ResNet18 widened INT16 Top-k 结果。

可直接在实测完成后按下列句式填写：

> FPGA 实物测试共执行 80 个用例，其中 YOLOv5n INT8［填写］/20 通过、YOLOv5n widened INT16［填写］/20 通过、ResNet18 INT8［填写］/20 通过、ResNet18 widened INT16［填写］/20 通过。各通过用例的 FPGA 特征与 Golden 结果满足 `max_abs <= 1e-3`，并完成主机端 Detect head、decode、NMS 或 GAP、FC、Top-k，生成最终检测或分类结果。因此，［支持/不支持］ResNet、YOLO 端到端推理流程，［支持/不支持］INT8 与 widened INT16 数据通路。widened INT16 结论不扩展为原生 INT16 量化网络结论。

只有表 5 和表 6 均由实际输出填写完成后，才在第三章“完成情况”中写入最终结论。

# 八、测试原始数据及处理结果

## 1. FPGA 烧录和设备状态原始记录

本节依次放置：

1. Vivado Program Device 截图，显示目标器件和 `edgeyolo_c1773f6_w8a8_w16a16w.bit`。

2. Vivado 烧录完成截图。

3. 主机重启或 PCIe 重新枚举后的 Windows 设备管理器截图。

4. `xdma_rw.exe` 对 `h2c_0`、`c2h_0` 的实际访问记录。

5. 烧录时间、主机名、板卡编号和操作者记录。

本节不放 bitstream 哈希校验表。

## 2. 网络编译原始数据

表 7. 正式编译产物规模

| 网络与精度 | program | weights.bin | wb.bin | FPGA 输出 |
|---|---:|---:|---:|---|
| YOLOv5n INT8 | 71,252 B，1 段 | 1,761,280 B | 38,928 B | PAN_P3 40×40×64、PAN_P4 20×20×128、PAN_P5 10×10×256 |
| YOLOv5n widened INT16 | 129,044 B，1 段 | 3,522,560 B | 38,928 B | PAN_P3 40×40×64、PAN_P4 20×20×128、PAN_P5 10×10×256 |
| ResNet18 INT8 | 71,908 B，1 段 | 11,169,792 B | 93,472 B | 7×7×512 INT8 特征 |
| ResNet18 widened INT16 | 212,776 B，2 段，共 53,194 个指令字 | 22,339,584 B | 93,472 B | 7×7×512 INT16 特征 |

附上四组编译日志，以及相应的 `plan.json`、`program_manifest.json`（存在时）、`weights_layout.json`、`wb_layout.json` 和 `memory_map.md`。报告正文可节选关键内容，完整文件随原始数据一并归档。

## 3. FPGA 端到端原始数据

正式实测输出根目录为 `output/acceptance/`。至少归档：

- `output/acceptance/acceptance_report.json`；

- `output/acceptance/acceptance_report.md`；

- `output/acceptance/yolo_coco/one_shot_int8/`；

- `output/acceptance/yolo_coco/one_shot_int16/`；

- `output/acceptance/resnet/one_shot_int8/`；

- `output/acceptance/resnet/one_shot_int16/`。

每个图片用例应保留：

- FPGA 原始输出 `.bin`；

- YOLOv5n 的 PAN_P3、PAN_P4、PAN_P5 特征，或 ResNet18 的最终特征；

- `max_abs`、`mean_abs`、`rmse` 比对结果；

- 各程序段上传和执行时间的 `*_timing.json`；

- 主机端检测或 Top-k 结果 `.json`；

- 最终可视化图片；

- FAIL 用例的异常文本和重测记录。

把 `acceptance_report.md` 中的 80 个用例表复制到本节，列出网络、精度、图片名称和 PASS/FAIL。若发生失败或重测，不得只保留最终 PASS；应同时保存首次失败原因和重测条件。

## 4. VCS/FSDB 峰值算力原始数据

VCS 输出目录为：

`rtl/tb/lite_bd/module_tb/sim/run_peak_int8_all_tiles/`

至少归档：

| 文件 | 内容 |
|---|---|
| `sim.log` | VCS 日志、Golden 比对、`PEAK_INT8_EVENT` 和 `PEAK_INT8_METRIC` |
| `tb_lite_bd_module.fsdb` | Verdi 原始波形 |
| `peak_int8_report.json` | 周期、时间和 TOPS 结构化结果 |
| `peak_int8_report.md` | 可直接引用的峰值算力摘要 |
| `peak_int8_waveform.svg` | 自动生成的有效计算窗口示意图 |
| `manifest.txt` | M、K、N、acc_depth 和峰值用例标志 |

表 8. 峰值算力原始数据处理

| 原始量 | 数据来源 | 实测值 |
|---|---|---:|
| M、K、N | `manifest.txt` | M=1，K=512，N=128 |
| 逻辑 MAC 数 | M×K×N | 65,536 |
| OPS | 2×MAC | 131,072 |
| Tile 数 | `PEAK_INT8_METRIC` | 8 |
| any_cycles | `PEAK_INT8_METRIC` | ［填写］ |
| all_cycles | `PEAK_INT8_METRIC` | ［填写］ |
| skew_cycles | `PEAK_INT8_METRIC` | ［填写］ |
| 有效计算时间 | all_cycles×4ns | ［填写］ns |
| 峰值算力 | OPS÷有效计算时间 | ［填写］TOPS@INT8 |
| 完整事务时间 | transaction_cycles×4ns | ［填写］ns |
| 完整事务有效算力 | OPS÷完整事务时间 | ［填写］TOPS@INT8 |

FSDB 截图必须使用实际 VCS 生成的 `tb_lite_bd_module.fsdb`，同时显示全局事务窗口和放大的全 Tile 有效计算窗口。最终的 2.048 TOPS 结论必须能够由表 8 的实测周期和 FSDB 中连续的 `8'hFF` 计算活动信号复算得到。

## 5. 代码与测试步骤对应关系

表 9. 测试代码追溯表

| 测试步骤 | 代码文件 | 作用 |
|---|---|---|
| 一行测试入口 | `run.py` | 组织 80 个 FPGA 用例、调用服务器峰值测试、生成汇总报告 |
| 网络编译 | `tests/chip/compiler/compile.py` | 完整网络 lowering、存储规划、权重/WB 打包和指令编码 |
| FPGA 下发与执行 | `tests/chip/runtime/hw_runner_win.py` | 图片预处理、权重/输入/指令写入、启动、轮询和结果读回 |
| XDMA 命令封装 | `tests/chip/unit-tb/xdma_win.py` | 调用 `xdma_rw.exe` 的 `h2c_0` 和 `c2h_0` |
| FPGA/Golden 比对 | `tests/chip/runtime/compare_one_shot.py` | 计算 `max_abs`、`mean_abs`、`rmse` 并判定特征是否一致 |
| 主机端网络头 | `tests/chip/runtime/one_shot_host_head.py` | YOLO Detect/decode/NMS；ResNet GAP/FC/Top-k |
| 峰值输入和 Golden | `rtl/tb/lite_bd/module_tb/golden_module_tb.py` | 生成 `peak_int8_all_tiles` 的输入、期望输出和 manifest |
| VCS Testbench | `rtl/tb/lite_bd/module_tb/tb_lite_bd_module.sv` | 例化设计、输出 FSDB、监测 8 个 Tile 的计算活动周期 |
| VCS 执行脚本 | `rtl/tb/lite_bd/module_tb/sim/run_module_sim.sh` | 生成数据、编译/运行仿真、检查日志 |
| 峰值报告 | `rtl/tb/lite_bd/module_tb/report_peak_int8.py` | 从日志和 manifest 计算有效周期、时间及峰值 TOPS |

本章全部路径、命令、日志和截图应与正式测试时使用的同一项目版本对应。测试结束后，将项目版本标识、板卡记录、80 个 FPGA 用例原始数据、VCS 日志和 FSDB 一并归档。
