Processes and time
==================

Everything in a testbench runs in the SystemC kernel, which advances in delta cycles. In each delta the processes that
are ready run, and the signals they wrote take their new value only at the end of it. This is the same model as the
non blocking assignment of RTL, and the rules below follow from it.

Three kinds of process
----------------------

.. list-table::
   :header-rows: 1
   :widths: 22 30 48

   * - Kind
     - Started with
     - Used for
   * - thread
     - ``spawn``
     - The test sequence. It is the only kind that can wait, so every blocking call (``write``, ``idle``,
       ``wait_cycles``, ``drain``, ``reset_sequence``) must be made from one.
   * - method on every clock edge
     - ``spawn_every_cycle``
     - The monitor, the random ``ready`` of a slave and the window of a trace. It runs a function and returns.
   * - method on an event
     - ``spawn_on_event``
     - The trace, which writes a signal when it changes.

A method is a function the kernel calls on an event and that returns, so it costs a call and no context switch, which
is much cheaper than a thread. The monitor and the slave are methods for that reason, and the time of a test goes to
the model of the device.
The converter tests check about three million vectors per second on a laptop (5 million in 1.7 s on the machine they
were developed on).

A method started with ``spawn_every_cycle`` runs on the clock edges, after the simulation has started, so it always
sees a system in a defined state.

Sampling
--------

Everything that reads a bus reads it on a rising clock edge and sees the values from before the edge, because the
signals written at that edge have not taken effect yet. The monitor, the slave and the master all follow this rule,
so a testbench sees exactly what the flip-flops of the device see.

A transfer takes place on a rising edge where ``valid`` and ``ready`` are both high. The monitor reports the beat in
the cycle where that happens.

Driving
-------

The master writes its signals after a clock edge and the device sees them at the next one. ``write`` returns at the
edge where the beat was accepted. If the next ``write`` follows immediately, it drives ``valid`` again in the same
instant in which the previous call released it, and only the last value takes effect: ``valid`` stays high and one
beat is sent per cycle for as long as the slave is ready. A gap between beats is made with ``idle``.

The slave drives ``ready`` high all the time by default. With a probability below one it decides at every edge whether
``ready`` is high in the next cycle, with a seeded random generator, so a run is repeatable.

Time resolution
---------------

SystemC counts time in units of the time resolution, 1 ps by default, and Verilator checks that it matches the
``timeprecision`` of the model. ``sctb::init`` sets it to 1 ns, the one the RTL in this repository uses, and has to be
the first call of ``sc_main``.

Ending a test
-------------

``finish`` stops the simulation. ``run`` returns the exit code, which is 0 if no piece reported an error and 1
otherwise, so the test binary can be used directly from a script or from CI. A simulation that ends without ``finish``
having been called, or that reaches the timeout given to ``run``, is reported as an error too.

The reporter is one object that every piece reports to, and the exit code is its verdict. See :doc:`checking`.
