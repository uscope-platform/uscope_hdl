import math


num_entries = 512

# The full cycle would have 4 * num_entries = 2048 points.
# The angle for each step is calculated based on this full cycle resolution.
angle_step = (2 * math.pi) / (4 * num_entries)

lut = list()

for i in range(num_entries):
    # Calculate the angle for the current step.
    angle = i * angle_step
    
    # Calculate the cosine of the angle.
    value = math.cos(angle)
    
    # Scale the cosine value (from 1.0 down to 0.0) to the 16-bit unsigned
    # integer range (65535 down to 0). The result is rounded to the
    # nearest integer.
    scaled_value = round(value * 65535)
    
    # Ensure the value is an integer for formatting.
    int_value = int(scaled_value)
    
    # Format the integer value as a 4-digit hexadecimal string,
    # ensuring uppercase letters to match the file.
    hex_value = f'{int_value:04X}'
    
    lut.append(hex_value)


with open("lut.mem", "w") as f:
    for i in lut:
        f.write(f"{i}\n")