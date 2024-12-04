declare -a TESTS=(mult_no_lsq btest1 btest2 no_hazard basic_load basic_store simple_store fib simp_branch simp_mult simple)

for i in $(seq 1 6); do
    sed -i "31s/.*/\`define N $i/" verilog/sys_defs.svh
    make nuke > /dev/null
    make cpu.out > /dev/null
    for test in "${TESTS[@]}"; do
        echo "$test (N=$i)"
        make $test.out > /dev/null
        diff output/$test.wb correct_out/$test.wb > /dev/null 2>&1
        wb_status=$?
        diff <(grep "@@@" output/$test.out) <(grep "@@@" correct_out/$test.out) > /dev/null 2>&1
        out_status=$?

        if [ $wb_status -ne 0 ] || [ $out_status -ne 0 ]
        then
            echo "Failed WB: $wb_status MEM: $out_status"
        else
            echo "Passed"
        fi
        echo ""
    done
    echo "=========="
done