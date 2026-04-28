//Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
//Copyright 2022-2025 Advanced Micro Devices, Inc. All Rights Reserved.
//--------------------------------------------------------------------------------
//Tool Version: Vivado v.2024.2.2 (lin64) Build 6060944 Thu Mar 06 19:10:09 MST 2025
//Date        : Tue Apr 28 23:17:50 2026
//Host        : DESKTOP-5NNBJ0V running 64-bit Ubuntu 22.04.1 LTS
//Command     : generate_target xdma_bram_wrapper.bd
//Design      : xdma_bram_wrapper
//Purpose     : IP block netlist
//--------------------------------------------------------------------------------
`timescale 1 ps / 1 ps

module xdma_bram_wrapper
   (cpu_reset,
    pci_express_x8_rxn,
    pci_express_x8_rxp,
    pci_express_x8_txn,
    pci_express_x8_txp,
    pcie_refclk_clk_n,
    pcie_refclk_clk_p,
    user_lnk_up_0);
  input cpu_reset;
  input [7:0]pci_express_x8_rxn;
  input [7:0]pci_express_x8_rxp;
  output [7:0]pci_express_x8_txn;
  output [7:0]pci_express_x8_txp;
  input pcie_refclk_clk_n;
  input pcie_refclk_clk_p;
  output user_lnk_up_0;

  wire cpu_reset;
  wire [7:0]pci_express_x8_rxn;
  wire [7:0]pci_express_x8_rxp;
  wire [7:0]pci_express_x8_txn;
  wire [7:0]pci_express_x8_txp;
  wire pcie_refclk_clk_n;
  wire pcie_refclk_clk_p;
  wire user_lnk_up_0;

  xdma_bram xdma_bram_i
       (.cpu_reset(cpu_reset),
        .pci_express_x8_rxn(pci_express_x8_rxn),
        .pci_express_x8_rxp(pci_express_x8_rxp),
        .pci_express_x8_txn(pci_express_x8_txn),
        .pci_express_x8_txp(pci_express_x8_txp),
        .pcie_refclk_clk_n(pcie_refclk_clk_n),
        .pcie_refclk_clk_p(pcie_refclk_clk_p),
        .user_lnk_up_0(user_lnk_up_0));
endmodule
