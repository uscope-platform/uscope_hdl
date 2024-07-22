clearvars
input_bits = 16;
n_phases = 12;

max_int = 2^16-1;

divisors = 1./(1:n_phases);

fi_str = cell(12,1);
for i = 1:n_phases  
    fi_str(i) = {dec2hex(uint16(max_int/i))};
end
writecell(fi_str, "pmp_buck_divisors.mem", "FileType","text");


div = 7;
in = 5423;

check_res = in/div

fp_res = bitsrl(uint32(in*9362), 16)