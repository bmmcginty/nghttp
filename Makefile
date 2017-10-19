all:
	crystal2 build test.cr
release:
	crystal2 build --release test.cr
run:
	make
	./test
strace:
	make
	strace -f -tt -ozs ./test
stracerelease:
	make release
	strace -f -tt -ozs ./test
debug:
	touch callg.del
	rm callg*
	crystal2 build --release --link-flags "-ggdb" --debug test.cr
	valgrind --tool=callgrind --dump-instr=yes --trace-jump=yes ./test
	callgrind_annotate callg* > test.txt
