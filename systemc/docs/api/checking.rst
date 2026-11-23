Checking
========

.. cpp:namespace:: sctb

Scoreboard (``scoreboard``)
---------------------------

.. cpp:class:: template<typename beat_type> scoreboard

   Checks that what comes out of a device is what the reference model said would come out. The beats are matched
   in order. The latency is measured on the way, from the time a beat is expected (when its input went in) to the
   time it is observed (when it came out), so a test measures the depth of the pipeline without knowing it in
   advance.

   ``beat_type`` is whatever the test compares, the scoreboard only stores it and hands it to the comparison. It is
   not tied to any protocol: the transfer of a stream, ``axis_beat<>`` or the one the endpoints of the test use, for
   example ``axis_beat<uint32_t>`` (see :cpp:struct:`axis_beat`), is one choice, and a transaction of another bus or a
   packet is as good. The scoreboard and the checks that take it are templates defined in the headers, so a new type
   needs nothing built for it.

   .. cpp:type:: compare_function = std::function<std::string(const beat_type &expected, const beat_type &actual, uint64_t tag)>

      Returns an empty string when the beats match, otherwise what differs. The string is built on a mismatch.
      The third argument is the tag given to :cpp:func:`expect`, which the scoreboard carries through and never
      looks at.

   .. cpp:type:: compare_function_without_tag = std::function<std::string(const beat_type &expected, const beat_type &actual)>

      The comparison of a test that has nothing to say about the input: it is not given the tag. The expected beat
      says everything, which is the case of a device that passes its input through, like the fifo.

   .. cpp:function:: scoreboard(const std::string &name, compare_function compare, sc_time clock_period)

   .. cpp:function:: scoreboard(const std::string &name, compare_function_without_tag compare, sc_time clock_period)

   .. cpp:function:: template<typename T> scoreboard(const std::string &name, const T &object, std::string (T::*method)(const beat_type &, const beat_type &, uint64_t) const, sc_time clock_period)

      The comparison is a member function of an object.

   .. cpp:function:: template<typename T> scoreboard(const std::string &name, const T &object, std::string (T::*method)(const beat_type &, const beat_type &) const, sc_time clock_period)

      The same, for a comparison that takes only the two beats.

   .. cpp:function:: void expect(const beat_type &beat, uint64_t tag = 0)

      The reference model says this will come out. The tag is opaque to the scoreboard: it stores it with the beat
      and gives it back to the comparison unchanged. It is whatever the test needs to report, for example the input
      that produced the beat, or an index into the test's own data. A comparison that takes only the two beats is
      not given it.

   .. cpp:function:: void observe(const beat_type &beat)

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
They are templates on the beat of the scoreboard they are given, so ``sctb::drain(scoreboard, clk, 20)`` works
whichever beat the scoreboard holds.

.. cpp:function:: template<typename beat_type> void drain(const scoreboard<beat_type> &board, const clock &clk, int64_t max_cycles)

   Waits for what is still in the device to come out, up to ``max_cycles``. Call it
   from a thread.

.. cpp:function:: template<typename beat_type> void check_latency(const scoreboard<beat_type> &board, int64_t cycles)

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
