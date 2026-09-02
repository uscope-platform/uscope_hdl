proc generate_wrappers {path part} {
    set_part $part
    source $path/adder.tcl
    adder adder_sv 5
    source $path/itf.tcl
    itf itf_sv 3
    source $path/fti.tcl
    fti fti_sv 3
    source $path/multiplier.tcl
    multiplier mul_sv 5
    source $path/reciprocal.tcl
    multiplier rec_sv 5
    
}

