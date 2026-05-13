import numpy as np
import os

def numpy_to_verilog_mem(arr: np.ndarray, var_name="act", file_prefix="act_data", type="int8",out_dir=".", task = ""):
    """
    将 numpy 数组转为:
      1. <out_dir>/<file_prefix>.mem 文件（用于 $readmemh）
      2. Verilog 声明 + $readmemh 语句字符串

    每 256 bit (32 byte) 一行。
    支持 type: 'int8', 'int16', 'fp16', 'fp32'
    """
    # validate type
    t = type.lower()
    if t not in ("int8", "int16","int32", "fp16", "fp32"):
        raise ValueError("Only int8/int16/fp16/fp32 supported")

    # element byte size and conversion to unsigned view
    if t == "int8":
        elem_bytes = 1
        data_view = arr.flatten().astype(np.uint8)
    elif t == "int16":
        elem_bytes = 2
        data_view = arr.flatten().astype(np.uint16)
    elif t == "int32":
        elem_bytes = 4
        data_view = arr.flatten().astype(np.uint32)
    elif t == "fp16":
        elem_bytes = 2
        # convert to float16 then reinterpret bits as uint16
        data_view = arr.astype(np.float16).flatten().view(np.uint16)
    elif t == "fp32":
        elem_bytes = 4
        data_view = arr.astype(np.float32).flatten().view(np.uint32)

    # 每行目标为 32 bytes
    bytes_per_line = 32
    elems_per_line = bytes_per_line // elem_bytes

    # split into chunks of elems_per_line
    total_elems = data_view.size
    chunks = [data_view[i:i+elems_per_line] for i in range(0, total_elems, elems_per_line)]

    # create hex lines (big-endian style within chunk by reversing chunk order)
    hex_lines = []
    hex_width = elem_bytes * 2  # hex digits per element
    for chunk in chunks:
        # pad last chunk if shorter than elems_per_line with zeros
        if chunk.size < elems_per_line:
            # create zero-padded array of same dtype
            pad = np.zeros(elems_per_line - chunk.size, dtype=data_view.dtype)
            chunk = np.concatenate((chunk, pad))
        # reverse order (original函数使用了 chunk[::-1])
        chunk_be = chunk[::-1]
        # format each element with fixed width and concat
        hex_str = ''.join(f"{int(elem):0{hex_width}x}" for elem in chunk_be)
        hex_lines.append(hex_str)

    # write .mem file
    os.makedirs(out_dir, exist_ok=True)
    mem_filename = f"{out_dir}/{task}_{file_prefix}.mem"
    with open(mem_filename, "w") as f:
        for line in hex_lines:
            f.write(line + "\n")

    # infer height and channel for Verilog params (best-effort)
    if arr.ndim == 4:
        # assume shape (N, H, W, C) or (N, C, H, W) - we'll try (N,H,W,C)
        height = arr.shape[1]
        width = arr.shape[2]
        channels = arr.shape[3]
    elif arr.ndim == 3:
        # assume (H, W, C)
        height = arr.shape[0]
        width = arr.shape[1]
        channels = arr.shape[2]
    else:
        # fallback
        height = arr.shape[0]
        width = arr.shape[0]
        channels = arr.shape[-1]

    blocks = len(chunks)
    verilog_mem_filename = mem_filename.replace("\\", "/")

    verilog_decl = f"""\

localparam {var_name.upper()}_CHANNEL_NUM = {channels};
localparam {var_name.upper()}_HEIGHT = {height};
localparam {var_name.upper()}_WIDTH  = {width};
localparam {var_name.upper()}_BLOCKS = {blocks};
localparam {var_name.upper()}_BYTES  = {blocks} * 32;

reg [255:0] {var_name} [0:{blocks-1}];

initial begin
    $display("Loading {mem_filename} ...");
    $readmemh("{verilog_mem_filename}", {var_name});
    $display("Loaded %0d blocks into {var_name}", {var_name.upper()}_BLOCKS);
end

"""

    # # save verilog decl file
    # verilog_filename = os.path.join(out_dir, f"{file_prefix}_decl.v")
    # with open(verilog_filename, "w") as f:
    #     f.write(verilog_decl)

    return verilog_decl
