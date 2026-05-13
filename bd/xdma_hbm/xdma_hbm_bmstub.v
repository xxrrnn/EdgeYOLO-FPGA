// Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
// Copyright 2022-2026 Advanced Micro Devices, Inc. All Rights Reserved.
// -------------------------------------------------------------------------------

`timescale 1 ps / 1 ps

(* BLOCK_STUB = "true" *)
module xdma_hbm (
  user_lnk_up_0,
  pci_express_x8_rxn,
  pci_express_x8_rxp,
  pci_express_x8_txn,
  pci_express_x8_txp,
  cpu_reset,
  pcie_refclk_clk_n,
  pcie_refclk_clk_p
);

  (* X_INTERFACE_IGNORE = "true" *)
  output user_lnk_up_0;
  (* X_INTERFACE_INFO = "xilinx.com:interface:pcie_7x_mgt:1.0 pci_express_x8 rxn" *)
  (* X_INTERFACE_MODE = "master pci_express_x8" *)
  input [7:0]pci_express_x8_rxn;
  (* X_INTERFACE_INFO = "xilinx.com:interface:pcie_7x_mgt:1.0 pci_express_x8 rxp" *)
  input [7:0]pci_express_x8_rxp;
  (* X_INTERFACE_INFO = "xilinx.com:interface:pcie_7x_mgt:1.0 pci_express_x8 txn" *)
  output [7:0]pci_express_x8_txn;
  (* X_INTERFACE_INFO = "xilinx.com:interface:pcie_7x_mgt:1.0 pci_express_x8 txp" *)
  output [7:0]pci_express_x8_txp;
  (* X_INTERFACE_INFO = "xilinx.com:signal:reset:1.0 RST.CPU_RESET RST" *)
  (* X_INTERFACE_MODE = "slave RST.CPU_RESET" *)
  (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME RST.CPU_RESET, POLARITY ACTIVE_HIGH, INSERT_VIP 0" *)
  input cpu_reset;
  (* X_INTERFACE_INFO = "xilinx.com:interface:diff_clock:1.0 pcie_refclk CLK_N" *)
  (* X_INTERFACE_MODE = "slave pcie_refclk" *)
  (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME pcie_refclk, CAN_DEBUG false, FREQ_HZ 100000000" *)
  input pcie_refclk_clk_n;
  (* X_INTERFACE_INFO = "xilinx.com:interface:diff_clock:1.0 pcie_refclk CLK_P" *)
  input pcie_refclk_clk_p;

  // stub module has no contents

endmodule
