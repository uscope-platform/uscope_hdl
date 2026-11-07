Recipes
=======

A directed sequence
-------------------

The body of a sequence is ordinary procedural code. It lives in a member function of a class and is started with
``sctb::spawn("sequence", object, &class::run)``.

.. code-block:: cpp

    void run() {
        sctb::reset_sequence(reset, clk);

        master.write(0x3f800000, /*dest*/ 1, /*user*/ 2);   // returns when the beat is accepted
        scoreboard.expect({0x3ff0000000000000, 1, 2, false});
        master.idle(5);
        master.write(0x40000000, 1, 2, true);
        scoreboard.expect({0x4000000000000000, 1, 2, true});

        sctb::drain(scoreboard, clk, 20);
        scoreboard.finish();
        sctb::finish();
    }

A sink that stalls
------------------

The third argument of ``axis_sink`` is the data width and the fourth is the probability that ``ready`` is high in a
cycle:

.. code-block:: cpp

    sctb::axis_sink output("out", clk, 64, 0.5);

The device sees back pressure, and so does the master. Leave out ``check_throughput`` and ``check_latency``, which assume
a sink that is always ready.

A device with several streams in
--------------------------------

Make one ``axis_source`` for each and ``connect`` them all. To put a beat on every stream in the same cycle, call
``put`` on each master and wait one cycle:

.. code-block:: cpp

    a.put(operand_a, dest, user);
    b.put(operand_b);
    op.put(subtract);
    clk.wait_cycles(1);

``put`` returns at once and ignores ``ready``, so it also drives a stream that has no back pressure. ``write`` is
``put`` followed by the wait for ``ready``. The test of the adder model in
``Components/system/fcore/alu/ip/tb/systemc/adder`` drives three input streams this way.

A different kind of check
-------------------------

The scoreboard compares whatever the test gives it, so the expected beat can depend on anything the model knows. A
device with state keeps the state in the model and calls ``expect`` with what the model says. A device that
produces a result per several inputs calls ``expect`` once per result.

A new protocol
--------------

``axis/`` is the model: a bus with named signals, a beat, a master, a slave, a monitor, a function that connects a
model to a bus, and an endpoint that bundles a bus with its master or slave. A new protocol is the same set in a new
folder next to it. The SystemVerilog BFMs in ``Components/Common`` (``axi_lite_BFM.svh``, ``axi_full_bfm.svh``) are the
reference for the operations: ``write(address, data)`` and ``read(address)`` should be calls that block until the
transaction is done.

Rules to keep:

* Blocking calls wait on ``clk.posedge()`` and can only be called from a thread.
* Monitors and slaves are methods started with ``spawn_every_cycle`` and read the values from before the edge.
* What a monitor sees goes to listeners. A device's reference model is called by the test from its own code.

A new device
------------

A shim, a ``CMakeLists.txt`` copied from a similar test, a model, a sequence and a ``sc_main``. When a third test
repeats a piece of wiring, move that piece into the library as a function or a small class with one job, as
``checks`` was.
