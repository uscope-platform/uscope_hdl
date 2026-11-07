Infrastructure
==============

.. cpp:namespace:: sctb

Reporting (``report``)
----------------------

.. cpp:class:: reporter

   Collects the verdict of a test. Every checker reports to it, so the exit code of the simulation is whether
   anything was reported. There is one instance.

   .. cpp:function:: static reporter &instance()

   .. cpp:function:: void set_max_printed_errors(int64_t max)

      The first ``max`` errors are printed (default 10), all of them are counted.

   .. cpp:function:: void error(const std::string &message)

      Counts an error and prints it, until the limit is reached.

   .. cpp:function:: void info(const std::string &message) const

      Prints a line and flushes, so that progress shows while a long test runs.

   .. cpp:function:: int64_t get_errors() const

   .. cpp:function:: bool passed() const

      True if no error was reported.

   .. cpp:function:: int get_exit_code() const

      0 if the test passed, 1 otherwise.

.. cpp:function:: std::string format(const char *fmt, ...)

   ``printf`` into a ``std::string``.

.. cpp:function:: std::string hex(uint64_t value, int digits)

   Hexadecimal with a fixed number of digits.

Clock and reset (``clocking``)
------------------------------

.. cpp:class:: clock

   The testbench clock. It starts low, so the first rising edge is half a period in.

   .. cpp:function:: explicit clock(const char *name, sc_time clock_period = sc_time(10, SC_NS))

   .. cpp:function:: sc_signal_in_if<bool> &get_signal()

      The clock as a signal, to connect to the clock port of the model.

   .. cpp:function:: const sc_event &posedge() const

      The rising edge, what blocking calls wait for.

   .. cpp:function:: sc_time get_period() const

   .. cpp:function:: void wait_cycles(int64_t cycles) const

      Waits for a number of rising edges. Call it from a thread.

.. cpp:function:: void reset_sequence(sc_signal<bool> &reset_n, const clock &clk, int64_t cycles = 4)

   Active low reset, asserted for a number of cycles and then released. Call it from a thread.

Running (``run``)
-----------------

.. cpp:function:: void init(double resolution = 1, sc_time_unit unit = SC_NS)

   Sets the time resolution of SystemC. It has to be the first thing in ``sc_main``, and it has to match the
   ``timeprecision`` of the RTL.

.. cpp:function:: void spawn(const std::string &name, std::function<void()> body)

   Starts a thread when the simulation starts, like an ``initial`` block. This is where the test sequence goes, as
   a thread is the kind of process that can wait.

.. cpp:function:: template<typename T> void spawn(const std::string &name, T &object, void (T::*method)())

   The body is a member function of an object.

.. cpp:function:: void spawn_every_cycle(const std::string &name, const clock &clk, std::function<void()> body)

   Runs a function on every rising edge of the clock. The function runs and returns, which is much cheaper than a
   thread. Monitors and slaves are built with it.

.. cpp:function:: template<typename T> void spawn_every_cycle(const std::string &name, const clock &clk, T &object, void (T::*method)())

   The body is a member function of an object.

.. cpp:function:: void spawn_on_event(const std::string &name, const sc_event &event, std::function<void()> body)

   Runs a function every time an event happens, for example the change of a signal. Like
   :cpp:func:`spawn_every_cycle` it runs a function that returns.

.. cpp:function:: template<typename T> void spawn_on_event(const std::string &name, const sc_event &event, T &object, void (T::*method)())

   The body is a member function of an object.

.. cpp:function:: void finish()

   Ends the simulation.

.. cpp:function:: int run(sc_time timeout = SC_ZERO_TIME)

   Runs until :cpp:func:`finish` is called, or until the timeout if there is one (zero means none). A test that did
   not finish is reported as an error. Returns the exit code of the test.

Progress (``progress``)
-----------------------

.. cpp:class:: progress

   Prints a line every few percent of a long test, with the errors found so far.

   .. cpp:function:: explicit progress(int64_t total, int step_percent = 5)

   .. cpp:function:: void update(int64_t done)

      Prints the lines for the steps that were reached.

   .. cpp:function:: void finish()

      Prints the lines still missing up to 100%.

Command line (``options``)
--------------------------

.. cpp:class:: options

   The command line of a test. An option is ``--name=value``, or ``--name`` alone, everything else is a positional
   argument.

   .. cpp:function:: options(int argc, char *argv[])

   .. cpp:function:: bool has(const std::string &name) const

   .. cpp:function:: std::string get(const std::string &name, const std::string &fallback = "") const

   .. cpp:function:: int64_t get_integer(const std::string &name, int64_t fallback) const

   .. cpp:function:: const std::vector<std::string> &get_positional() const

   .. cpp:function:: int64_t get_positional_integer(size_t index, int64_t fallback) const

Waveforms (``trace``)
---------------------

.. cpp:class:: trace

   Writes the signals that are added to it to a waveform file in the FST format. It is on when the command line has
   ``--trace=<file>``. When it is off, every ``add`` returns immediately, so the signals can be listed in every test.
   The signals are written when they change, at the time they change.

   ``--trace-start=<cycles>`` and ``--trace-cycles=<cycles>`` select the part of the simulation that is written,
   which is all of it by default. Every signal is written with its value when the window opens.

   .. cpp:function:: trace(const options &opts, const clock &clk)

      The clock is always traced, and sets what a cycle is.

   .. cpp:function:: bool is_enabled() const

   .. cpp:function:: void add(const std::string &name, const sc_signal_in_if<bool> &signal)
   .. cpp:function:: void add(const std::string &name, const sc_signal_in_if<uint32_t> &signal)
   .. cpp:function:: void add(const std::string &name, const sc_signal_in_if<uint64_t> &signal)

      Any signal of the testbench, under the name given.

   .. cpp:function:: void add(const std::string &name, const sc_signal_in_if<uint64_t> &signal, uint32_t bits)

      The lowest bits of the signal are written, for a value that is narrower than the signal that carries it.

   .. cpp:function:: void add(const axis_bus &bus)
   .. cpp:function:: void add(const axis_source &source)
   .. cpp:function:: void add(const axis_sink &sink)

      The six signals of a stream, under the names they were given. The data is written with the width of the stream.

   Only the signals of the testbench are written, which include the ports of the device. The registers inside the
   device are not: they belong to the model made by Verilator, whose own tracer is not connected to this one yet.
