AXI stream
==========

.. cpp:namespace:: sctb

``axis``. A transfer happens on a rising clock edge where ``valid`` and ``ready`` are both high. This is the
counterpart of the ``axi_stream`` interface and of ``axis_BFM`` in ``Common``. Data is 64 bits wide, a narrower
stream is zero extended by the shim.

Bus and transfer
----------------

.. cpp:struct:: axis_beat

   One transfer.

   .. cpp:member:: uint64_t data
   .. cpp:member:: uint32_t dest
   .. cpp:member:: uint32_t user
   .. cpp:member:: bool tlast

   .. cpp:function:: bool same_sideband(const axis_beat &other) const

      Whether ``dest``, ``user`` and ``tlast`` are the same, what a device that only transforms the data has to
      carry through.

.. cpp:class:: axis_bus

   The signals of a stream, the interface. The data signal is always 64 bits so that one set of classes serves every
   the width of a stream. The width of the stream is how many of those bits are used, the ones above it are zero.

   .. cpp:function:: explicit axis_bus(const std::string &name, uint32_t data_bits = 64)

      The signals are called ``<name>_valid``, ``<name>_ready``, ``<name>_data``, ``<name>_dest``, ``<name>_user``
      and ``<name>_tlast``, so they show up with those names in traces. The width is from 1 to 64.

   .. cpp:function:: uint32_t get_data_bits() const

      The width of the stream. The waveform shows the data with it, so that a viewer can display a 32 bit float
      as one.

   .. cpp:member:: sc_signal<bool> valid
   .. cpp:member:: sc_signal<bool> ready
   .. cpp:member:: sc_signal<uint64_t> data
   .. cpp:member:: sc_signal<uint32_t> dest
   .. cpp:member:: sc_signal<uint32_t> user
   .. cpp:member:: sc_signal<bool> tlast

.. cpp:function:: void connect_stream(axis_bus &bus, const sc_module &model, const std::string &stream)

   Connects the ports of a model to a bus. The ports are looked up in the model by name, they are the ones called
   ``<stream>_valid``, ``_ready``, ``_data``, ``_dest``, ``_user`` and ``_tlast``, and each of them can be an input or
   an output, so the same call connects a stream the model receives and one it produces:

   .. code-block:: cpp

       sctb::connect_stream(env.get_input_bus(), dut, "in");
       sctb::connect_stream(env.get_output_bus(), dut, "out");

   A port that is missing, or that is not of the type of the signal (the data of a stream is 64 bits wide), stops the
   simulation at startup with a message that names the port.

Master
------

.. cpp:class:: axis_master

   Drives a bus. The calls block, so they can be made from a thread like the tasks of ``axis_BFM`` are called from an
   ``initial`` block.

   .. cpp:function:: axis_master(axis_bus &bus, const clock &clk)

      Drives the bus idle.

   .. cpp:function:: void write(const axis_beat &beat)

      Returns when the beat has been accepted. Consecutive calls send one beat per cycle as long as the slave is
      ready. A beat with bits set above the width of the stream is reported as an error, it is a mistake of the test.

   .. cpp:function:: void write(uint64_t data, uint32_t dest = 0, uint32_t user = 0, bool tlast = false)

   .. cpp:function:: void idle(int64_t cycles = 1)

      Leaves the bus idle for a number of cycles.

Slave
-----

.. cpp:class:: axis_slave

   Answers a bus with ``ready`` and tells its listeners what it received.

   .. cpp:function:: axis_slave(const std::string &name, axis_bus &bus, const clock &clk, double ready_probability = 1.0, uint64_t seed = 1)

      ``ready_probability`` is the chance that ``ready`` is high in a cycle. With 1 it is always high, and the slave
      costs no simulation time. Below 1 it is drawn every cycle from a generator that starts from ``seed``, so the
      back pressure is random but repeatable.

   .. cpp:function:: void add_listener(std::function<void(const axis_beat &)> listener)

      Called with every transfer the slave accepted, in the cycle it happens.

   .. cpp:function:: template<typename T> void add_listener(T &object, void (T::*method)(const axis_beat &))

      The listener is a member function of an object.

Monitor
-------

.. cpp:class:: axis_monitor

   Watches a bus and reports every transfer. It runs on every rising edge and reads the values from before the edge.

   .. cpp:function:: axis_monitor(const std::string &name, axis_bus &bus, const clock &clk)

   .. cpp:function:: void add_listener(std::function<void(const axis_beat &)> listener)

      Called with every transfer, in the cycle it happens, in the order the listeners were added.

   .. cpp:function:: template<typename T> void add_listener(T &object, void (T::*method)(const axis_beat &))

      The listener is a member function of an object.

Stream endpoints
----------------

The parts above wired up for the common case, so that a test creates a stream in one line. They work with any
device.

.. cpp:class:: axis_source

   The sending end of a stream of the device: the bus and a master that drives it.

   .. cpp:function:: axis_source(const std::string &name, const clock &clk, uint32_t data_bits = 64)

      The bus signals are called ``<name>_valid`` and so on, as in :cpp:class:`axis_bus`.

   .. cpp:function:: void connect(const sc_module &model)

      Connects the ports of the model called ``<name>_valid`` and so on to the bus, see :cpp:func:`connect_stream`.

   .. cpp:function:: axis_master &get_master()

.. cpp:class:: axis_sink

   The receiving end of a stream of the device: the bus and a slave that answers it.

   .. cpp:function:: axis_sink(const std::string &name, const clock &clk, uint32_t data_bits = 64, double ready_probability = 1.0, uint64_t seed = 1)

   .. cpp:function:: void connect(const sc_module &model)

   .. cpp:function:: axis_slave &get_slave()

   .. cpp:function:: void add_listener(std::function<void(const axis_beat &)> listener)

      Called with every transfer the sink received.

   .. cpp:function:: template<typename T> void add_listener(T &object, void (T::*method)(const axis_beat &))

      The listener is a member function of an object.
