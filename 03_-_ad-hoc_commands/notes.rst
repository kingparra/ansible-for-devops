****************************
 Chapter 3: Ad-Hoc Commands
****************************



Where ansible.cfg lives
-----------------------
There are several possible locations where
``ansible.cfg`` can live. If Ansible finds one of them
it will read it and ignore the other ones.

* value of the ``-i`` or ``--inventory`` command-line argument
* ``$ANSIBLE_CONFIG``
* ``./ansible.cfg``
* ``~/ansible.cfg``
* ``/etc/ansible/ansible.cfg``

This means you have to put all of your relevant setting
in one file, global and local config files will not be
merged.



Setting up an ansible.cfg for your local project
------------------------------------------------
If you want to configure ansible locally for your
project, use the ``./ansible.cfg`` file in your
projects directory.

The ``./ansible.cfg`` file is in INI format, and
divided into several sections. Some of the commonly
used ones are:

* ``[defaults]``
* ``[inventory]``
* ``[ssh_connection]``

To generate a config with all of the options commented
out, use this command:
``ansible-config init --disabled --type all > ansible.cfg``.




Where to put SSH connection details
-----------------------------------
There are several locations you can specify SSH connection
details.

Directly in ansible.cfg
^^^^^^^^^^^^^^^^^^^^^^^
ansible.cfg

::

  [ssh_connection]
  # (string) Extra exclusive to the C(sftp) CLI
  ;sftp_extra_args=

  # (string) Arguments to pass to all SSH CLI tools.
  ;ssh_args=-C -o ControlMaster=auto -o ControlPersist=60s

  # (string) Extra exclusive to the SSH CLI.
  ;ssh_extra_args=

  # (string) Common extra args for all SSH CLI tools.
  ;ssh_common_args=

  # (boolean) Determines if SSH should check host keys.
  ;host_key_checking=True

  # (integer) This is the default amount of time we will wait while establishing an SSH connection.
  # It also controls how long we can wait to access reading the connection once established (select on the socket).
  ;timeout=10

Indirectly in ssh.cfg
^^^^^^^^^^^^^^^^^^^^^
Or in ./ssh.cfg, by setting an option in ./ansible.cfg

ansible.cfg::

  [ssh_connection]
  ssh_common_args = -F ./ssh.cfg

ssh.cfg::

  Host *
    User vagrant
    StrictHostKeyChecking no
    UserKnownHostsFile=/dev/null
    IdentityFile ~/.vagrant.d/insecure_private_keys/vagrant.key.ed25519
    IdentityFile ~/.vagrant.d/insecure_private_keys/vagrant.key.rsa

In the inventory using variables
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
::

  [app]
  Server1 ssh_host=10.0.0.1 ssh_port=22 ssh_user=xuser
  Server2 ssh_host=10.0.0.2 ssh_port=22 ssh_user=xuser

  [slave]
  192.168.1.11 ansible_connection=ssh ansible_ssh_user=vagrant ansible_ssh_pass=vagrant
  192.168.1.12 ansible_connection=ssh ansible_ssh_user=vagrant ansible_ssh_pass=vagrant ansible_ssh_port=23

You can also supply those variables in a separate file.


Pipelining
----------
In ansible.cfg you can set the pipelining option::

  [connection]
  ;pipelining=False

Pipelining reduces the number of connection operations
required to execute a module on the remote server, by
executing many Ansible modules without actual file
transfers. This can result in a very significant
performance improvement when enabled.

However this can conflict with privilege escalation
(become). For example, when using sudo operations you
must first disable 'requiretty' in the sudoers file for
the target hosts, which is why this feature is disabled
by default.


Ad-hoc commands
---------------
Ad-hoc commands have this general form::

  ansible <groupname> -m <module> -a <argument_string>

If you want to limit the hosts in the group to act on
to a subset that meets a glob or regex pattern, you can
use the ``--limit`` flag, like this::

  # Limit to a particular host in the app group
  ansible app -b -a "service chronyd restart" --limit "192.168.56.4"
  # Limit hosts with a simple pattern (asterisk is a wildcard).
  ansible app -b -a "service chronyd restart" --limit "*.4"

  # Limit hosts with a regular expression (prefix with a tilde).
  ansible app -b -a "service chronyd restart" --limit ~".*\.4"


Running background jobs and resuming them
-----------------------------------------
You can tell Ansible to run commands asynchronously,
and poll the servers to see when the commands finish.

Use the following options:

* ``-B <seconds>`` : max time
* ``-P <seconds>`` : poll interval

Run dnf update on all the servers, in the background,
print background job information, and exit.

::

  ansible multi -b -B 3600 -P 0 -a "dnf -y update"

Check on the status of our long-running dnf update using the job id from the last commands output

::

  ansible multi -b -m async_status -a "jid=j562271572399.30968"

