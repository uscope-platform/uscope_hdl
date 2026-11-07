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
  with its current value, so every signal has a value from the start of the window.
* The clock is always traced and sets what a cycle is.

The file is written by `libfst <https://github.com/gtkwave/libfst>`_, a plain C library. CMake fetches it the first
time a test is configured, at a pinned commit, and compiles it with the library. The first configure needs the network
and zlib.

What is written
---------------

The signals of the testbench: the clock, the reset, the buses and any signal added by name. The ports of the device are
the bus signals, so the stream of the device is visible. The registers inside the device belong to the Verilated model,
which has a tracer of its own.

The data of a stream is written with the declared width of the stream, so a viewer can display a 32 bit float as one.

A long run makes a large file. Use a window to look at a part of it.
