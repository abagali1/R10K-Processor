declare -a TESTS=(mult_no_lsq btest1 btest2 no_hazard basic_load basic_store simple_store)

make nuke
make cpu.out
for test in "${TESTS[@]}"; do
    echo $test
    make $test.out > /dev/null
    diff output/$test.wb correct_out/$test.wb
    wb_status=$?
    diff <(grep "@@@" output/$test.out) <(grep "@@@" correct_out/$test.out)
    out_status=$?

    if [ $wb_status -ne 0 ] || [ $out_status -ne 0 ]
    then
        echo "Failed"
        exit 1
    else
        echo "Passed"
    fi
    echo ""
done
