PCIE_SIM_HOME = ${PCIE_HOME}/sim
export PCIE_SIM_HOME

FILE_LISTS	+= $(PCIE_HOME)/design/filelist.f
FILE_LISTS	+= $(PCIE_SIM_HOME)/sv/compile.f

SIMULATOR	?= vcs
#RANDOM_SEED	?= auto
RANDOM_SEED	= 0
DUMP	?= off
GUI	?= off

STABLE_TC = pcie_test
#STABLE_TC = pcie_sample_test
DEVEL_TC = devel_test

STABLE_TESTS	+= default
STABLE_TESTS	+= request_delay
STABLE_TESTS	+= response_delay
STABLE_TESTS	+= ready_delay
STABLE_TESTS	+= out_of_order_response
STABLE_TESTS	+= read_interleave
STABLE_TESTS	+= wvalid_preceding_awvalid

.PHONY: all cli gui devel $(STABLE_TESTS) clean clean_all

all: cli

cli:
	make                                   --eval=TC=$(STABLE_TC) $(STABLE_TESTS)

gui:
	make --eval=GUI=verdi --eval=DUMP=fsdb --eval=TC=$(STABLE_TC) $(STABLE_TESTS)

devel:
	make --eval=GUI=verdi --eval=DUMP=fsdb --eval=TC=$(DEVEL_TC) --eval=VCS_ARGS=+define+DEVEL_CXL  sim_$(SIMULATOR) TEST=devel

$(STABLE_TESTS):
	make sim_$(SIMULATOR) TEST=$@

CLEAN_TARGET	+= *.log
CLEAN_ALL_TARGET += *.log
CLEAN_ALL_TARGET += *.key

clean:
	rm -rf $(CLEAN_TARGET)

clean_all:
	make clean
	rm -rf $(CLEAN_ALL_TARGET)
	rm -rf $(addprefix */,$(CLEAN_ALL_TARGET))

include vcs.mk