Checking
========

Scoreboard
----------

A ``scoreboard`` is a queue of the results that the test said would come out, and a comparison.

* ``expect(beat, tag)`` puts a result at the end of the queue and remembers the time. The tag is any 64 bit value that
  the comparison wants to report, usually the input that produced the beat.
* ``observe(beat)`` takes the oldest expected result, calls the comparison, and reports an error if it returns
  something. The comparison is a member function of an object the test provides, which returns an empty string when
  the beats match and a description of the difference when they do not. The string is built on a mismatch.
* ``finish()`` reports what is still in the queue: those results never came out.

A beat that comes out when none is expected is an error, and so is one that does not match.

The matching is in order and there is one queue per scoreboard. A device with several output streams has one
scoreboard for each.

Because the scoreboard stamps the time at ``expect`` and again at ``observe``, it measures the latency of every
result by itself. The depth of the pipeline comes from those timestamps, and ``check_latency`` compares it with the
one the test expects.

What counts as a match is up to the test. The comparison of the floating point converters compares a NaN by its
class and everything else bit by bit, and checks that ``dest``, ``user`` and ``tlast`` came out unchanged.

End of test checks
------------------

The functions in ``checks`` are called by the sequence when the stimulus is over. Each one reports to the reporter and
can be used alone.

* ``drain`` waits for what is still in the device to come out, up to a number of cycles.
* ``check_latency`` requires every result to have taken the same number of cycles, equal to the one given.
* ``check_throughput`` requires a device that accepts a beat every cycle to take about as many cycles as there were
  beats.

``check_latency`` and ``check_throughput`` are for a sink that is always ready. With a sink that stalls at random, the
latency and the time taken change, and ``drain`` and the scoreboard do the checking.

Coverage
--------

A ``coverpoint`` is a value that falls in one of a list of named bins. The test classifies what it sees and calls
``hit(bin)``. A ``covergroup`` collects coverpoints and reports at the end of the test, and a bin that was never hit
is an error: a case that is never reached is a case that is never checked.

The bins are listed by the test, and the classification comes from the test's model, so the same coverage pieces serve
any device.

Reporter
--------

Every checker reports to ``reporter::instance()``, which counts the errors and prints the first few (ten by default).
The verdict of a test is whether the count is zero, and ``run`` turns it into the exit code. Every piece reports to the
same place, so the test has one thing to ask for the result. ``progress`` prints the number of errors found so far on each line, so a long run that has
gone wrong shows it early.

The simulation continues after an error and runs the whole test, and the total at the end is the number of
mismatches.
