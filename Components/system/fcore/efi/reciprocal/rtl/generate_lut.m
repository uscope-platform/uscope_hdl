clearvars

inputs = 1:1:512;
result = 1./inputs;

fi_res = round(result*(2^16-1));

hex_res = dec2hex(fi_res);

writematrix(hex_res, "rec_lut.mem", "FileType","text");