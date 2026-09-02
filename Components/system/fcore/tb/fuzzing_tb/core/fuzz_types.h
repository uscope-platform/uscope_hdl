#ifndef __FUZZ_TYPES_H__
#define __FUZZ_TYPES_H__

struct fuzzing_package {
    uint32_t reg_file[64];
    uint32_t instructions[4096];
};

struct fuzz_result {
    uint32_t reg_file[64];
};


#endif // __FUZZ_TYPES_H__