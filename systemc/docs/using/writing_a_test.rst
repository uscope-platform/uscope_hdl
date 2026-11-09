Writing a test
==============

This follows the test of ``fp_fp32_to_fp64``, a pipelined converter with one stream in and one stream out. The code
shown is included from the repository, so it is what runs. The files are in
``Components/system/floating_point_ip/fp32_to_fp64/tb/systemc``.

1. The shim
-----------

The device has ``axi_stream`` interface ports and a Verilated top module has plain ports, so the device is instantiated
in a wrapper with plain ports named ``<stream>_valid``, ``_ready``, ``_data``, ``_dest``, ``_user`` and ``_tlast``.
The ports of the shim have the width of the streams, ``sctb`` adapts to them, see :doc:`/architecture/verilator_boundary`.

.. literalinclude:: ../../../Components/system/floating_point_ip/fp32_to_fp64/tb/systemc/fp_fp32_to_fp64_shim.sv
   :language: systemverilog
   :start-at: // fp_fp32_to_fp64 with plain ports

2. The build
------------

.. literalinclude:: ../../../Components/system/floating_point_ip/fp32_to_fp64/tb/systemc/CMakeLists.txt
   :language: cmake
   :start-at: find_package(verilator

``verilate()`` comes with Verilator and turns the RTL and the shim into a SystemC model. ``add_subdirectory`` of the
``systemc`` folder provides the library as the target ``sctb``.

3. The model of the device
--------------------------

A plain class that says what the device does. For this test it has:

* ``generate(rng)``: a random input, biased towards the cases that matter (denormals, infinities, NaNs, the edges of
  the exponent range), because random words almost never hit them
* ``reference(input)``: the expected output bits, here the ``float`` to ``double`` conversion of the C++ compiler
* ``matches(got, expected)`` and ``compare(...)``: what counts as equal and how a difference is described
* ``classify(input)`` and ``get_class_names()``: which coverage bin an input belongs to

4. The sequence
---------------

A class with a member function, started as a thread. It resets the device, sends the inputs, says for each one what
must come out, waits for the pipeline to empty and runs the end of test checks.

.. literalinclude:: ../../../Components/system/floating_point_ip/fp32_to_fp64/tb/systemc/test.cpp
   :language: cpp
   :start-at: /// Reset, a stream
   :end-before: int sc_main

5. The wiring
-------------

.. literalinclude:: ../../../Components/system/floating_point_ip/fp32_to_fp64/tb/systemc/test.cpp
   :language: cpp
   :start-at: int sc_main

In order: the clock and the reset, the device and its connection to the two streams, the waveform, the checking, and the
sequence started as a thread. The only callback is ``output.add_listener(scoreboard, ...)``, which hands each result
that comes out to the scoreboard.
