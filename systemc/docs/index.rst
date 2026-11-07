sctb
====

``sctb`` is a C++17 library for writing testbenches in SystemC for modules simulated with Verilator. It is compiled
once as a static library and linked into each test.

It provides the pieces a testbench is made of:

* a bus that bundles the signals of a protocol, and blocking master and slave BFMs that a sequence calls like tasks
* monitors, a scoreboard that checks results in order and measures latency, and functional coverage
* end of test checks, an error reporter whose verdict is the exit code, and waveform tracing

A test wires these together in ``sc_main``, so the code of a test shows what is connected to what.

.. toctree::
   :maxdepth: 1
   :caption: Architecture

   architecture/overview
   architecture/processes_and_time
   architecture/checking
   architecture/verilator_boundary
   architecture/waveforms

.. toctree::
   :maxdepth: 1
   :caption: Using sctb

   using/getting_started
   using/writing_a_test
   using/recipes

.. toctree::
   :maxdepth: 1
   :caption: Reference

   api/index
