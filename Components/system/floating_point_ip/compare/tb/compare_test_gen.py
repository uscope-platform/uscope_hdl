import random
import os
import struct
from decimal import Decimal, ROUND_HALF_EVEN


if __name__ == "__main__":
    base_dir =  os.path.dirname(os.path.abspath(__file__))
    test_stimuli = list()
    test_results = list()
    for i in range(1, 10000001):
        rand_f64 = [random.uniform(-2**5-1, 2**5-1), random.uniform(-2**5-1, 2**5-1)]
        rand = [0, 0]
        rand[0] = struct.unpack('<f', struct.pack('<f', rand_f64[0]))[0]
        rand[1] = struct.unpack('<f', struct.pack('<f', rand_f64[1]))[0]

        test_stimuli.append(rand)


    with open(base_dir + "/test_stimuli.mem", "w") as f:
        for stimulus in test_stimuli:
            str_a = struct.unpack('<I', struct.pack('<f', stimulus[0]))[0]
            str_b = struct.unpack('<I', struct.pack('<f', stimulus[1]))[0]
            f.write(f"{str_a:08x}{str_b:08x}\n")
