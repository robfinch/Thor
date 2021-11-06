---------------
*  DPTI Demo  *
---------------

This folder contains logic for implementing a synchronous DPTI interface.
The files are as follows:

*dpti_ctrl.vhd
	A reusable DPTI controller component. It includes 2 local FIFOs for 
	synchronizing data from the DPTI clock domain to the domain(s) of the 
	rest of the design

*dpti_demo.vhd
	A simple loopback wrapper for dpti_ctrl.vhd that will work with the 
	DptiDemo.cpp host software test. 

*clk_wiz_0.v 
	A wrapper for instantiating an MMCM. Required for dpti_ctrl.vhd.

*timing.xdc
	Timing constraints for dpti_ctrl.vhd.

*testbench
	A testbench that can be used to simulate and test dpti_demo.vhd.


To build dpti_demo, import all of these files into a new vivado project. 
Then also import the master XDC provided for you platform (Nexys Video, 
Genesys 2, etc.) and uncomment the pin mappings for the DPTI bus and system 
clock. You may need to rename some ports in the master XDC, but they should 
match for the most part.

You will then be able to build the project and run it. Build and run 
Dptidemo.cpp to test your logic. 

If you want to include dpti_ctrl.vhd in your own design, be sure to import
dpti_ctrl.vhd, clk_wiz_0.v, and timing.xdc.