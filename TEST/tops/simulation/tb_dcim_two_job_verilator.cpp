#include <verilated.h>
#include "Vtb_dcim_two_job_verilator_top.h"

#include <array>
#include <cctype>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <fstream>
#include <string>
#include <vector>

static vluint64_t sim_time = 0;
double sc_time_stamp() { return static_cast<double>(sim_time); }

#ifndef TWO_JOB_PIXELS
#define TWO_JOB_PIXELS 256
#endif
#ifndef TWO_JOB_ACC
#define TWO_JOB_ACC 2
#endif

static const int kPixels = TWO_JOB_PIXELS;
static const int kAcc = TWO_JOB_ACC;
static const int kActStride = kAcc * 4;
static const int kWeightBase = kPixels * kActStride;
static const uint32_t kExpA = static_cast<uint32_t>(kAcc * 64 * 0x11 * 0x11);
static const uint32_t kExpB = static_cast<uint32_t>(kAcc * 64 * 0x22 * 0x11);
static const int kTimeout = kPixels * kAcc * 400 + 20000;

using Word128 = std::array<uint32_t, 4>;

static Word128 parse_word128(const std::string& raw) {
    std::string hex;
    for (char ch : raw) {
        if (!std::isspace(static_cast<unsigned char>(ch))) hex.push_back(ch);
    }
    if (hex.empty()) {
        std::fprintf(stderr, "empty 128-bit hex word\n");
        std::exit(2);
    }
    if (hex.size() > 32) {
        std::fprintf(stderr, "hex word wider than 32 digits\n");
        std::exit(2);
    }
    hex.insert(hex.begin(), 32 - hex.size(), '0');
    Word128 word{};
    for (int lane = 0; lane < 4; ++lane) {
        const std::string chunk = hex.substr(24 - lane * 8, 8);
        word[lane] = static_cast<uint32_t>(std::stoul(chunk, nullptr, 16));
    }
    return word;
}

static std::vector<Word128> read_hex_words(const std::string& path) {
    std::ifstream input(path.c_str());
    if (!input) {
        std::fprintf(stderr, "cannot open %s\n", path.c_str());
        std::exit(2);
    }
    std::vector<Word128> words;
    std::string line;
    while (std::getline(input, line)) {
        if (line.empty() || line[0] == '#') continue;
        if (!line.empty() && line.back() == '\r') line.pop_back();
        words.push_back(parse_word128(line));
    }
    return words;
}

struct Runner {
    Vtb_dcim_two_job_verilator_top top;

    void tick() {
        top.clk = 0;
        top.eval();
        sim_time += 2;
        top.clk = 1;
        top.eval();
        sim_time += 2;
    }

    void set_load_word(uint32_t addr, uint32_t lane0_repeat) {
        Word128 word;
        word[0] = word[1] = word[2] = word[3] = lane0_repeat;
        set_load_wide(addr, word);
    }

    void set_load_wide(uint32_t addr, const Word128& word) {
        top.load_en = 1;
        top.load_addr = addr;
        for (int lane = 0; lane < 4; ++lane) top.load_data[lane] = word[lane];
        tick();
        top.load_en = 0;
    }

    void load_words(uint32_t base, const std::vector<Word128>& words) {
        for (size_t i = 0; i < words.size(); ++i)
            set_load_wide(base + static_cast<uint32_t>(i), words[i]);
    }

    void fill_weights() {
        const uint32_t word = 0x11111111u;
        for (int w = 0; w < kAcc * 64; ++w)
            set_load_word(static_cast<uint32_t>(kWeightBase + w), word);
    }

    void fill_act(uint8_t val) {
        const uint32_t word = static_cast<uint32_t>(val) * 0x01010101u;
        for (int p = 0; p < kPixels; ++p) {
            for (int w = 0; w < kAcc * 4; ++w)
                set_load_word(static_cast<uint32_t>(p * kAcc * 4 + w), word);
        }
    }

    void pulse_start() {
        top.start = 1;
        tick();
        top.start = 0;
        tick();
    }

    bool wait_done() {
        int t = 0;
        while (!top.done && t < kTimeout) {
            tick();
            ++t;
        }
        if (!top.done) return false;
        t = 0;
        while (!top.ready && t < kTimeout) {
            tick();
            ++t;
        }
        for (int i = 0; i < 4; ++i) tick();
        return top.ready;
    }

    int check_obuf(uint32_t exp, int* first_bad) {
        int mismatches = 0;
        *first_bad = -1;
        for (int p = 0; p < kPixels; ++p) {
            for (int w = 0; w < 4; ++w) {
                top.peek_addr = static_cast<uint32_t>(p * 4 + w);
                top.eval();
                for (int lane = 0; lane < 4; ++lane) {
                    if (top.peek_data[lane] != exp) {
                        if (*first_bad < 0) *first_bad = p;
                        ++mismatches;
                    }
                }
            }
        }
        return mismatches;
    }

    int check_obuf_hex(const std::vector<Word128>& exp, int job, int* first_bad) {
        int mismatches = 0;
        int exact = 0;
        int64_t max_abs = 0;
        *first_bad = -1;
        const int tot = kPixels * 16;
        for (int p = 0; p < kPixels; ++p) {
            for (int w = 0; w < 4; ++w) {
                const int idx = p * 4 + w;
                top.peek_addr = static_cast<uint32_t>(idx);
                top.eval();
                for (int lane = 0; lane < 4; ++lane) {
                    const uint32_t got_u = top.peek_data[lane];
                    const uint32_t exp_u = exp[static_cast<size_t>(idx)][lane];
                    const int32_t got = static_cast<int32_t>(got_u);
                    const int32_t want = static_cast<int32_t>(exp_u);
                    int64_t diff = static_cast<int64_t>(got) - static_cast<int64_t>(want);
                    if (diff < 0) diff = -diff;
                    if (diff > max_abs) max_abs = diff;
                    if (got_u == exp_u) {
                        ++exact;
                    } else {
                        if (*first_bad < 0) {
                            *first_bad = p;
                            std::printf("TWO_JOB_YOLO first_bad job=%d px=%d word=%d lane=%d got=%d exp=%d\n",
                                        job, p, w, lane, got, want);
                        }
                        ++mismatches;
                    }
                }
            }
        }
        std::printf("TWO_JOB_YOLO job=%d exact=%d/%d mismatches=%d first_bad_px=%d max_abs=%lld\n",
                    job, exact, tot, mismatches, *first_bad, static_cast<long long>(max_abs));
        if (*first_bad >= 0) {
            const int p = *first_bad;
            std::printf("TWO_JOB_YOLO px%d got=", p);
            for (int w = 0; w < 4; ++w) {
                top.peek_addr = static_cast<uint32_t>(p * 4 + w);
                top.eval();
                for (int lane = 0; lane < 4; ++lane)
                    std::printf("%d%s", static_cast<int32_t>(top.peek_data[lane]),
                                (w == 3 && lane == 3) ? "" : ",");
            }
            std::printf("\nTWO_JOB_YOLO px%d exp=", p);
            for (int w = 0; w < 4; ++w)
                for (int lane = 0; lane < 4; ++lane)
                    std::printf("%d%s", static_cast<int32_t>(exp[static_cast<size_t>(p * 4 + w)][lane]),
                                (w == 3 && lane == 3) ? "" : ",");
            std::printf("\n");
        }
        return mismatches;
    }
};

static int run_constant(Runner& r) {
    std::printf("TWO_JOB verilator4 pixels=%d acc=%d expA=%u expB=%u weight_base=%d\n",
                kPixels, kAcc, kExpA, kExpB, kWeightBase);
    r.fill_weights();
    r.fill_act(0x11);
    std::printf("TWO_JOB start job1\n");
    r.pulse_start();
    if (!r.wait_done()) {
        std::printf("TWO_JOB_FAIL job=1 timeout done=%d ready=%d\n", r.top.done, r.top.ready);
        return 1;
    }
    int first_bad = -1;
    int mm = r.check_obuf(kExpA, &first_bad);
    std::printf("TWO_JOB job1 mismatches=%d first_bad_px=%d\n", mm, first_bad);
    if (mm != 0) {
        std::printf("TWO_JOB_FAIL job=1 first_bad_px=%d mismatches=%d\n", first_bad, mm);
        return 1;
    }
    r.fill_act(0x22);
    std::printf("TWO_JOB start job2 (no reset) ready=%d\n", r.top.ready);
    r.pulse_start();
    if (!r.wait_done()) {
        std::printf("TWO_JOB_FAIL job=2 timeout done=%d ready=%d\n", r.top.done, r.top.ready);
        return 1;
    }
    first_bad = -1;
    mm = r.check_obuf(kExpB, &first_bad);
    std::printf("TWO_JOB job2 mismatches=%d first_bad_px=%d\n", mm, first_bad);
    if (mm != 0) {
        std::printf("TWO_JOB_FAIL job=2 first_bad_px=%d mismatches=%d\n", first_bad, mm);
        return 1;
    }
    std::printf("TWO_JOB_PASS pixels=%d acc_depth=%d\n", kPixels, kAcc);
    return 0;
}

static int run_hex_case(Runner& r, const std::string& case_dir) {
    const std::string sep = case_dir.back() == '/' ? "" : "/";
    const auto wei = read_hex_words(case_dir + sep + "wei.hex");
    const auto act0 = read_hex_words(case_dir + sep + "act0.hex");
    const auto act1 = read_hex_words(case_dir + sep + "act1.hex");
    const auto exp0 = read_hex_words(case_dir + sep + "exp0.hex");
    const auto exp1 = read_hex_words(case_dir + sep + "exp1.hex");
    const size_t n_act = static_cast<size_t>(kPixels * kActStride);
    const size_t n_wei = static_cast<size_t>(kAcc * 64);
    const size_t n_exp = static_cast<size_t>(kPixels * 4);
    if (wei.size() != n_wei || act0.size() != n_act || act1.size() != n_act ||
        exp0.size() != n_exp || exp1.size() != n_exp) {
        std::printf("TWO_JOB_FAIL hex size wei=%zu/%zu act0=%zu/%zu act1=%zu exp0=%zu/%zu exp1=%zu\n",
                    wei.size(), n_wei, act0.size(), n_act, act1.size(), exp0.size(), n_exp, exp1.size());
        return 2;
    }
    std::printf("TWO_JOB_YOLO pixels=%d acc=%d weight_base=%d case=%s\n",
                kPixels, kAcc, kWeightBase, case_dir.c_str());

    r.load_words(static_cast<uint32_t>(kWeightBase), wei);
    r.load_words(0, act0);
    std::printf("TWO_JOB_YOLO start job1\n");
    r.pulse_start();
    if (!r.wait_done()) {
        std::printf("TWO_JOB_FAIL job=1 timeout done=%d ready=%d\n", r.top.done, r.top.ready);
        return 1;
    }
    int first_bad = -1;
    int mm1 = r.check_obuf_hex(exp0, 1, &first_bad);
    r.load_words(0, act1);
    std::printf("TWO_JOB_YOLO start job2 (no reset) ready=%d\n", r.top.ready);
    r.pulse_start();
    if (!r.wait_done()) {
        std::printf("TWO_JOB_FAIL job=2 timeout done=%d ready=%d\n", r.top.done, r.top.ready);
        return 1;
    }
    first_bad = -1;
    int mm2 = r.check_obuf_hex(exp1, 2, &first_bad);
    if (mm1 == 0 && mm2 == 0) {
        std::printf("TWO_JOB_PASS pixels=%d acc_depth=%d yolo_real\n", kPixels, kAcc);
        return 0;
    }
    std::printf("TWO_JOB_FAIL yolo_real job1_mm=%d job2_mm=%d\n", mm1, mm2);
    return 1;
}

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    Runner r;
    r.top.rst_n = 0;
    r.top.start = 0;
    r.top.load_en = 0;
    for (int i = 0; i < 8; ++i) r.tick();
    r.top.rst_n = 1;
    for (int i = 0; i < 4; ++i) r.tick();

    int rc = 0;
    if (argc >= 2 && argv[1][0] != '+')
        rc = run_hex_case(r, argv[1]);
    else
        rc = run_constant(r);
    r.top.final();
    return rc;
}
