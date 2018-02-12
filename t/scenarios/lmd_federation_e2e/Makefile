include ../Makefile.common
EXPECTED_BACKENDS=8

extra_prepare:
	sudo ./docker_tc.sh lmdfederatione2e_slow_1 slow

extra_clean:
	-killall lmd
