Getting started
===============

Requirements
------------

* Verilator 5.x
* SystemC 3.x, for example ``brew install systemc``
* CMake 3.20 or newer
* a C++17 compiler. SystemC has to be built with the same standard as the testbench, and the Homebrew package is
  built with C++17.
* zlib, and access to GitHub the first time a test is configured, for the waveform writer

Running a test
--------------

Every test has a ``CMakeLists.txt`` next to its sources. From that folder:

.. code-block:: bash

    cmake -S . -B build -G Ninja
    cmake --build build
    ./build/test

For example in ``Components/system/floating_point_ip/fp32_to_fp64/tb/systemc``. The exit code is 0 when nothing was
reported as an error, so the binary can be used from a script or from CI.

The command line
----------------

.. list-table::
   :header-rows: 1
   :widths: 34 66

   * - Argument
     - Meaning
   * - ``<number>``
     - The number of vectors, for the tests that take one. Every converter test has its own default.
   * - ``--trace=<file>``
     - Write a waveform, see :doc:`/architecture/waveforms`.
   * - ``--trace-start=<cycles>``
     - First cycle that is written, 0 by default.
   * - ``--trace-cycles=<cycles>``
     - Number of cycles that are written, all of them by default.

.. code-block:: bash

    ./build/test 2000 --trace=wave.fst --trace-start=100 --trace-cycles=40

Open the file with GTKWave or Surfer.

Where things are
----------------

.. code-block:: text

    systemc/
        CMakeLists.txt        the sctb library: add_subdirectory() it and link sctb
        includes/sctb/        declarations, axis/ has the AXI stream pieces
        src/                  definitions, same layout
        docs/                 this documentation

Everything specific to a device is next to the device, in a ``tb/systemc`` folder beside its other testbenches.

Building this documentation
---------------------------

.. code-block:: bash

    pip install sphinx sphinx-rtd-theme
    sphinx-build -b html docs docs/_build/html
