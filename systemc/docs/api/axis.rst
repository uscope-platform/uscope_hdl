AXI stream
==========

.. cpp:namespace:: sctb

``axis``. A transfer happens on a rising clock edge where ``valid`` and ``ready`` are both high. This is the
counterpart of the ``axi_stream`` interface and of ``axis_BFM`` in ``Common``. The signals of the bus are 64 bits
wide for the data and 32 for dest and user, and the ports of the model can be narrower, see :cpp:func:`connect_stream`.

Types of the beat
-----------------

The pieces of a stream are templates on the types of the beat: the data, the dest and the user.

.. code-block:: cpp

    template<typename data_type = uint64_t, typename dest_type = uint32_t, typename user_type = uint32_t>
    struct axis_beat;

The defaults are the ones of the signals of :cpp:class:`axis_bus`, so the beat of a bus is written ``axis_beat<>``.
A stream whose data is a word says so once, ``axis_beat<uint32_t>``, and the master, slave, monitor and endpoints that
carry it are the same specialization, written ``axis_master<uint32_t>``, ``axis_source<uint32_t>`` and so on. The
widths are still what the stream is made with: the type of the beat says what the test holds the data in, the
``data_bits`` of the bus says how many bits of it the device sees.

The library is built for two of them, ``axis_beat<>`` and ``axis_beat<uint32_t, uint32_t, uint32_t>``. The
definitions of the templates are in ``systemc/src``, so another one is a line in each of the files that define them:

.. code-block:: cpp

    template class axis_master<uint16_t, uint8_t, uint32_t>;

in ``axis/master.cpp``, ``axis/slave.cpp``, ``axis/monitor.cpp`` and ``axis/endpoints.cpp`` for the stream, and
``scoreboard.cpp`` and ``checks.cpp`` for the checking, next to the ones that are already there.

Bus and transfer
----------------

.. cpp:struct:: template<typename data_type = uint64_t, typename dest_type = uint32_t, typename user_type = uint32_t> axis_beat

   One transfer. ``axis_beat<>`` is the one of a bus, ``axis_beat<uint32_t>`` the one of a stream whose data is a word.

   .. cpp:member:: data_type data
   .. cpp:member:: dest_type dest
   .. cpp:member:: user_type user
   .. cpp:member:: bool tlast

   .. cpp:function:: bool same_sideband(const axis_beat &other) const

      Whether ``dest``, ``user`` and ``tlast`` are the same, what a device that only transforms the data has to
      carry through.

.. cpp:class:: axis_bus

   The signals of a stream, the interface. The data signal is always 64 bits, and dest and user 32, so that one set of
   classes serves every width of a stream. The width of the stream is how many of those bits are used, the ones above
   it are zero. It is not a template: the widths are the ones the stream is made with, so that a test has one type of
   bus whatever the streams of its device are.

   .. cpp:function:: explicit axis_bus(const std::string &name, uint32_t data_bits = 64, uint32_t dest_bits = 32, uint32_t user_bits = 32)

      The signals are called ``<name>_valid``, ``<name>_ready``, ``<name>_data``, ``<name>_dest``, ``<name>_user``
      and ``<name>_tlast``, so they show up with those names in traces. The width of the data is from 1 to 64, the one
      of dest and user from 1 to 32.

   .. cpp:function:: uint32_t get_data_bits() const

      The width of the stream. The waveform shows the data with it, so that a viewer can display a 32 bit float
      as one.

   .. cpp:function:: uint32_t get_dest_bits() const
   .. cpp:function:: uint32_t get_user_bits() const

      The widths of dest and user, used in the same way.

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

   ``valid``, ``ready`` and ``tlast`` have to be one bit. ``_data``, ``_dest`` and ``_user`` can be any width that
   Verilator gives a ``bool``, ``uint8_t``, ``uint16_t``, ``uint32_t`` or ``uint64_t`` port: a port that is narrower
   than the signal is connected through an adapter that forwards to it, with no process and no delta cycle in
   between. A value that the port can not hold is reported as an error instead of being cut off.

   A port that is missing, or of a type that is not one of those (a port wider than 64 bits is a ``sc_bv``), stops the
   simulation at startup with a message that names the port.

Master
------

.. cpp:class:: template<typename data_type = uint64_t, typename dest_type = uint32_t, typename user_type = uint32_t> axis_master

   Drives a bus. The calls block, so they can be made from a thread like the tasks of ``axis_BFM`` are called from an
   ``initial`` block.

   .. cpp:function:: axis_master(axis_bus &bus, const clock &clk)

      Drives the bus idle.

   .. cpp:function:: void write(const axis_beat<data_type, dest_type, user_type> &beat)

      Returns when the beat has been accepted. Consecutive calls send one beat per cycle as long as the slave is
      ready. A beat with bits set above the width of the stream is reported as an error, it is a mistake of the test.

   .. cpp:function:: void write(uint64_t data, uint32_t dest = 0, uint32_t user = 0, bool tlast = false)

   .. cpp:function:: void put(const axis_beat<data_type, dest_type, user_type> &beat)

      Puts the beat on the bus for the next clock edge and returns at once, whatever ``ready`` is. The caller waits for
      the edge, for example with :cpp:func:`clock::wait_cycles`. It is for a stream that has no back pressure, and for
      putting a beat on several streams in the same cycle. A beat with bits set above the width of the stream is
      reported as an error, as with ``write``.

   .. cpp:function:: void put(uint64_t data, uint32_t dest = 0, uint32_t user = 0, bool tlast = false)

   .. cpp:function:: void idle(int64_t cycles = 1)

      Leaves the bus idle for a number of cycles.

Slave
-----

.. cpp:class:: template<typename data_type = uint64_t, typename dest_type = uint32_t, typename user_type = uint32_t> axis_slave

   Answers a bus with ``ready`` and tells its listeners what it received.

   .. cpp:function:: axis_slave(const std::string &name, axis_bus &bus, const clock &clk, double ready_probability = 1.0, uint64_t seed = 1)

      ``ready_probability`` is the chance that ``ready`` is high in a cycle. With 1 it is always high, and the slave
      costs no simulation time. Below 1 it is drawn every cycle from a generator that starts from ``seed``, so the
      back pressure is random but repeatable.

   .. cpp:function:: void add_listener(std::function<void(const axis_beat<data_type, dest_type, user_type> &)> listener)

      Called with every transfer the slave accepted, in the cycle it happens.

   .. cpp:function:: template<typename T> void add_listener(T &object, void (T::*method)(const axis_beat<data_type, dest_type, user_type> &))

      The listener is a member function of an object.

Monitor
-------

.. cpp:class:: template<typename data_type = uint64_t, typename dest_type = uint32_t, typename user_type = uint32_t> axis_monitor

   Watches a bus and reports every transfer. It runs on every rising edge and reads the values from before the edge.

   .. cpp:function:: axis_monitor(const std::string &name, axis_bus &bus, const clock &clk)

   .. cpp:function:: void add_listener(std::function<void(const axis_beat<data_type, dest_type, user_type> &)> listener)

      Called with every transfer, in the cycle it happens, in the order the listeners were added.

   .. cpp:function:: template<typename T> void add_listener(T &object, void (T::*method)(const axis_beat<data_type, dest_type, user_type> &))

      The listener is a member function of an object.

Stream endpoints
----------------

The parts above wired up for the common case, so that a test creates a stream in one line. They work with any
device.

.. cpp:class:: template<typename data_type = uint64_t, typename dest_type = uint32_t, typename user_type = uint32_t> axis_source

   The sending end of a stream of the device: the bus and a master that drives it.

   .. cpp:function:: axis_source(const std::string &name, const clock &clk, uint32_t data_bits = 64, uint32_t dest_bits = 32, uint32_t user_bits = 32)

      The bus signals are called ``<name>_valid`` and so on, as in :cpp:class:`axis_bus`. The width of the stream is
      what the device sees, the type of the beat is what the test holds the data in.

   .. cpp:function:: void connect(const sc_module &model)

      Connects the ports of the model called ``<name>_valid`` and so on to the bus, see :cpp:func:`connect_stream`.

   .. cpp:function:: axis_master<data_type, dest_type, user_type> &get_master()

.. cpp:class:: template<typename data_type = uint64_t, typename dest_type = uint32_t, typename user_type = uint32_t> axis_sink

   The receiving end of a stream of the device: the bus and a slave that answers it.

   .. cpp:function:: axis_sink(const std::string &name, const clock &clk, uint32_t data_bits = 64, double ready_probability = 1.0, uint64_t seed = 1, uint32_t dest_bits = 32, uint32_t user_bits = 32)

   .. cpp:function:: void connect(const sc_module &model)

   .. cpp:function:: axis_slave<data_type, dest_type, user_type> &get_slave()

   .. cpp:function:: void add_listener(std::function<void(const axis_beat<data_type, dest_type, user_type> &)> listener)

      Called with every transfer the sink received.

   .. cpp:function:: template<typename T> void add_listener(T &object, void (T::*method)(const axis_beat<data_type, dest_type, user_type> &))

      The listener is a member function of an object.

A stream whose data is a word
-----------------------------

The two ends and the checking have to agree on the beat, and the type is written once in each place:

.. code-block:: cpp

    const axis_fifo_model model;
    sctb::axis_source<uint32_t> input("in", clk, 32);
    sctb::axis_sink<uint32_t> output("out", clk, 32);
    sctb::scoreboard<sctb::axis_beat<uint32_t>> scoreboard("axis_fifo", model, &axis_fifo_model::compare, clk.get_period());

    output.add_listener(scoreboard, &sctb::scoreboard<sctb::axis_beat<uint32_t>>::observe);

and the model of the device takes the same beat,
``std::string compare(const sctb::axis_beat<uint32_t> &expected, const sctb::axis_beat<uint32_t> &actual)``. The
test of ``axi_stream/fifo`` is written that way, and its comparison does not take the tag of the scoreboard because
the expected beat is the input.
