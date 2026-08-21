#include <verilated.h>
#include "Vtb_cdma_sr_idle_hold.h"

#include <cstdint>
#include <cstdio>
#include <cstdlib>

static vluint64_t sim_time = 0;
double sc_time_stamp() { return static_cast<double>(sim_time); }

struct Runner {
    Vtb_cdma_sr_idle_hold top;

    void tick() {
        top.clk = 0;
        top.eval();
        sim_time += 2;
        top.clk = 1;
        top.eval();
        sim_time += 2;
    }

    void reset() {
        top.rst_n = 0;
        top.cdma_start = 0;
        top.idle_hold = 0;
        top.xfer_cycles = 0;
        for (int i = 0; i < 8; ++i) tick();
        top.rst_n = 1;
        for (int i = 0; i < 4; ++i) tick();
    }
};

struct Result {
    int first_poll_idle;
    int first_poll_cycle;
    int ready_fall_cycle;
    int ready_rise_cycle;
    int ip_busy_at_ready;
    int ip_idle_at_ready;
    int true_done_cycle;
};

static Result run_case(Runner& r, int hold, int xfer, const char* name) {
    std::printf("\n=== CASE %s idle_hold=%d xfer_cycles=%d cooldown=%d ===\n",
                name, hold, xfer, 2000);
    r.reset();
    r.top.idle_hold = static_cast<uint16_t>(hold);
    r.top.xfer_cycles = static_cast<uint16_t>(xfer);

    while (!r.top.ctrl_ready) r.tick();

    r.top.cdma_start = 1;
    r.tick();
    r.top.cdma_start = 0;

    Result out{};
    out.first_poll_idle = -1;
    out.first_poll_cycle = -1;
    out.ready_fall_cycle = -1;
    out.ready_rise_cycle = -1;
    out.true_done_cycle = -1;
    out.ip_busy_at_ready = -1;
    out.ip_idle_at_ready = -1;

    int saw_busy = 0;
    int saw_true_done = 0;
    const int timeout = 2000 + xfer + hold + 4000;
    for (int i = 0; i < timeout; ++i) {
        r.tick();
        const int cyc = static_cast<int>(r.top.cycle_ctr);
        if (r.top.first_poll_valid && out.first_poll_cycle < 0) {
            out.first_poll_cycle = cyc;
            out.first_poll_idle = static_cast<int>(r.top.first_poll_idle);
        }
        if (!r.top.ctrl_ready && out.ready_fall_cycle < 0)
            out.ready_fall_cycle = cyc;
        if (r.top.ip_busy) saw_busy = 1;
        if (saw_busy && r.top.ip_idle && out.true_done_cycle < 0) {
            out.true_done_cycle = cyc;
            saw_true_done = 1;
        }
        if (out.ready_fall_cycle >= 0 && r.top.ctrl_ready && out.ready_rise_cycle < 0) {
            out.ready_rise_cycle = cyc;
            out.ip_busy_at_ready = static_cast<int>(r.top.ip_busy);
            out.ip_idle_at_ready = static_cast<int>(r.top.ip_idle);
            break;
        }
    }

    std::printf("first_SR_poll_after_BTT idle=%d cycle=%d\n",
                out.first_poll_idle, out.first_poll_cycle);
    std::printf("controller left IDLE cycle=%d\n", out.ready_fall_cycle);
    std::printf("controller returned ready cycle=%d ip_busy=%d ip_idle=%d\n",
                out.ready_rise_cycle, out.ip_busy_at_ready, out.ip_idle_at_ready);
    std::printf("true AXI CDMA transfer done cycle=%d\n", out.true_done_cycle);

    const int decoder_new_same =
        (out.ready_rise_cycle >= 0 && out.ready_fall_cycle >= 0);
    std::printf("decoder seen_busy&&ready would fire at controller ready=%d (same cycle)\n",
                decoder_new_same ? out.ready_rise_cycle : -1);

    if (out.ready_rise_cycle < 0) {
        std::printf("VERDICT %s TIMEOUT\n", name);
    } else if (out.ip_busy_at_ready) {
        std::printf("VERDICT %s FALSE_COMPLETE "
                    "CDMA_Controller returned ready while AXI CDMA SR.Idle still 0\n",
                    name);
    } else if (saw_true_done && out.ready_rise_cycle + 2 < out.true_done_cycle) {
        std::printf("VERDICT %s FALSE_COMPLETE "
                    "ready %d cycles before true SR busy->idle\n",
                    name, out.true_done_cycle - out.ready_rise_cycle);
    } else {
        std::printf("VERDICT %s WAITED_FOR_TRUE_IDLE\n", name);
    }
    return out;
}

int main() {
    Verilated::commandArgs(0, static_cast<char**>(nullptr));
    Runner r;

    // Naive IP: Idle drops in the same BTT-write cycle. Old poll "wait until
    // Idle=1" happens to work because the first poll already sees Idle=0.
    const Result naive = run_case(r, 0, 8000, "NAIVE_IP_IDLE_DROPS_NOW");

    // PG034-like window: BRESP of BTT returns while SR.Idle is still the
    // pre-start 1. First poll treats that as "transfer done", then 2000
    // cooldown, then ready — while the 8000-cycle transfer is still running.
    const Result delayed = run_case(r, 32, 8000, "DELAYED_IDLE_DROP");

    const int naive_ok = (naive.ip_busy_at_ready == 0 && naive.ready_rise_cycle >= 0);
    const int delayed_false = (delayed.ip_busy_at_ready == 1);

    std::printf("\n=== ROOT_CAUSE ===\n");
    std::printf("naive IP model (Idle falls immediately): %s\n",
                naive_ok ? "controller waits" : "UNEXPECTED");
    std::printf("delayed Idle after BTT: %s\n",
                delayed_false ? "controller FALSE_COMPLETE" : "UNEXPECTED");
    if (naive_ok && delayed_false) {
        std::printf("ERROR_CAUSE=CDMA_Controller polls SR.Idle=1 after BTT "
                    "without first seeing SR.Idle=0\n");
        std::printf("NOT_THE_CAUSE=INST_Decoder initial IDLE / cdma_seen_busy "
                    "(it only waits for controller ready, which already lied)\n");
        return 0;
    }
    std::printf("ERROR_CAUSE=UNRESOLVED\n");
    return 1;
}
