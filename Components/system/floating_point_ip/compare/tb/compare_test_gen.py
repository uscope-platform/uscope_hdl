import random
import os
import struct
from decimal import Decimal, ROUND_HALF_EVEN

def compare(input):
    if input[0] > input[1]:
        return 1
    elif input[0] == input[1]:
        return 0
    else:
        return 2

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
        test_results.append(compare(rand)) 

    test_stimuli.append([0, 0])
    test_results.append(0)
    
    test_stimuli.append([0x80000000, 0])
    test_results.append(0)
        
    
    test_stimuli.append([0x7F800000, 0x7F800000])
    test_results.append(0)
        
    
    test_stimuli.append([0x7F800000, 0xFF800000])
    test_results.append(1)


    test_stimuli.append([0x7FC00000, 0x7FC00000])
    test_results.append(1)

        

    with open(base_dir + "/test_stimuli.mem", "w") as f:
        for stimulus in test_stimuli:
            str_a = struct.unpack('<I', struct.pack('<f', stimulus[0]))[0]
            str_b = struct.unpack('<I', struct.pack('<f', stimulus[1]))[0]
            f.write(f"{str_a:08x},{str_b:08x}\n")
    with open(base_dir + "/test_results.mem", "w") as f:
        for result in test_results:
            f.write(f"{result & 0xffffffff:08x}\n")