"""Custom exceptions raised by the EdgeYOLO-FPGA-lite compiler."""


class CompilerError(Exception):
    pass


class UnsupportedOp(CompilerError):
    """Raised by lowering when an ONNX op does not map to the current RTL."""

    def __init__(self, layer_name: str, op: str, reason: str):
        self.layer_name = layer_name
        self.op = op
        self.reason = reason
        super().__init__(f"[Unsupported] {layer_name} ({op}): {reason}")


class MemoryPlanError(CompilerError):
    pass


class OutOfBuffer(CompilerError):
    pass
