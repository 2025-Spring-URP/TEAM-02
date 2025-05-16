# TEAM-02
## 질문거리
1. compile, synthesis <-- make file
2. FPGA
3. 
## 진행상황
## TL
1. 김주성:
2. 최원기:
## DLL
1. 임용성:
2. 이승로: DLCMSM, DLLP generator, Decoder(dllp 부분만 설계함) / 테스트벤치 or 합성은 아직 진행X


## TestBench(sv)
- **How to use**
  - Make sure your SSH terminal supports remote GUI functionality.
  - Linux cli mode:
    ```
    $ source env.source
    $ cd sim/sv/work/
    $ mkdir devel
    $ make clean
    $ make devel
    ```
## TestBench(cocotb)
- **Requirements**
  - The following python-packages are required in the local environment.
    ```
    $ pip install cocotb
    $ pip install cocotb-test
    $ pip install cocotb-bus
    $ pip install cocotbext-axi
    ```
  - Your Design Top Mdule must be named __PCIE_TOP_WRAPPER.sv__
  - The I/O ports of PCIE_TOP_WRAPPER must match the design in PCIE_TOP_WRAPPER.sv from the Issues repository.
    
- **Modifications**
  - The following libraries require modification.
      - ~/.local/lib/python3.10/site-packages/cocotbext/axi/`__init__.py` : add "from .memory import Memory"
    ```
    from .version import __version__
    
    from .constants import AxiBurstType, AxiBurstSize, AxiLockType, AxiCacheBit, AxiProt, AxiResp
    
    from .address_space import MemoryInterface, Window, WindowPool
    from .address_space import Region, MemoryRegion, SparseMemoryRegion, PeripheralRegion
    from .address_space import AddressSpace, Pool
    
    ...
    
    from .axi_slave import AxiSlaveWrite, AxiSlaveRead, AxiSlave
    from .axi_ram import AxiRamWrite, AxiRamRead, AxiRam
    
    from .memory import Memory
    ```
    
      - ~/.local/lib/python3.10/site-packages/cocotb/share/makefiles/simulators/Makefile.vcs : Copy and paste the code blow
    ```
        ###############################################################################
    # Copyright (c) 2013 Potential Ventures Ltd
    # Copyright (c) 2013 SolarFlare Communications Inc
    # All rights reserved.
    #
    # Redistribution and use in source and binary forms, with or without
    # modification, are permitted provided that the following conditions are met:
    #     * Redistributions of source code must retain the above copyright
    #       notice, this list of conditions and the following disclaimer.
    #     * Redistributions in binary form must reproduce the above copyright
    #       notice, this list of conditions and the following disclaimer in the
    #       documentation and/or other materials provided with the distribution.
    #     * Neither the name of Potential Ventures Ltd,
    #       SolarFlare Communications Inc nor the
    #       names of its contributors may be used to endorse or promote products
    #       derived from this software without specific prior written permission.
    #
    # THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
    # ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
    # WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
    # DISCLAIMED. IN NO EVENT SHALL POTENTIAL VENTURES LTD BE LIABLE FOR ANY
    # DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
    # (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
    # LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
    # ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
    # (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
    # SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
    ###############################################################################
    
    include $(shell cocotb-config --makefiles)/Makefile.inc
    
    ifneq ($(VHDL_SOURCES),)
    
    $(COCOTB_RESULTS_FILE):
    	@echo "Skipping simulation as VHDL is not supported on simulator=$(SIM)"
    clean::
    
    else
    
    CMD_BIN := vcs
    
    ifdef VCS_BIN_DIR
         CMD := $(shell :; command -v $(VCS_BIN_DIR)/$(CMD_BIN) 2>/dev/null)
    else
         # auto-detect bin dir from system path
         CMD := $(shell :; command -v $(CMD_BIN) 2>/dev/null)
    endif
    
    ifeq (, $(CMD))
         $(error Unable to locate command >$(CMD_BIN)<)
    else
         VCS_BIN_DIR := $(shell dirname $(CMD))
         export VCS_BIN_DIR
    endif
    
    ifdef VERILOG_INCLUDE_DIRS
        COMPILE_ARGS += $(addprefix +incdir+, $(VERILOG_INCLUDE_DIRS))
    endif
    
    ifeq ($(PYTHON_ARCH),64bit)
        EXTRA_ARGS += -full64
    endif
    
    ifeq ($(GUI),1)
        EXTRA_ARGS += -gui
    endif
    
    
    ifeq ($(WAVES), 1)
        COMPILE_ARGS += -kdb
        COMPILE_ARGS    += -debug_access+all
        COMPILE_ARGS    += -debug_access+struct
        COMPILE_ARGS    += -debug_region+cell
        COMPILE_ARGS    += +vcs+fsdbon
        SIM_ARGS        += +fsdb+record
        SIM_ARGS        += +fsdb+mda
        SIM_ARGS        += +fsdb+signal
        SIM_ARGS        += +fsdb+struct
        SIM_ARGS        += +fsdbfile+dump.fsdb
    endif
    
    ifeq ($FILELISTS),)
        FILELIST_ARGS =
    else
        FILELIST_ARGS = -f $(FILELISTS)
    endif
    
    # TODO:
    # investigate +vpi+1 option which reduces memory requirements
    
    # Can't do this using an argument, we have to create a PLI table file
    # enabling write access to the design
    $(SIM_BUILD)/pli.tab : | $(SIM_BUILD)
    	echo "acc+=rw,wn:*" > $@
    
    # Compilation phase
    $(SIM_BUILD)/simv: $(VERILOG_SOURCES) $(SIM_BUILD)/pli.tab $(CUSTOM_COMPILE_DEPS) | $(SIM_BUILD)
    	cd $(SIM_BUILD) && \
    	TOPLEVEL=$(TOPLEVEL) \
    	$(CMD) -top $(TOPLEVEL) $(PLUSARGS) -debug_access+r+w-memcbk -debug_region+cell +vpi -P pli.tab -sverilog \
    	-timescale=$(COCOTB_HDL_TIMEUNIT)/$(COCOTB_HDL_TIMEPRECISION) \
    	$(EXTRA_ARGS) -debug -load $(shell cocotb-config --lib-name-path vpi vcs) $(COMPILE_ARGS) $(VERILOG_SOURCES) $(FILELIST_ARGS)
    
    # Execution phase
    $(COCOTB_RESULTS_FILE): $(SIM_BUILD)/simv $(CUSTOM_SIM_DEPS)
    	$(RM) $(COCOTB_RESULTS_FILE)
    
    	MODULE=$(MODULE) TESTCASE=$(TESTCASE) TOPLEVEL=$(TOPLEVEL) TOPLEVEL_LANG=$(TOPLEVEL_LANG) \
    	$(SIM_CMD_PREFIX) $(SIM_BUILD)/simv +define+COCOTB_SIM=1 $(SIM_ARGS) $(EXTRA_ARGS) $(PLUSARGS) $(SIM_CMD_SUFFIX)
    
    	$(call check_for_results_file)
    
    clean::
    	$(RM) -r $(SIM_BUILD)
    	$(RM) -r simv.daidir
    	$(RM) -r cm.log
    	$(RM) -r ucli.key
    endif

    ```
- **How to use**
  - Make sure your SSH terminal supports remote GUI functionality.
  - Always run update before using submodules.
    ```
    $ git submodule update --init --recursive
    ```
  - Linux CLI mode:
    ```
    $ source env.source
    $ cd sim/cocotb_pcie/
    $ make clean
    $ make
    ```
  - GUI mode(after cli mode):
    ```
    $ ./run_verdi.sh
    ```
