The Verilator boundary
======================

The device under test is a Verilated model, which is a SystemC module with ``sc_in`` and ``sc_out`` ports. The
testbench connects to it through those ports. This page is about the decisions that come from what Verilator and the
SystemC installation work.

The shim
--------

The top module of a Verilated model has plain ports, and the modules in this repository have ``axi_stream`` interface
ports. The device is instantiated in a wrapper with plain ports, the *shim*, which is a few ``assign`` statements and a
module instance kept next to the test.

The ports of a shim follow one convention: for each stream, ``<stream>_valid``, ``_ready``, ``_data``, ``_dest``,
``_user`` and ``_tlast``, plus ``clock`` and ``reset``. A stream called ``in`` has the ports ``in_valid``, ``in_ready``
and so on.

Connecting by name
------------------

``connect_stream`` finds the ports of the model by those names. SystemC registers every port as ``<model>.<port>``,
and the function looks each one up with ``sc_find_object`` and binds it to the signal of the bus, whether the port is
an input or an output. It checks every port: a port that is missing, or of another type than the signal, stops the
simulation at startup with a message that names the port. The check runs before anything is simulated.

This is what makes a stream a single call, ``axis_source("in", clk, 32)`` followed by ``connect(dut)``, whichever way
the stream goes.

Widths
------

Verilator gives a one bit port the type ``bool``, and otherwise the narrowest of ``uint32_t`` and ``uint64_t`` that
holds it, or ``uint8_t`` and ``uint16_t`` as well with ``--pins-uint8``. A bus that followed the width of the stream
would need to be a template, and so would everything that uses one: the master, the monitor, the slave, the endpoints
and the trace. To keep the library free of that, the data signal of a bus is always 64 bits and dest and user are 32.

``connect_stream`` looks at the type of each port and, when it is narrower than the signal, binds it to a small
adapter instead of to the signal. The adapter implements the signal interface and forwards to the real signal, so it
needs no process and adds no delta cycle: what the model reads is the low bits of the signal, and what it writes is
zero extended into it. The checks of the signal, such as the one that has one writer, still apply. The shim therefore
only flattens the interface ports, without zero extending anything, and can leave the parameters and other ports as
they are.

The width the stream really has is declared when the stream is made, ``axis_source("in", clk, 32)``, with the width of
dest and user after it when they are not 32. It is used for what is visible to a person: the waveform shows the values
with that width, so a 32 bit float can be displayed as one, and a beat that does not fit it is reported as an error of
the test. A port can not tell the width a stream has, only the type that holds it, so a declared width that is not the
width of the design is a mistake of the test. A value that the port can not hold is reported as an error by the
adapter.

A stream wider than 64 bits needs its own signal type. Verilator gives it a ``sc_bv`` port, which ``connect_stream``
refuses with a message that names the port.

Timing and ``interfaces_no_timing.sv``
--------------------------------------

The ``axi_stream`` interface in ``Common/interfaces.sv`` has tasks that use ``wait`` and ``#`` delays. Verilator builds
them with ``--timing``, which uses C++20 coroutines and so needs a SystemC library built with C++20. A testbench is built
with the standard of the SystemC it links, and the Homebrew SystemC is built with C++17.

``Common/interfaces_no_timing.sv`` has the same signals, parameters and modports without the tasks. The SystemC builds
use it with ``--no-timing``.

Other details
-------------

* ``verilate()`` names the model after the first source unless told otherwise, so the tests pass
  ``PREFIX V<top>`` and the header is ``V<module>_shim.h``.
* The tests default to ``Release``, which simulates about three times faster than the empty build type of a plain
  configure.
* Verilator reads a comment that starts with its own name as a pragma, so the comments in a shim start with something
  else.
* Verilator implements ``shortreal`` as a 64 bit ``real``, so ``$bitstoshortreal`` and ``$shortrealtobits`` work on
  64 bits. The floating point modules are checked against the C++ ``float`` and ``double`` of the testbench.
