#!/bin/sh

# -----------------
# control variables
# -----------------
LOG_FILE="/var/log/defense.log"
BASELINE_NETSTAT="/var/log/netstat_baseline.txt"
BASELINE_PROCESS="/var/log/process_baseline.txt"
BASELINE_CRONTAB="/var/log/crontab_baseline.txt"
FILES="/etc/passwd /etc/shadow"
DIRS="/bin"

# ---------
# functions
# ---------
processMonitor(){
    CURR_PROCESS="/var/log/process_current.txt"
    ps -o pid,ppid,user,args > $CURR_PROCESS
    result=$( {
        diff -u --new-file $BASELINE_PROCESS $CURR_PROCESS | 
        grep -E "^\+" |
        grep -v "^+++" |
        grep -v ${0} | 
        grep -v "ps -o pid,ppid,user,args" |
        sed 's/+/   /g';
    } )
    cp $CURR_PROCESS $BASELINE_PROCESS
    rm $CURR_PROCESS
    echo "$result"
}

connectionMonitor() {  
    CURR_CONNECTIONS="/var/log/netstat_current.txt"
    netstat -antpu > $CURR_CONNECTIONS
    result=$( {
        diff -u --new-file $BASELINE_NETSTAT $CURR_CONNECTIONS | 
        grep -E "^\+" | 
        sed 's/+/    /' | 
        grep -v "^    ++" | 
        grep -v "^    Active";
    } )
    cp $CURR_CONNECTIONS $BASELINE_NETSTAT
    rm $CURR_CONNECTIONS
    echo "$result"
}

crontabMonitor(){
    CURR_CRONTAB="/var/log/crontab_current.txt"
    for user in $(cut -f1 -d: /etc/passwd); do
        crontab=$(crontab -u ${user} -l 2>/dev/null)
        if ! [ -z "$crontab" ]; then
            echo -e "user "${user}"\n$crontab" >> $CURR_CRONTAB
        fi
    done
    result=$( {
        diff -u --new-file $BASELINE_CRONTAB $CURR_CRONTAB | 
        grep -E "^\+" | 
        sed 's/+/    /' | 
        grep -v "^    ++" | 
        grep -v "^    Active";
    } )
    cp $CURR_CRONTAB $BASELINE_CRONTAB
    rm $CURR_CRONTAB
    echo "$result"
}

fileMonitor() {
    if [ $# -ne 1 ]; then
        return 1
    fi
    local file="$1"
    if [ ! -e "$file" ]; then
        return 2
    fi
    result=$( {
        diff -u --new-file "$file.bak" "$file" |
        awk 'NR > 3' |
        grep "^[+-]" |
        sed 's/+/    +/'|
        sed 's/-/    -/';
    } )
    cp -r "$file" "$file.bak"
    echo "$result"
}

directoryMonitor() {
    if [ $# -ne 1 ]; then
        return 1
    fi
    local dir="$1"
    CURR_FILES="$dir/current_files.txt"
    ls $dir > $CURR_FILES
    result=$( {
        diff -u --new-file "$dir/current_files.bak" "$CURR_FILES" |
        awk 'NR > 3' | 
        grep -v "current_files.txt" |
        grep -v ".bak" |
        grep "^[+-]" |
        sed 's/+/    +/'|
        sed 's/-/    -/';
    } )
    cp $CURR_FILES "$dir/current_files.bak"
    echo "$result"
}

initializeLogging(){
    echo -e "\n\n\n\nOffense script started at $(date)" >> $LOG_FILE
    DIRS="${DIRS} $(which init.d | cut -d " " -f 2)"
    systemdDirs=$(which systemd | tr ' ' '\n' | tail -n +2)
    for dir in $systemdDirs; do
        if [ -d "$dir/system" ]; then
            DIRS="${DIRS} $dir/system"
        fi
    done

    for dir in ${DIRS}; do
        rm -f "{$dir}/current_files.txt"
        if [ -d "{$dir}" ]; then
            for file in $(ls {$dir}); do 
                ext="${file##*.}"
                if [ "$ext" == "bak" ]; then
                    rm -rf "{$dir}/$file"
                else 
                    FILES="${FILES} ${dir}/$file"
                fi
            done
        fi
    done

    echo "monitoring files:" >> $LOG_FILE
    for file in ${FILES}; do
        echo "    $file" >> $LOG_FILE
    done

    for file in ${FILES}; do
        cp -r $file $file.bak >> $LOG_FILE 2>&1
    done

    echo "monitoring directories:" >> $LOG_FILE
    for dir in "${DIRS}"; do
        echo "    ${dir}" >> $LOG_FILE
    done

    for dir in "${DIRS}"; do
        ls ${dir} > "${dir}/current_files.txt"
    done

    echo "process baseline" >> $LOG_FILE
    echo "$(processMonitor)" >> $LOG_FILE 2>&1
    echo "network connection baseline" >> $LOG_FILE
    echo "$(connectionMonitor)" >> $LOG_FILE 2>&1
    echo "crontab baseline" >> $LOG_FILE
    echo "$(crontabMonitor)" >> $LOG_FILE 2>&1
}

initializeLogging
while true; do
    sleep 10
    echo -e "\n\n\n\nLog entry at $(date)" >> $LOG_FILE
    
    procOutput=$(processMonitor)
    if ! [ -z "$procOutput" ]; then
        echo "new processes created:" >> $LOG_FILE
        echo "   PID   PPID  USER     COMMAND" >> $LOG_FILE
        echo "$procOutput" >> $LOG_FILE 2>&1
    fi

    connectionOutput=$(connectionMonitor)
    if ! [ -z "$connectionOutput" ]; then
        echo "new network connections:" >> $LOG_FILE
        echo "    Proto Recv-Q Send-Q Local Address           Foreign Address         State       PID/Program name" >> $LOG_FILE
        echo "$connectionOutput" >> $LOG_FILE 2>&1
    fi

    for dir in "${DIRS}"; do
        dirMonOutput=$(directoryMonitor "${dir}")
        if ! [ -z "$dirMonOutput" ]; then
            echo -e "changes to ${dir}:\n$dirMonOutput" >> $LOG_FILE 2>&1
        fi
        for file in $dirMonOutput; do
            if [[ $file =~ ^"+" ]]; then
                file=$(echo $file | sed 's/+//')
                if [ -f "${dir}/$file" ]; then
                    FILES="${FILES} ${dir}/$file"
                fi
            fi
        done
    done
    
    for file in ${FILES}; do
        fileOutput=$(fileMonitor "$file")
        if ! [ -z "$fileOutput" ]; then
            echo -e "changes to ${file}:\n$fileOutput" >> $LOG_FILE 2>&1
        fi
    done

    cronOutput=$(crontabMonitor)
    if ! [ -z "$cronOutput" ]; then
        echo "changes to crontab:" >> $LOG_FILE
        echo "$cronOutput" >> $LOG_FILE 2>&1
    fi
done