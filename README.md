# Digital FIR filter design and implementation
The activity includes:
- Specification analysis: understanding the features implemented by the filter (essentially lowpass filtering and decimation), understanding the communication protocols through which
the filter interfaces with the external environment, understanding the proposed hardware
architecture.
- RTL design of the filter by writing synthesizeable VHDL code.
- Preparing a testbench to verify that the implementation is correct by using functional
simulation and validation.
- Synthesis and post-synthesis simulation. Static timing analysis.
- FPGA mapping (Xilinx Virtex-E) and P&R. Static timing analysis. Post-mapping/post-P&R
simulation with back-annotation of gate delays.


Each group will be asked to perform the following activities:
- The RTL-level hardware implementation of some filter functions, by completing the filter's
synthesized VHDL code.
- Refining the VHDL testbench prepared for the functional simulation of the filter by adding
specific test portions.
- Debugging the unit by compiling code, run functional simulation, and output analysis.
- Synthesis of the filter, emphasizing in particular the aspects related to the correct setting of
the synthesizer parameters and the verification of the reports obtained with respect to
different settings.
- Mapping on FPGA: you will have to prove that you understand and know how to manage
the different steps that lead from the synthesized netlist to the corresponding binary
programming file for the HW card.
- Detailed documentation of the work done (both as documentation of the unit and as
documentation of the project choices made).

we want to design an 8-bit FIR filter, which has an finite impulse response at 10 
coefficients and integrates a 1/10 decimation functionality of the output into the same unit. The 
filter must be programmable, in the sense that the coefficients ai, with i=0,... ,9 must be able to be 
loaded from the outside. The operation of the filter must be stopped until the coefficients have all 
been loaded correctly. In addition, you can explicitly manage enabling/disabling the filter and 
updating the value of the coefficients themselves.

