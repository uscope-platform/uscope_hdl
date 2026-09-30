import numpy as np
import matplotlib.pyplot as plt

# --- Configuration parameters ---
INPUT_WIDTH = 16
N_STEPS = 3
M_DELAY = 1
DECIMATION_RATIO = 16
ACCUM_WIDTH = 28  # Full unscaled internal processing width (16-bit input + 12-bit growth)

NUM_SAMPLES = 2048
BIT_MASK = (1 << ACCUM_WIDTH) - 1

def to_signed(val, bits):
    """Converts a bit-masked integer back to a standard Python signed integer."""
    val = val & ((1 << bits) - 1)
    if val & (1 << (bits - 1)):
        return val - (1 << bits)
    return val

# 1. Simulate Product Demodulator Signal
t = np.arange(NUM_SAMPLES)
baseband_msg = np.sin(2 * np.pi * 0.002 * t)          # Low-freq information signal
carrier = np.cos(2 * np.pi * 0.1 * t)                 # IF Carrier
modulated_rf = baseband_msg * carrier

lo_carrier = np.cos(2 * np.pi * 0.1 * t)              # Local Oscillator
mixed_product = modulated_rf * lo_carrier             # Product: 0.5*msg + 0.5*msg*cos(2*w*t)

# Scale to 16-bit signed integer range
max_int = (1 << (INPUT_WIDTH - 1)) - 1
input_signal = np.int16(np.clip(mixed_product * max_int * 0.8, -max_int, max_int))

# 2. Pure Mathematical Ideal CIC Filter (Full Precision)
# A. Integrators: registered, each stage uses the OLD value of the previous one
integ = [0] * N_STEPS
high_rate_accum = []
for x in input_signal:
    prev = integ[:]
    integ[0] = (prev[0] + int(x)) & BIT_MASK
    for i in range(1, N_STEPS):
        integ[i] = (prev[i] + prev[i-1]) & BIT_MASK
    high_rate_accum.append(integ[-1])

# B. Decimate (unchanged)
decimated_samples = high_rate_accum[DECIMATION_RATIO - 1 :: DECIMATION_RATIO]

# C. Combs: registered, each stage uses the OLD output of the previous one
comb_mem = [0] * N_STEPS
comb_out = [0] * N_STEPS
all_outputs = []
for s in decimated_samples:
    inp = [s] + comb_out[:-1]                 # old outputs
    comb_out = [(inp[i] - comb_mem[i]) & BIT_MASK for i in range(N_STEPS)]
    comb_mem = inp
    all_outputs.append(to_signed(comb_out[-1], ACCUM_WIDTH))

# RTL suppresses output until pipeline_full (first N_STEPS-1 comb outputs dropped)
expected_outputs = all_outputs[N_STEPS - 1:]

# 3. Write Stimulus Files
with open("stim.mem", "w") as f_in:
    for val in input_signal:
        hex_val = f"{(int(val) & 0xFFFF):04X}"
        f_in.write(f"{hex_val}\n")

with open("check.mem", "w") as f_out:
    for val in expected_outputs:
        # Full 28-bit output formatted as 8-character 32-bit hex words for Verilog $readmemh
        hex_val = f"{(int(val) & 0xFFFF):04X}"
        f_out.write(f"{hex_val}\n")

# 4. Visualization Plots
fig, (ax1, ax2) = plt.subplots(2, 1, figsize=(10, 6), sharex=False)

ax1.plot(input_signal, color='crimson', alpha=0.7, label='Mixed Input Signal (16-bit)')
ax1.set_title('Product Demodulator Mixed Input Signal (High Sample Rate $F_s$)')
ax1.set_ylabel('Amplitude')
ax1.grid(True, linestyle='--', alpha=0.6)
ax1.legend(loc='upper right')

out_t = np.arange(len(expected_outputs)) * DECIMATION_RATIO
ax2.plot(out_t, expected_outputs, color='navy', linewidth=2, label=f'Full Precision Output (28-bit)')
ax2.set_title('Decimated & Unscaled Output Signal (Low Sample Rate $F_s / R$)')
ax2.set_xlabel('Input Sample Index ($n$)')
ax2.set_ylabel('28-bit Accumulator Value')
ax2.grid(True, linestyle='--', alpha=0.6)
ax2.legend(loc='upper right')

plt.tight_layout()
plt.show()