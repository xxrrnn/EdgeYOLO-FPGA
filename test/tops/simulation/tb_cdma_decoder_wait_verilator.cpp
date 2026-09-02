#include "Vtb_cdma_decoder_wait_verilator.h"
#include "verilated.h"

#include <cstdint>
#include <memory>

double sc_time_stamp() { return 0.0; }

static void tick(Vtb_cdma_decoder_wait_verilator* top) {
    top->clk = 0;
    top->eval();
    top->clk = 1;
    top->eval();
}

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    auto top = std::make_unique<Vtb_cdma_decoder_wait_verilator>();
    top->clk = 0;
    top->rst_n = 0;
    top->decoder_start = 0;

    for (std::uint64_t cycle = 0; cycle < 200000 && !Verilated::gotFinish(); ++cycle) {
        top->rst_n = cycle >= 8;
        top->decoder_start = (cycle == 12);
        tick(top.get());
    }

    const bool finished = Verilated::gotFinish();
    top->final();
    return finished ? 0 : 2;
}
