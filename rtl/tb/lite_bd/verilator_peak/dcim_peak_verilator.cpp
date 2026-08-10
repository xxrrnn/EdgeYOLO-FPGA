#include <verilated.h>
#include <verilated_vcd_c.h>

#include <array>
#include <cctype>
#include <cstdint>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <sstream>
#include <stdexcept>
#include <string>
#include <vector>

#include "Vdcim_peak_verilator_top.h"

using Word128 = std::array<uint32_t, 4>;

static vluint64_t sim_time_ns = 0;
double sc_time_stamp() { return static_cast<double>(sim_time_ns); }

static Word128 parse_word128(const std::string& raw) {
    std::string hex;
    for (char ch : raw) {
        if (!std::isspace(static_cast<unsigned char>(ch))) hex.push_back(ch);
    }
    if (hex.empty()) throw std::runtime_error("empty 128-bit hex word");
    if (hex.size() > 32) throw std::runtime_error("128-bit hex word is wider than 32 digits: " + hex);
    hex.insert(hex.begin(), 32 - hex.size(), '0');
    Word128 word{};
    for (int lane = 0; lane < 4; ++lane) {
        const std::string chunk = hex.substr(24 - lane * 8, 8);
        word[lane] = static_cast<uint32_t>(std::stoul(chunk, nullptr, 16));
    }
    return word;
}

static std::vector<Word128> read_hex_words(const std::string& path) {
    std::ifstream input(path);
    if (!input) throw std::runtime_error("cannot open " + path);
    std::vector<Word128> words;
    std::string line;
    while (std::getline(input, line)) {
        if (line.empty() || line[0] == '#') continue;
        words.push_back(parse_word128(line));
    }
    return words;
}

static std::string word_to_hex(const Word128& word) {
    std::ostringstream out;
    out << std::hex << std::setfill('0');
    for (int lane = 3; lane >= 0; --lane) out << std::setw(8) << word[lane];
    return out.str();
}

static void set_wide(WData* signal, const Word128& word) {
    for (int lane = 0; lane < 4; ++lane) signal[lane] = word[lane];
}

static Word128 get_wide(const WData* signal) {
    Word128 word{};
    for (int lane = 0; lane < 4; ++lane) word[lane] = signal[lane];
    return word;
}

struct Runner {
    Vdcim_peak_verilator_top top;
    VerilatedVcdC trace;
    uint64_t cycles = 0;
    uint64_t start_cycle = 0;
    uint64_t any_cycles = 0;
    uint64_t all_cycles = 0;
    uint64_t skew_cycles = 0;
    uint64_t first_time_ns = 0;
    uint64_t last_time_ns = 0;
    std::vector<uint32_t> sampled_inputs;
    uint64_t result_pulses = 0;
    uint32_t sampled_result = 0;
    bool monitor_compute = false;

    explicit Runner(const std::string& vcd_path) {
        Verilated::traceEverOn(true);
        top.trace(&trace, 2);
        trace.open(vcd_path.c_str());
    }

    ~Runner() {
        top.final();
        trace.close();
    }

    void tick() {
        top.clk = 0;
        top.eval();
        trace.dump(sim_time_ns);
        sim_time_ns += 2;
        top.clk = 1;
        top.eval();
        trace.dump(sim_time_ns);
        ++cycles;
        if (monitor_compute && top.compute_fire != 0) {
            const unsigned mask = top.compute_fire;
            if (any_cycles == 0) first_time_ns = sim_time_ns;
            last_time_ns = sim_time_ns;
            ++any_cycles;
            if (mask == 0xff) ++all_cycles;
            else ++skew_cycles;
            sampled_inputs.push_back(top.peak_dcim_input);
            std::cout << "PEAK_INT8_EVENT cycle=" << (cycles - start_cycle)
                      << " time_ns=" << sim_time_ns
                      << " mask=0x" << std::hex << mask << std::dec << "\n";
        }
        if (top.peak_result_valid) {
            ++result_pulses;
            sampled_result = top.peak_result_data;
        }
        sim_time_ns += 2;
    }

    void load_word(unsigned tile, unsigned addr, const Word128& word) {
        top.load_en = 1;
        top.load_tile = tile;
        top.load_addr = addr;
        set_wide(top.load_data, word);
        tick();
        top.load_en = 0;
    }

    Word128 read_word(unsigned tile, unsigned addr) {
        top.read_tile = tile;
        top.read_addr = addr;
        top.read_en = 1;
        tick();
        top.read_en = 0;
        for (int wait = 0; wait < 64; ++wait) {
            tick();
            if (top.read_valid) return get_wide(top.read_data);
        }
        throw std::runtime_error("tile OBUF read timed out");
    }
};

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    if (argc != 3) {
        std::cerr << "usage: " << argv[0] << " CASE_DIR WAVEFORM.vcd\n";
        return 2;
    }

    const std::string case_dir = argv[1];
    try {
        const auto activations = read_hex_words(case_dir + "/act.hex");
        const auto expected = read_hex_words(case_dir + "/expected.hex");
        if (activations.size() != 4) {
            throw std::runtime_error("exact-fit peak case must contain 4 activation words");
        }
        if (expected.size() != 32) {
            throw std::runtime_error("peak case must contain 32 expected output words");
        }

        // The ILA input probe carries Tile 0's first eight DCIM nibbles:
        // high nibble on phase 0, low nibble on phase 1.
        std::array<uint32_t, 2> expected_probe_inputs{};
        for (unsigned channel = 0; channel < 8; ++channel) {
            const unsigned byte_value =
                (activations[0][channel / 4] >> (8 * (channel % 4))) & 0xffu;
            expected_probe_inputs[0] |= ((byte_value >> 4) & 0xfu) << (4 * channel);
            expected_probe_inputs[1] |= (byte_value & 0xfu) << (4 * channel);
        }

        Runner sim(argv[2]);
        sim.top.rst_n = 0;
        sim.top.start = 0;
        sim.top.load_en = 0;
        sim.top.read_en = 0;
        for (int i = 0; i < 8; ++i) sim.tick();
        sim.top.rst_n = 1;
        for (int i = 0; i < 4; ++i) sim.tick();

        for (unsigned tile = 0; tile < 8; ++tile) {
            for (unsigned index = 0; index < activations.size(); ++index) {
                sim.load_word(tile, index, activations[index]);
            }
            const auto weights = read_hex_words(
                case_dir + "/weight_tile" + std::to_string(tile) + ".hex");
            if (weights.size() != 64) {
                throw std::runtime_error("exact-fit peak case tile weight file must contain 64 words");
            }
            for (unsigned index = 0; index < weights.size(); ++index) {
                sim.load_word(tile, 0x4000u + index, weights[index]);
            }
        }

        if (!sim.top.ready) throw std::runtime_error("DCIM array is not ready before start");
        sim.top.start = 1;
        sim.start_cycle = sim.cycles;
        sim.monitor_compute = true;
        sim.tick();
        sim.top.start = 0;

        bool observed_busy = false;
        bool completed = false;
        for (uint64_t wait = 0; wait < 1000000; ++wait) {
            sim.tick();
            if (!sim.top.done) observed_busy = true;
            if (observed_busy && sim.top.done) {
                completed = true;
                break;
            }
        }
        sim.monitor_compute = false;
        if (!completed) throw std::runtime_error("DCIM transaction timed out");
        const uint64_t transaction_cycles = sim.cycles - sim.start_cycle;

        unsigned mismatches = 0;
        for (unsigned tile = 0; tile < 8; ++tile) {
            for (unsigned word = 0; word < 4; ++word) {
                const Word128 actual = sim.read_word(tile, word);
                const Word128& want = expected[tile * 4 + word];
                if (actual != want) {
                    ++mismatches;
                    std::cerr << "MISMATCH tile=" << tile << " word=" << word
                              << " actual=" << word_to_hex(actual)
                              << " expected=" << word_to_hex(want) << "\n";
                }
            }
        }

        std::cout << "PEAK_INT8_METRIC tiles=8 any_cycles=" << sim.any_cycles
                  << " all_cycles=" << sim.all_cycles
                  << " skew_cycles=" << sim.skew_cycles
                  << " transaction_cycles=" << transaction_cycles
                  << " first_time_ns=" << sim.first_time_ns
                  << " last_time_ns=" << sim.last_time_ns << "\n";

        const bool probe_input_ok =
            sim.sampled_inputs.size() == expected_probe_inputs.size() &&
            sim.sampled_inputs[0] == expected_probe_inputs[0] &&
            sim.sampled_inputs[1] == expected_probe_inputs[1];
        const bool probe_result_ok =
            sim.result_pulses == 1 && sim.sampled_result == expected[0][0];

        std::cout << "PEAK_ILA_CHECK input_match=" << probe_input_ok
                  << " result_pulses=" << sim.result_pulses
                  << " result_match=" << probe_result_ok << "\n";

        if (mismatches == 0 && sim.any_cycles == 2 && sim.all_cycles == 2 &&
            sim.skew_cycles == 0 && probe_input_ok && probe_result_ok) {
            std::cout << "MODULE CHECK PASSED\n";
            return 0;
        }
        std::cerr << "MODULE CHECK FAILED mismatches=" << mismatches << "\n";
        return 1;
    } catch (const std::exception& exc) {
        std::cerr << "FATAL: " << exc.what() << "\n";
        return 1;
    }
}
