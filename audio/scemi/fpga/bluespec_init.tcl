
if { [info exists bscws] } {
    # Add the "Program FPGA" button
    register_tool_bar_item program {
        programfpga
    } database_lightning.gif {program fpga}

    # Add the "Run Testbench" button
    register_tool_bar_item runbench {
        runtb ./tb
    } cog.gif {run testbench}
}

