
NAME ?= 
BIN_NAME = $(NAME)-cpu-tests

VCDS = $(shell find $(abspath $(BUILD_HOME)) -name "*.vcd")

run:
	bash ./build.sh -e cpu_axi_diff -d -s -a "-i non-output/cpu-tests/$(BIN_NAME).bin --dump-wave -b 0" -m "EMU_TRACE=1 WITH_DRAMSIM3=1" -b

wave: 
	bash ./build.sh -e cpu_axi_diff -d -w

clean:
	rm -rf $(VCDS)
