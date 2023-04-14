#!/bin/bash
# Run pyperformance benchmark on host.
# Usage: ./benchmark.sh <workload> <perf/emon>
# Example1: ./benchmark.sh pidigits perf
# Example2: ./benchmark.sh all emon

# set -x

# Configurations
# Python binary path for pyperformance, use default//usr/bin/python3.11.2...
python="/home/yangge/pyperformance/python3.11.2/bin/python3.11.2"
# Workload name, use all/fannkuch...
workload=$1
# workload="chaos"
# Pinned core, use default/0/1/2/2,10...
core=2

# duration and tps
duration=0
tps=0

# Enable perf, use true/false
perf_enalbed="false"
# perf_enalbed="true"
perf_bin="/home/yangge/pyperformance/os.linux.intelnext.kernel/tools/perf/perf"
# perf delay and duration(seconds)
perf_delay=5
perf_duration=10

# Enable emon, use true/false
emon_enabled="true"
# emon_enabled="false"
# emon delay and duration(seconds)
emon_delay=5
emon_duration=10

if [ $2 = "perf" ]; then
    perf_enalbed="true"
    emon_enabled="false"
else
    perf_enalbed="false"
    emon_enabled="true"
fi

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
result_dir=$cur_dir/$workload-$timestamp
mkdir $result_dir
echo result_dir=$result_dir
# pyperf_result_warmup=$result_dir/$workload-warmup.json
pyperf_warmup_log=$result_dir/pyperf-warmup-$workload.log
pyperf_result=$result_dir/$workload.json
pyperf_log=$result_dir/pyperf-$workload.log

# Print parameters
touch $result_dir/config.txt
echo "python=$python" >> $result_dir/config.txt
echo "workload=$workload" >> $result_dir/config.txt
echo "core=$core" >> $result_dir/config.txt
echo "perf_enalbed=$perf_enalbed" >> $result_dir/config.txt
echo "perf_bin=$perf_bin" >> $result_dir/config.txt
echo "perf_delay=$perf_delay" >> $result_dir/config.txt
echo "perf_duration=$perf_duration" >> $result_dir/config.txt
echo "emon_enabled=$emon_enabled" >> $result_dir/config.txt
echo "emon_delay=$emon_delay" >> $result_dir/config.txt
echo "emon_duration=$emon_duration" >> $result_dir/config.txt
echo "edp_architecture_codename=$edp_architecture_codename" >> $result_dir/config.txt
echo "edp_architecture_sockets=$edp_architecture_sockets" >> $result_dir/config.txt
echo "result_dir=$result_dir" >> $result_dir/config.txt

echo "-------------------------------------------------------------------------------"
echo "Run benchmark first as warm up"
if [ $core = "default" ]; then
    core_cmd=""
else
    core_cmd="--affinity $core"
fi

if [ $workload = "all" ]; then
    python3 -m pyperformance run \
        --inherit-environ http_proxy,https_proxy \
        $core_cmd \
        -r \
        -p $python | tee -a ${pyperf_warmup_log}
else
    python3 -m pyperformance run \
        --inherit-environ http_proxy,https_proxy \
        $core_cmd \
        -r \
        -p $python \
        --benchmarks $workload | tee -a ${pyperf_warmup_log}
fi
echo "-------------------------------------------------------------------------------"

# Extract execution time info from result
caculate_duration(){
    cd $result_dir
    echo "-------------------------------------------------------------------------------"
    echo "Extracting benchmark duration"
    date_str=$(cat pyperf-warmup-$workload.log | grep -i 'Start date')
    echo $date_str
    date=${date_str#*: }
    start_date=$(date -d "$date" +%s)
    date_str=$(cat pyperf-warmup-$workload.log | grep -i 'End date')
    echo $date_str
    date=${date_str#*: }
    end_date=$(date -d "$date" +%s)
    duration=$(($end_date - $start_date))
    echo Benchmark duration: $duration secs
    cd $cur_dir
    echo "-------------------------------------------------------------------------------"
    echo ""
}

# Caculate TPS automatically
caculate_tps(){
    echo "-------------------------------------------------------------------------------"
    echo "Calculating TPS"
    cd $result_dir
    if [ -f mean.txt ]; then
        rm mean.txt
    fi
    # python3 -m pyperformance show $workload.json | grep 'Mean' > mean.txt
    # if [ $workload = "all" ]
    # then
    #     # Collect all workloads mean results
    #     string_flag="Start date:"
    #     last_line=$(sed -n "/$string_flag/=" pyperf-warmup-$workload.log | awk '{print $1-1}')
    #     echo lateline=$last_line
    #     sed -n "1,${last_line}p" pyperf-warmup-$workload.log | grep -i ': Mean' > mean.txt
    # else
    #     cat pyperf-warmup-$workload.log | grep -i "$workload: Mean" > mean.txt
    # fi
    string_flag="Start date:"
    last_line=$(sed -n "/$string_flag/=" pyperf-warmup-$workload.log | awk '{print $1-1}')
    echo lateline=$last_line
    sed -n "1,${last_line}p" pyperf-warmup-$workload.log | grep -i ': Mean' > mean.txt

    # Move time unit to second from mead.txt to mean-result.txt
    if [ -f mean-result.txt ]; then
        rm mean-result.txt
    fi
    touch mean-result.txt
    cat mean.txt | while read line; do
        workload=$(echo "$line" | cut -d ':' -f 1)
        mean=$(echo "$line" | cut  -d ':' -f 3 | cut -d ' ' -f 2)
        time_type=$(echo "$line" | cut  -d ':' -f 3 | cut -d ' ' -f 3)
        
        if [ $time_type = "ms" ]; then
            mean=$(echo "scale=10; $mean/1000" | bc)
        elif [ $time_type = "us" ]; then
            mean=$(echo "scale=10; $mean/1000000" | bc)
        elif [ $time_type = "ns" ]; then
            mean=$(echo "scale=10; $mean/1000000000" | bc)
        fi

        echo $mean >> mean-result.txt
    done
    function geometric_mean() {
        # Python version should be higher than 3.8
        python3 -c 'from statistics import geometric_mean; import sys; \
            data=[float(x) for x in sys.stdin.readlines()]; \
            print(geometric_mean(data))'
    }
    geometric_mean=$(cat mean-result.txt | cut -f2 -d, | geometric_mean)
    echo "geometric_mean=$geometric_mean secs"

    tps=$(echo "scale=2; 1/$geometric_mean" | bc)
    echo "TPS: $tps"
    cd $cur_dir
    echo "-------------------------------------------------------------------------------"
}

# Collect perf data
collect_perf(){
    cd $result_dir
    perf_duration=`expr $duration - $perf_delay`
    perf_duration=`expr $perf_duration - $perf_delay`
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
    cd $result_dir
    line="-------------------------------------------------------------------------------"
    echo "Collecting emon data"
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

process_emon_data(){
    cd $result_dir
    if ! command -v ruby &> /dev/null
    then
        echo "Ruby is not installed; installing ruby…"
        sudo apt install ruby -y
    fi
    echo "-------------------------------------------------------------------------------"
    echo "Processing EMON for ${edp_architecture_codename} ${edp_architecture_sockets} and generating CSVs..."
    echo "TPS=$tps"
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
    echo "-------------------------------------------------------------------------------"
    echo ""
    # echo "-->> __edp_system_view_summary.per_txn.csv <<---"
    # cat __edp_system_view_summary.per_txn.csv
    # echo "-------------------------------------------------------------------------------"
    # awk -F',' '{print $2}' __edp_system_view_summary.per_txn.csv 
    # echo "-------------------------------------------------------------------------------"
    cd $cur_dir
}

# Read benchmark output, if target string is in the output, start to collect data
collect_data(){
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

caculate_duration
caculate_tps
benchmark="true"
if [ -f $pyperf_result ]; then
        rm -f $pyperf_result
fi
if [ -f $pyperf_log ]; then
    rm -f $pyperf_log
fi
touch $pyperf_log
# ./collect-data.sh $workload $pyperf_log $result_dir > $result_dir/collect.log
# collect_data > $result_dir/collect.log &
collect_data &
echo "-------------------------------------------------------------------------------"
echo "Run benchmark for data collection"
if [ $workload = "all" ]
then
    python3 -m pyperformance run \
        --inherit-environ http_proxy,https_proxy \
        $core_cmd \
        -r \
        -p $python \
        -o $pyperf_result | tee -a ${pyperf_log}
else
    python3 -m pyperformance run \
        --inherit-environ http_proxy,https_proxy \
        $core_cmd \
        -r \
        -p $python \
        --benchmarks $workload \
        -o $pyperf_result | tee -a ${pyperf_log}
fi
echo "-------------------------------------------------------------------------------"

if [ $emon_enabled = "true" ]; then
    process_emon_data
fi
