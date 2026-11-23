AXI
===

.. cpp:namespace:: sctb

``axi``. The full AXI4 interface, the counterpart of the ``AXI`` interface and of ``axi_full_bfm`` in ``Common``. It
has five channels, each with its own ``valid`` and ``ready``, and a transfer happens on a rising clock edge where both
are high: the write address (``aw``), the write data (``w``), the write response (``b``), the read address (``ar``) and
the read data (``r``). A test includes ``sctb/axi.hpp``, or the parts from ``sctb/axi/``.

Both ends are provided: a master that drives a model that is an AXI slave, and a slave that answers a model that is an
AXI master, with the plumbing that connects them, and a monitor that hands whole transactions to a scoreboard.

Bus
---

.. cpp:enum-class:: axi_response

   The value of ``bresp`` and ``rresp``: ``okay``, ``exokay``, ``slverr`` and ``decerr``. ``to_string`` gives the name.

.. cpp:class:: axi_bus

   The 44 signals of the interface. The data and the address signals are 64 bits and the others 32, so that one class
   serves every width of interface. The width of the interface is how many of those bits are used, the ones above are
   zero. The signals have the names of the interface in lower case, ``<name>_awvalid``, ``<name>_wdata`` and so on, so
   they show up with those names in traces.

   .. cpp:function:: explicit axi_bus(const std::string &name, uint32_t data_bits = 32, uint32_t addr_bits = 32, uint32_t id_bits = 1, uint32_t user_bits = 1)

      The data is 8, 16, 32 or 64 bits, the address from 1 to 64, the id and the user from 1 to 32. The width of the
      data is also the size of every beat of a transfer of the master, which always uses the full width of the bus.

   .. cpp:function:: const std::string &get_name() const
   .. cpp:function:: uint32_t get_data_bits() const
   .. cpp:function:: uint32_t get_addr_bits() const
   .. cpp:function:: uint32_t get_id_bits() const
   .. cpp:function:: uint32_t get_user_bits() const

.. cpp:function:: void connect_axi(axi_bus &bus, const sc_module &model, const std::string &interface_name)

   Connects the ports of a model to a bus, the same way :cpp:func:`connect_stream` does for a stream: the ports are
   found by name, they are ``<interface_name>_awvalid``, ``_awaddr``, ``_wdata``, ``_rready`` and so on, and each of
   them can be an input or an output. A port can be narrower than the signal, and a value it can not hold is reported.
   A missing port stops the simulation at startup with a message that names it.

   Verilator can not have an interface port on the top level module, so the model that a test connects to is a shim
   with those plain ports around the real module. See ``Components/system/axi_full/axi_memory/tb/systemc``.

Master
------

.. cpp:class:: axi_master

   Drives a bus. The calls block until the transaction is over, so they can be made from a thread, like the tasks of
   ``axi_full_bfm``. They return the response of the device, the worst one of the beats for a burst. A transfer is an
   INCR burst of the full width of the bus.

   The address and the first beat of a write go out together and the device takes them in either order, the beats follow
   as fast as ``wready`` allows, and ``bready`` is raised once the last one is taken. A read raises ``rready`` with the
   address and collects the beats. ``rlast`` is checked on every beat.

   One transaction is in flight at a time in each direction. The write channels and the read channels are independent,
   so they can be driven at the same time, but a signal has one writer in SystemC: a thread that writes and a thread that
   reads have to be the same ones for the whole test, and one thread can not take over the writes of another.

   .. cpp:function:: axi_master(axi_bus &bus, const clock &clk)

   .. cpp:function:: axi_response write(uint64_t address, uint64_t data, uint64_t strobe = ~0)

      One beat. The strobe says which bytes of the data are written, all of them by default.

   .. cpp:function:: axi_response write_burst(uint64_t address, const std::vector<uint64_t> &data, uint64_t strobe = ~0)

      The beats go to consecutive addresses. The strobe applies to every beat.

   .. cpp:function:: axi_response read(uint64_t address, uint64_t &data)

   .. cpp:function:: axi_response read_burst(uint64_t address, uint32_t beats, std::vector<uint64_t> &data)

   A burst of the wrong size, an address or data that does not fit the interface, and a burst that crosses a 4 KB
   boundary are mistakes of the test: they are reported as errors, nothing is put on the bus and the call returns
   ``slverr``. A burst has from 1 to 256 beats.

   .. cpp:function:: void set_id(uint32_t id)
   .. cpp:function:: void set_user(uint32_t user)

      The id and the user the next transactions carry, 0 by default.

   .. cpp:function:: void idle(int64_t cycles = 1)

      Waits for a number of cycles. It does not touch the bus, so it does not disturb a transaction of the other direction.

Slave
-----

.. cpp:class:: axi_slave

   Answers a bus the device drives, the counterpart of :cpp:class:`axi_master` and of ``axis_slave``. It takes the
   addresses and the write data, answers the writes, and returns the data of a memory that starts as zeros and holds what
   was written to it. One write and one read are in flight at a time, and the two directions are independent. It runs on
   every clock edge and does not need a thread.

   What it does is set by the test while it runs, which is how a test plays a slave that misbehaves.

   .. cpp:function:: axi_slave(const std::string &name, axi_bus &bus, const clock &clk)

   .. cpp:function:: void set_hung(bool hung)

      While it is on the slave raises no ready and no valid. What it has already accepted is kept and the transaction
      goes on when it is turned off.

   .. cpp:function:: void set_latency(uint32_t cycles)

      Cycles between the last beat of a write and its response, and between a read address and the first beat. 1 by default.

   .. cpp:function:: void set_response(axi_response response)

      The response of the transactions that come next, okay by default. A write that is not answered with okay does
      not change the memory, and a read gives zeros.

   .. cpp:function:: void add_write_listener(std::function<void(const axi_write &)> listener)
   .. cpp:function:: void add_read_listener(std::function<void(const axi_read &)> listener)

      Called with the write once its last beat is in, and with the read request in the cycle its address is taken.
      ``axi_write`` has the ``id``, the ``address``, and the ``data`` and ``strobe`` of every beat, ``axi_read`` the
      ``id``, the ``address`` and the number of ``beats``.

   .. cpp:function:: uint64_t peek(uint64_t address) const
   .. cpp:function:: void poke(uint64_t address, uint64_t data)

      The memory, by the address of a beat. It is sparse, nothing is checked against a size.

.. cpp:class:: axi_responder

   The slave end of an interface of the device that is an AXI master: the bus and a slave, like ``axis_sink`` is for a
   stream. ``connect``, ``get_bus`` and ``get_slave`` are as in ``axi_driver``, and ``trace::add`` takes it.

Transactions and monitor
------------------------

.. cpp:struct:: axi_write

   A write as a whole: the ``id``, the ``address``, the ``data`` and the ``strobe`` of every beat, and the ``response``.

.. cpp:struct:: axi_read

   A read as a whole: the ``id``, the ``address``, the number of ``beats`` asked for, the ``data`` that came back and the
   ``response``, which is the worst one of the beats. What the slave hands its listeners is the request alone, with no
   data.

.. cpp:function:: std::string compare(const axi_write &expected, const axi_write &actual)
.. cpp:function:: std::string compare(const axi_read &expected, const axi_read &actual)

   What differs, empty when the transactions are the same, which is what the comparison of a scoreboard returns.

.. cpp:class:: axi_monitor

   Watches an interface and hands its listeners the transactions as wholes. It only looks, so it can be on either side of
   the device, and it runs on every clock edge without a thread.

   A write is reported when its response is taken, with the address from ``aw``, the beats from ``w`` and the response
   from ``b``, which can arrive in either order. A read is reported when its last beat is taken. The channels of a
   transaction are matched in the order they arrive, which is what a master and a slave that keep their transactions in
   order do. What can not be a valid transaction is reported as an error: a response nobody asked for, or a burst of
   another length than its address said.

   .. cpp:function:: axi_monitor(const std::string &name, axi_bus &bus, const clock &clk)
   .. cpp:function:: void add_write_listener(std::function<void(const axi_write &)> listener)
   .. cpp:function:: void add_read_listener(std::function<void(const axi_read &)> listener)

   The scoreboard does not look inside its beat, so one of transactions needs nothing more:

   .. code-block:: cpp

       sctb::scoreboard<sctb::axi_write> writes("writes", [](const sctb::axi_write &expected, const sctb::axi_write &actual) {
           return sctb::compare(expected, actual);
       }, clk.get_period());
       monitor.add_write_listener(writes, &sctb::scoreboard<sctb::axi_write>::observe);
       // the sequence says what the monitor has to see before it sends it
       writes.expect(expected_write);
       master.write_burst(expected_write.address, expected_write.data);

Driver
------

.. cpp:class:: axi_driver

   The master end of an interface of the device: the bus and a master, which is all the plumbing a device that is an AXI
   slave needs, like ``axis_source`` is for a stream.

   .. cpp:function:: axi_driver(const std::string &name, const clock &clk, uint32_t data_bits = 32, uint32_t addr_bits = 32, uint32_t id_bits = 1, uint32_t user_bits = 1)
   .. cpp:function:: void connect(const sc_module &model)
   .. cpp:function:: const axi_bus &get_bus() const
   .. cpp:function:: axi_master &get_master()

   ``trace::add`` takes a driver or a bus, and writes the 44 signals with the widths of the interface.

.. code-block:: cpp

    sctb::axi_driver axi("axi", clk, 32, 32);
    axi.connect(dut);

    sctb::trace trace(options, clk);
    trace.add(axi);

    auto &master = axi.get_master();
    master.write(0x100, 0xcafe);
    uint64_t data;
    master.read(0x100, data);
