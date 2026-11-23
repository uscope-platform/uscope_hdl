Waveforms
=========

``trace`` writes the signals of the testbench to a file in the FST format, the compressed format that GTKWave and
Surfer open. It is on when the command line has ``--trace=<file>``. When it is off, ``add`` returns immediately, so
the signals can be listed in every test and the speed is that of the test alone.

How it works
------------

* Each signal added gets a variable in the file and a method process that is sensitive to the change of the signal.
  The process writes the new value with the simulation time, so a change is recorded at the time it happens.
* The window is checked once per clock cycle. ``--trace-start=<cycles>`` and ``--trace-cycles=<cycles>`` select the
  part of the simulation that is written, which is all of it by default. When the window opens, every signal is written
  with its current value, so every signal has a value from the start of the window. A window that starts after the end
  of the run never opens, and no file is written.
* The clock is always traced and sets what a cycle is.

The file is written by `libfstwriter <https://github.com/gtkwave/libfstwriter>`_, the writer Verilator also uses for
its traces. CMake fetches it the first time a test is configured, at a pinned commit, and compiles it with the library.
The first configure needs the network, zlib and lz4.

What is written
---------------

The signals of the testbench: the clock, the reset, the buses and any signal added by name. The ports of the device are
the bus signals, so the stream of the device is visible.

The data of a stream is written with the declared width of the stream, so a viewer can display a 32 bit float as one.

A long run makes a large file. Use a window to look at a part of it.

The signals inside the device
-----------------------------

The registers and the memories inside the device belong to the Verilated model, which has a tracer of its own.
``add_dut`` gives it the model and does the rest::

    #include "sctb/verilator.hpp"
    ...
    sctb::trace trace(options, clk);
    trace.add("reset", reset);
    trace.add(input);
    trace.add(output);
    trace.add_dut(dut);

The tracer writes the signals inside the device to a file of its own, and ``sctb::run`` merges that file into the
waveform of the testbench when the run ends, under the scopes Verilator wrote them in. The device signals are clipped
to the window of the testbench and given the value they have when the window opens, like the signals of the testbench.
The file of the device is only a step of the run, so it is removed.

The tracer is set up at the start of ``sctb::run``: the model is elaborated only then, and Verilator refuses to attach
a tracer once the simulation has dumped anything. ``add_dut`` does nothing when the trace is off, so the call can stay
in every test.

Merging reads the file of the device back, which needs a reader that the writer does not have, so CMake also fetches
`libfst <https://github.com/gtkwave/libfst>`_, the reference implementation of the format, and compiles it with the
library. The changes of the window are held in memory while the two files are read, so a window keeps that bounded as
well.

The test is verilated with ``TRACE_FST``. The tracer of Verilator writes FST through lz4, which its generated target
links by name, so the test adds the include and library directories of lz4 to its target. See
``Components/system/axi_stream/fifo/tb/systemc/CMakeLists.txt``.

Stages of the test
------------------

A waveform of a long test is hard to read without knowing where in the test each part is. ``define_stages`` gives the
trace the names of the stages, and ``stage`` marks the start of one::

    sctb::trace trace(options, clk);
    ...
    trace.define_stages({"reset", "pass_through", "hung_write"});
    ...
    trace.stage("pass_through");   // from the sequence, where the stage starts

The waveform has a signal, ``test_stage``, that changes at the call. The names are in the file as the names of its
values, so a viewer that reads the names of values displays the name of the stage, and one that does not shows its
number, the stages in the order they were given starting from 1, with 0 for before the first one. The
names have to be given before the test starts, as the signals of a waveform can not be added once it is being
written, and a stage that is not one of them is an error of the test. Both calls do nothing when the trace is off, so
they can stay in every test. The names of the stages go through the merge with the device, which drops the ones of the
device.
