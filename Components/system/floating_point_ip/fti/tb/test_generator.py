import random
import os
import struct
from decimal import Decimal, ROUND_HALF_EVEN

def round_half_to_even(f):
    return int(Decimal(str(f)).quantize(Decimal('1'), rounding=ROUND_HALF_EVEN))

if __name__ == "__main__":
    base_dir =  os.path.dirname(os.path.abspath(__file__))
    test_stimuli = list()
    test_results = list()
    for i in range(1, 10000001):
        rand_f64 = random.uniform(-2**5-1, 2**5-1)
        rand = struct.unpack('<f', struct.pack('<f', rand_f64))[0]

        test_stimuli.append(rand)
        test_results.append(round_half_to_even(rand)) 
        
    with open(base_dir + "/test_stimuli.mem", "w") as f:
        for stimulus in test_stimuli:
            f.write(f"{struct.unpack('<I', struct.pack('<f', stimulus))[0]:08x}\n")
    with open(base_dir + "/test_results.mem", "w") as f:
        for result in test_results:
            f.write(f"{result & 0xffffffff:08x}\n")