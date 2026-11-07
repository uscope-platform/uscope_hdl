Checking
========

.. cpp:namespace:: sctb

Scoreboard (``scoreboard``)
---------------------------

.. cpp:class:: scoreboard

   Checks that what comes out of a device is what the reference model said would come out. The beats are matched
   in order. The latency is measured on the way, from the time a beat is expected (when its input went in) to the
   time it is observed (when it came out), so a test measures the depth of the pipeline without knowing it in
   advance.

   .. cpp:type:: compare_function = std::function<std::string(const axis_beat &expected, const axis_beat &actual, uint64_t tag)>

      Returns an empty string when the beats match, otherwise what differs. The string is built on a mismatch.
      The tag is the one given to :cpp:func:`expect`.

   .. cpp:function:: scoreboard(const std::string &name, compare_function compare, sc_time clock_period)

   .. cpp:function:: template<typename T> scoreboard(const std::string &name, const T &object, std::string (T::*method)(const axis_beat &, const axis_beat &, uint64_t) const, sc_time clock_period)

      The comparison is a member function of an object.

   .. cpp:function:: void expect(const axis_beat &beat, uint64_t tag = 0)

      The reference model says this will come out. The tag is whatever the comparison wants to report, for example
      the input that produced the beat.

   .. cpp:function:: void observe(const axis_beat &beat)

      This came out. It is compared with the oldest beat that is expected and reported if it differs. A beat that
      comes out when none is expected is an error.

   .. cpp:function:: void finish()

      To be called when the test is over: what is still waiting never came out, and that is an error.

   .. cpp:function:: size_t get_pending() const

      Beats that are expected and have not come out yet.

   .. cpp:function:: int64_t get_checked() const

   .. cpp:function:: int64_t get_min_latency() const
   .. cpp:function:: int64_t get_max_latency() const

      In clock cycles. Valid once a result has been checked.

End of test checks (``checks``)
-------------------------------

Each one reports to the reporter and can be used on its own. A test picks the ones that make sense for its device.

.. cpp:function:: void drain(const scoreboard &board, const clock &clk, int64_t max_cycles)

   Waits for what is still in the device to come out, up to ``max_cycles``. Call it
   from a thread.

.. cpp:function:: void check_latency(const scoreboard &board, int64_t cycles)

   Every result has to take the same number of cycles, and it has to be ``cycles``. Nothing coming out at all is
   an error too.

.. cpp:function:: void check_throughput(int64_t beats, sc_time elapsed, const clock &clk)

   A device that takes a beat every cycle takes ``beats`` cycles for ``beats`` beats, give or take the cycle the
   sequence starts in. More than that means the input stalled.

Coverage (``coverage``)
-----------------------

.. cpp:class:: coverpoint

   Functional coverage of a value that falls in one of a list of named bins. The classification is up to the test,
   which tells the coverpoint which bin it was.

   .. cpp:function:: coverpoint(const std::string &name, const std::vector<std::string> &bin_names)

   .. cpp:function:: void hit(size_t bin)

   .. cpp:function:: bool report() const

      Prints how many times each bin was hit, returns whether all of them were.

.. cpp:class:: covergroup

   A set of coverpoints. A bin that was never hit means the test did not look at that case, so it is reported as an
   error.

   .. cpp:function:: void add(const coverpoint &point)

   .. cpp:function:: bool report() const

      Reports every coverpoint, and an error if any bin was never hit. Returns whether all of them were.
