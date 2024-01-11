#!/usr/bin/env bash
### 3.1 Your first ad-hoc commands


## 3.1.1 Discover Ansibles parallel nature
ansible multi -a "hostname"

# Use only one fork of the ansible process,
# to perform cmd in linear sequence,
# instead of in parllel, which is the default.
ansible multi -a "hostname" -f 1


## 3.1.2 Learning about your environment
ansible multi -a "df -h"
ansible multi -a "free -m"
ansible multi -a "date"


## 3.1.3 Make changes using Ansible modules
ansible multi -b -m dnf -a "name=chrony state=present"
ansible multi -b -m service -a "name=chronyd state=started"



### Configure groups of servers, or individual servers


## Configure the Application servers
ansible app -b -m dnf -a "name=python3-pip state=present"
ansible app -b -m pip -a "executable=pip3 name=django<4 state=present"
ansible app -a "python3 -m django --version"

## Configure the Database servers

# service
ansible db -b -m dnf -a "name=mariadb-server state=present"
ansible db -b -m service -a "name=mariadb state=started"

# firewall
ansible db -b -m dnf -a "name=firewalld state=present"
ansible db -b -m service -a "name=firewalld state=started"
ansible db -b -m firewalld -a "zone=database state=present permanent=yes"
ansible db -b -m firewalld -a "source=192.168.56.0/24 zone=database state=enabled permanent=yes"
ansible db -b -m firewalld -a "port=3306/tcp zone=database state=enabled permanent=yes"

# allow sql access for one user from our app servers
ansible db -b -m dnf -a "name=python3-PyMySQL state=present"
ansible db -b -m mysql_user -a "name=django host=% password=12345 priv=*.*:ALL state=present"


## Make changes to just one server
ansible app -b -a "systemctl status chronyd"
# use --limit to limit the command to a specific server in the host list
# --limit will match either an exact string or a regular expression (prefixed with ∼).
ansible app -b -a "service chronyd restart" --limit "192.168.56.4"
# Limit hosts with a simple pattern (asterisk is a wildcard).
ansible app -b -a "service chronyd restart" --limit "*.4"
# Limit hosts with a regular expression (prefix with a tilde).
ansible app -b -a "service chronyd restart" --limit ~".*\.4"



## Manage users and groups
ansible app -b -m group -a "name=admin state=present"

# other options: uid=[uid] shell=[shell] password=[encrypted-pw]
ansible app -b -m user -a "name=johndoe group=admin createhome=yes"
ansible app -b -m user -a "name=johndoe state=absent remove=yes"


## Manage packages
# you can abstract over package managers using the package module
ansible app -b -m package -a "name=git state=present"



## Manage files and directories

# get information about a file
ansible multi -m stat -a "path=/etc/environment"

# copy a file to the servers
ansible multi -m copy -a "src=/etc/hosts dest=/tmp/hosts"

# retrieve a file from the servers
ansible multi -b -m fetch -a "src=/etc/hosts dest=/tmp"

# create directories and files

# create a directory
ansible multi -m file -a "dest=/tmp/test mode=644 state=directory"

# create a symlink
ansible multi -m file -a "src=~/.bashrc dest=~/.bashrc-link state=link"

# delete directories and files
ansible multi -m file -a "dest=/tmp/test state=absent"


## Run operations in the background
# You can tell Ansible to run commands asynchronously, and poll the servers to see when teh commands finish.
# Use the following options:
# -B <seconds> : max time
# -P <seconds> : poll interval

## Update servers asynchronously with asynchronous jobs
# run dnf update on all the servers, in the background, print background job information, and exit.
ansible multi -b -B 3600 -P 0 -a "dnf -y update"

# check on the status of our long-running dnf update using the job id from the last commands output
ansible multi -b -m async_status -a "jid=j562271572399.30968"

## Check log files
# Ansible only displays output after an operation is complete, so something tail -f won't work (becuase it never exits).
# There is a differnce between the shell and command modules -- shell allows redirection operators, but command does not.
ansible multi -b -a "tail /var/log/messages"
ansible multi -b -m shell -a "tail /var/log/messages | grep ansible-command | wc -l"

## Manage cron jobs
ansible multi -b -m cron -a "name='daily-cron-all-servers' hour=4 job='/etc/bashrc'"
ansible multi -b -m cron -a "name='daily-cron-all-servers' state=absent"

## Deploy a version-controlled application
ansible app -b -m git -a "repo=https://github.com/kingparra/hpfp.git dest=/opt/hpfp"

## Ansibles SSH connection history
#
# One thing that's universal about all of Ansible's SSH connection
# methods is that it uses the connection to transfer one or a few files
# defining a play or command to the remote server, then runs the
# play/command, then deletes the transferred files, and reports back the
# result.
#
# There are two SSH backends that you should worry about Paramiko (a python
# lib) and OpenSSH.
#
# If you need to connect via a port other than port 22, you should specify
# it in an inventory file using ansible_ssh_port.
#
## Faster OpenSSH with pipelining
#
# Instead of copying files, you can send and execute commands directly
# with the [ssh_connection] -> pipelining=True option.
