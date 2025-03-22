try {
# ---------------------------------------
# Step 1: Specify libraries
# ---------------------------------------
set link_library \
[list /media/0/LogicLibraries/UMC/28nm/35hs/hsl/svt/2.01a/liberty/ecsm/um28nchslogl35hsl140f_sswc0p81v125c.db ]
set target_library \
[list /media/0/LogicLibraries/UMC/28nm/35hs/hsl/svt/2.01a/liberty/ecsm/um28nchslogl35hsl140f_sswc0p81v125c.db ]

# VER-26 Warning: The package XXX has already been analyzed. It is being replaced.
suppress_message VER-26

# ---------------------------------------
# Step 2: Read designs
# ---------------------------------------
# Source environment variables
set env_map {}
lappend env_map "\${PCIE_HOME}" $env(PCIE_HOME)

# parse the filelist and analyze
set fp [open "$env(PCIE_HOME)/design/filelist.f" r]
set data [split [read $fp] "\n"]
foreach line2 $data {
    global search_path

    set line [string map $env_map $line2]
    if {[string first "+incdir" $line] != -1} {
        set words [split $line "+"]
        set inc_path [lindex $words 2]
        lappend search_path $inc_path
    } elseif {[string first ".sv" $line] != -1} {
        analyze -format sverilog $line
    } elseif {[string first ".v" $line] != -1} {
        analyze -format verilog $line
    }
}

# Set SRAM models as black boxes (until we fix the SRAM configurations and use .db files)
set_app_var hdlin_sv_blackbox_modules SAL_SDP_RAM

set design_name $env(DESIGN_TOP)
elaborate ${design_name}

# connect all the library components and designs
link

# renames multiply references designs so that each
# instance references a unique design
uniquify

# ---------------------------------------
# Step 3: Define design environments
# ---------------------------------------
#
# ---------------------------------------
# Step 4: Set design constraints
# ---------------------------------------
# ---------------------------------------
# Clock
# ---------------------------------------
set clk_freq            500

# Reduce clock period to model wire delay (60% of original period)
set derating 0.60
set clk_period [expr 1000 / double($clk_freq)]
set clk_period [expr $clk_period * $derating]


set clk_name cclk
create_clock -period $clk_period $clk_name
# Set infinite drive strength
set_drive 0 $clk_name

set clk_name pclk
create_clock -period $clk_period $clk_name
# Set infinite drive strength
set_drive 0 $clk_name

set clk_name aclk
create_clock -period $clk_period $clk_name
# Set infinite drive strength
set_drive 0 $clk_name


set rst_name creset_n
set_ideal_network $rst_name

set rst_name preset_n
set_ideal_network $rst_name

set rst_name areset_n
set_ideal_network $rst_name

# ---------------------------------------
# Input/Output
# ---------------------------------------
# Apply default timing constraints for modules
set_input_delay  0.4 [all_inputs]  -clock $clk_name
set_output_delay 0.4 [all_outputs] -clock $clk_name

# ---------------------------------------
# Area
# ---------------------------------------
# If max_area is set 0, DesignCompiler will minimize the design as small as possible
set_max_area 0 

# ---------------------------------------
# Step 5: Synthesize and optimzie the design
# ---------------------------------------
compile_ultra -gate_clock

# ---------------------------------------
# Step 6: Analyze and resolve design problems
# ---------------------------------------
check_design  > $design_name.check_design.rpt

report_constraint -all_violators -verbose -sig 10 > $design_name.all_viol.rpt

report_design                             > $design_name.design.rpt
report_area -physical -hierarchy          > $design_name.area.rpt
report_timing -nworst 10 -max_paths 10    > $design_name.timing.rpt
report_power -analysis_effort high        > $design_name.power.rpt
report_cell                               > $design_name.cell.rpt
report_qor                                > $design_name.qor.rpt
report_reference                          > $design_name.reference.rpt
report_resources                          > $design_name.resources.rpt
report_hierarchy -full                    > $design_name.hierarchy.rpt
report_threshold_voltage_group            > $design_name.vth.rpt

# ---------------------------------------
# Step 7: Save the design database
# ---------------------------------------
write -hierarchy -format verilog -output  $design_name.netlist.v
write -hierarchy -format ddc     -output  $design_name.ddc
write_sdf -version 1.0                    $design_name.sdf
write_sdc                                 $design_name.sdc

# ---------------------------------------
# Step 8: Save the design database
# ---------------------------------------
set_scan_configuration -chain_count 5
create_test_protocol -infer_clock -infer_asynch

preview_dft

dft_drc

insert_dft

write -hierarchy -format verilog -output  $design_name.scan.netlist.v
write_test_protocol              -output  $design_name.scan.stil
write_sdc                                 $design_name.scan.sdc

exit 0
}
