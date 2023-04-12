#!/bin/bash
# Run pyperformance benchmark on host.
# Usage: ./benchmark.sh 

# set -x

# Configurations
# Python binary path for pyperformance, use default//usr/bin/python3.11.2...
python="/home/yangge/pyperformance/python3.11.2/bin/python3.11.2"
# Workload name, use all/fannkuch...
# workload="chaos"
workload="fannkuch"
# Pinned core, use default/0/1/2/2,10...
core=2

# Enable perf, use true/false
perf_enalbed="false"
perf_bin="/home/yangge/pyperformance/os.linux.intelnext.kernel/tools/perf/perf"
# perf delay and duration(seconds)
perf_delay=5
perf_duration=10

# Enable emon, use true/false
emon_enabled="true"
# emon delay and duration(seconds)
emon_delay=5
emon_duration=10

# CPU architcture and sockets
#edp_architecture_codename="cascadelake"
#edp_architecture_codename="icelake"
edp_architecture_codename="sapphirerapids"
#edp_architecture_codename="amd"

#edp_architecture_sockets="1s"
edp_architecture_sockets="2s"

# Check parameters
if [ $python = "default" ]; then
    python="/usr/bin/python3"
fi

if [ $perf_enalbed = "true" ]; then
    if ! command -v ${perf_bin} &> /dev/null
    then
        echo "perf is not installed"
        echo "Please installing perf..."
        exit 1
        # sudo apt install linux-tools-`uname -r` -y
    fi
fi

if [ $emon_enabled = "true" ]; then
    # Verify EMON is working first
    source /opt/intel/sep/sep_vars.sh
    output=$(bash -c 'emon -v' 2>&1)
    grep Error <<< "$output"
    error_found=$?
    if [[ ${error_found} -eq 0 ]]; then
        echo "EMON is broken or not installed"
        echo "Exiting automation..."
        exit 1
    else
        echo "EMON works"
        echo "Proceeding with run..."
    fi
fi

cur_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")"; pwd)"
timestamp=$(date +%Y%m%d%H%M%S)
result_dir=$workload-$timestamp
mkdir $result_dir
# pyperf_result_warmup=$result_dir/$workload-warmup.json
pyperf_result=$result_dir/$workload.json
pyperf_log=$result_dir/pyperf-$workload.log

echo "Run benchmark first as warm up"
if [ $core = "default" ]; then
    core_cmd=""
else
    core_cmd="--affinity $core"
fi

if [ $workload = "all" ]; then
    echo "Run all benchmark"
    python3 -m pyperformance run \
        --inherit-environ http_proxy,https_proxy \
        $core_cmd \
        -r \
        -p $python
else
    echo "Run benchmark "$workload
    python3 -m pyperformance run \
        --inherit-environ http_proxy,https_proxy \
        $core_cmd \
        -r \
        -p $python \
        --benchmarks $workload
fi

# Collect perf data
collect_perf(){
    echo "Collect perf data"
    cd $result_dir
    # $perf_bin script > $result_dir/perf.data
    echo "-------------------------------------------------------------------------------"
    echo "Sleeping for ${perf_delay} secs"
    sleep $perf_delay
    echo "-------------------------------------------------------------------------------"
    echo "Collecting perf record for ${perf_duration} secs"
    echo "-------------------------------------------------------------------------------"

    start_perf_time=$(date)
    echo "Start perf: ${start_perf_time}" > perf.log

    echo -1 | sudo tee /proc/sys/kernel/perf_event_paranoid
    # sudo ${perf_bin} record -e cycles,instructions -g -F 99 -a -- sleep ${perf_duration}
    sudo ${perf_bin} record -g -F 99 -a -- sleep ${perf_duration}

    stop_perf_time=$(date)

    echo "-------------------------------------------------------------------------------"
    # sudo perf record -e cycles,instructions -g -F 99 -a -- sleep 30
    echo "sudo $perf_bin record -e cycles,instructions -g -F 99 -a -- sleep ${perf_duration}" >> perf.log
    echo "Stop perf: ${stop_perf_time}" >> perf.log
    perf_ver=$(${perf_bin} --version)
    echo "Perf version: ${perf_ver}" >> perf.log

    sudo chown $USER:$USER perf.data

    echo "Process perf record data"
    sudo $perf_bin report -f -n --sort=dso --max-stack=0 --stdio > perf-report-out.txt
    sudo chown $USER:$USER perf-report-out.txt
    echo "-------------------------------------------------------------------------------"
    cd $cur_dir
}

# Collect emon data
collect_emon(){
    echo "Collect emon data"
    cd $result_dir

    line="------------------------------------------------------------"
    echo ${line}
    echo "Sleeping for ${emon_delay} secs"
    sleep ${emon_delay}
    echo ${line}
    echo ${line} >> emon.log
    start_emon_time=$(date)
    echo "Start EMON: ${start_emon_time}" >> emon.log

    # nohup emon -collect-edp -f emon.dat & sleep ${emon_duration}; emon -stop
    if [ ${edp_architecture_codename} == "cascadelake" ] || [ ${edp_architecture_codename} == "icelake" ] || [ ${edp_architecture_codename} == "sapphirerapids" ]; then
        # CLX, ICX, SPR
        nohup emon -v -i /opt/intel/sep/config/edp/${edp_architecture_codename}_server_events_private.txt > emon.dat 2>&1 &

    elif [ ${edp_architecture_codename} == "amd" ]; then
        # AMD
        nohup emon -v -i /opt/intel/sep/config/edp/${edp_architecture_codename}_events_private.txt > emon.dat 2>&1 &
    fi

    sleep $emon_duration

    emon -stop
    emon -v > emon-v.dat
    emon -M > emon-M.dat

    sudo dmidecode > dmidecode.txt
    grep 'stepping\|model\|microcode' /proc/cpuinfo > microcode.txt
    cat /proc/meminfo > meminfo-after.txt

    stop_emon_time=$(date)
    echo "Stop EMON: ${stop_emon_time}" >> emon.log

    if [ ${edp_architecture_codename} == "cascadelake" ] || [ ${edp_architecture_codename} == "icelake" ] || [ ${edp_architecture_codename} == "sapphirerapids" ]; then
        # CLX, ICX, SPR
        echo "EMON Command: nohup emon -v -i /opt/intel/sep/config/edp/${edp_architecture_codename}_server_events_private.txt > emon.dat 2>&1" >> emon.log
    elif [ ${edp_architecture_codename} == "amd" ]; then
        # AMD
        echo "EMON Command: nohup emon -v -i /opt/intel/sep/config/edp/${edp_architecture_codename}_events_private.txt > emon.dat 2>&1" >> emon.log
    fi

    echo ${line}
    echo ${line} >> emon.log

    lscpu > lscpu.txt
    cd $cur_dir
}

# Caculate TPS automatically
caculate_tps(){
    cd $result_dir
    echo "Extract execution time info from result, and calculate TPS"
    if [ -f mean.txt ]; then
        rm mean.txt
    fi
    python3 -m pyperformance show $workload.json | grep 'Mean' > mean.txt
    function geometric_mean() {
        # Python version should be higher than 3.8
        python3 -c 'from statistics import geometric_mean; import sys; \
            data=[float(x) for x in open("mean-result.txt")]; \
            print(geometric_mean(data))'
    }
    if [ -f mean-result.txt ]; then
        rm mean-result.txt
    fi
    touch mean-result.txt
    cat mean.txt | while read line; do
        mean=$(echo "$line" | cut  -d ':' -f 2 | cut -d ' ' -f 2)
        time_type=$(echo "$line" | cut  -d ':' -f 2 | cut -d ' ' -f 3)
        # echo $mean $time_type
        if [ $time_type = "ms" ]; then
            mean=$(echo "scale=10; $mean/1000" | bc)
        elif [ $time_type = "us" ]; then
            mean=$(echo "scale=10; $mean/1000000" | bc)
        elif [ $time_type = "ns" ]; then
            mean=$(echo "scale=10; $mean/1000000000" | bc)
        fi
        # echo $mean sec
        echo $mean >> mean-result.txt
    done
    geometric_mean=$(cat mean-result.txt | cut -f2 -d, | geometric_mean)
    echo geometric_mean=$geometric_mean s

    tps=$(echo "scale=2; 1/$geometric_mean" | bc)
    echo "-------------------------------------------------------------------------------"
    echo TPS=$tps
    echo "-------------------------------------------------------------------------------"
    cd $cur_dir
}

process_emon_data(){
    if ! command -v ruby &> /dev/null
    then
        echo "Ruby is not installed; installing ruby…"
        sudo apt install ruby -y
    fi

    echo "------------------------------------------------------------"
    echo "Processing EMON for ${edp_architecture_codename} ${edp_architecture_sockets} and generating CSVs..."
    caculate_tps $tps
    cd $result_dir
    if [ ${edp_architecture_codename} == "cascadelake" ] || [ ${edp_architecture_codename} == "icelake" ] || [ ${edp_architecture_codename} == "sapphirerapids" ]; then
        # CLX, ICX, SPR
        ruby /opt/intel/sep/config/edp/edp.rb --input emon.dat --emonv emon-v.dat --emonm emon-M.dat --dmidecode dmidecode.txt --metric /opt/intel/sep/config/edp/${edp_architecture_codename}_server_${edp_architecture_sockets}_private.xml --format /opt/intel/sep/config/edp/chart_format_${edp_architecture_codename}_server_private.txt --step 1 --socket-view --core-view --end -1 --begin 1 --tps $tps --temp-dir .

    elif [ ${edp_architecture_codename} == "amd" ]; then
        # AMD Milan
        ruby /opt/intel/sep/config/edp/edp.rb --input emon.dat --emonv emon-v.dat --emonm emon-M.dat  --dmidecode dmidecode.txt --metric /opt/intel/sep/config/edp/${edp_architecture_codename}_${edp_architecture_sockets}_private.xml --format /opt/intel/sep/config/edp/chart_format_${edp_architecture_codename}_private.txt --step 1 --socket-view --core-view --end -1 --begin 1 --tps $tps --temp-dir .
    fi

    # echo "Launching EDP script for bigcore data..."
    # ruby "/opt/intel/sep_private_5.37_linux_101222070cbac49/bin64/../lib64/../config/edp/SplitCoreType.rb"  -i "emon.dat" -o "emon"

    # echo "Launching EDP processing script..."
    # ruby "/opt/intel/sep_private_5.37_linux_101222070cbac49/bin64/../lib64/../config/edp/edp.rb"  --socket-view --core-view --thread-view -x ${tps} --timestamp-in-chart -i "emon_bigcore" -o "summary_bigcore.xlsx" -m "/opt/intel/sep_private_5.37_linux_101222070cbac49/bin64/../lib64/../config/edp/goldencove_1s_private.xml" -f "/opt/intel/sep_private_5.37_linux_101222070cbac49/bin64/../lib64/../config/edp/chart_format_goldencove_private.txt"

    # # save CSVs for big core, otherwise they will get overwritten by small core CSVs
    # mkdir ./big-core-csvs; mv summary_bigcore.xlsx ./big-core-csvs; mv *.csv ./big-core-csvs

    # echo "Launching EDP script for smallcore data ..."
    # ruby "/opt/intel/sep_private_5.37_linux_101222070cbac49/bin64/../lib64/../config/edp/edp.rb"  --socket-view --core-view --thread-view -x ${tps} --timestamp-in-chart -i "emon_smallcore" -o "summary_smallcore.xlsx" -m "/opt/intel/sep_private_5.37_linux_101222070cbac49/bin64/../lib64/../config/edp/gracemont_1s_private.xml" -f "/opt/intel/sep_private_5.37_linux_101222070cbac49/bin64/../lib64/../config/edp/chart_format_gracemont_private.txt"

    # mkdir ./small-core-csvs; mv summary_smallcore.xlsx ./small-core-csvs; mv *.csv ./small-core-csvs

    echo ""
    echo "------------------------------------------------------------"
    echo ""
    # echo "-->> __edp_system_view_summary.per_txn.csv <<---"
    # cat __edp_system_view_summary.per_txn.csv
    # echo "------------------------------------------------------------"
    # awk -F',' '{print $2}' __edp_system_view_summary.per_txn.csv 
    # echo "------------------------------------------------------------"
    cd $cur_dir
}

# Read benchmark output, if target string is in the output, start to collect data
collect_data(){
    # echo collect data PID, BASHPID, PPID is: $$, $BASHPID, $PPID
    if [ $workload = "all" ]; then
        target_string="[ 1/62] 2to3"
    else
        target_string="[ 1/[0-9]*] ${workload}"
    fi
    echo "[collect data] Checking if the pyperf log file contains the target string: $target_string"
    while true; do
        # if the pyperf log file contains the target string, run perf/emon
        if tail $pyperf_log | grep -q "$target_string"; then
            if [ $perf_enalbed = "true" ] && [ $benchmark = "true" ]; then
                collect_perf
                break
            fi
            if [ $emon_enabled = "true" ] && [ $benchmark = "true" ]; then
                collect_emon
                break
            fi
            break
        else
            echo "[collect data] Wait for 1s and check again"
            sleep 1
        fi
    done
}


benchmark="true"
touch $pyperf_log
echo benchmark PID, BASHPID, PPID is: $$, $BASHPID, $PPID
# ./collect-data.sh $workload $pyperf_log $result_dir > $result_dir/collect.log
# collect_data > $result_dir/collect.log &
collect_data &
echo "Run benchmark for data collection"
if [ $workload = "all" ]
then
    echo "Run all benchmark"
    python3 -m pyperformance run \
        --inherit-environ http_proxy,https_proxy \
        $core_cmd \
        -r \
        -p $python \
        -o $pyperf_result | tee -a ${pyperf_log}
else
    echo "Run benchmark "$workload
    python3 -m pyperformance run \
        --inherit-environ http_proxy,https_proxy \
        $core_cmd \
        -r \
        -p $python \
        --benchmarks $workload \
        -o $pyperf_result | tee -a ${pyperf_log}
fi

if [ $emon_enabled = "true" ]; then
    process_emon_data
fi
