******************************************************************
 Chapter 6: Playbook organization - roles, includes, and imports
******************************************************************

Check these docs for more:
https://docs.ansible.com/ansible/devel/playbook_guide/playbooks_reuse.html


Imports
-------
The ``import_tasks`` construct is processed at the time
the playbook is parsed. Variables are brought into
scope by supplying them to the call. Because this
happens at parse time, you can't do things like load a
particular import when some condition is met. You also
can't use ``import_tasks`` in a loop.

::

  # playbook.yaml
  ---
  - hosts: all
    tasks:
      - import_tasks: imported-tasks.yaml
        vars:
          username: johndoe
          ssh_private_keys:
            - { src: /path/to/johndoe/key1, dest: id_rsa }
            - { src: /path/to/johndoe/key2, dest: id_rsa_2 }
      - import_tasks: imported-tasks.yaml
        vars:
          username: janedoe
          ssh_private_keys:
            - { src: /path/to/janedoe/key1, dest: id_rsa }
            - { src: /path/to/janedoe/key2, dest: id_rsa_2 }

  # imported-tasks.yaml - this is a flat list of tasks
  ---
  - name: Add profile info for user.
    copy:
      src: example_profile
      dest: "/home/{{username}}/.profile"
      owner: "{{username}}"
      group: "{{username}}"
      mode: 0744

  - name: Add private keys for user.
    copy:
      src: "{{item.src}}"
      dest "/home/{{username}}/.ssh/{{item.dest}}"
      owner: "{{username}}"
      group: "{{username}}"
      mode: 0600
    with_items: "{{ssh_private_keys}}"


Includes
--------
The ``include_tasks`` construct is like textual
substitution, during playbook execution time (instead
of parse time). It's as though the task-list was
copy-pasted into the playbook where the call to
``include_tasks`` used to be.

This means that you don't have to explicitly pass
variables to the task list.

It also measn the task list can only see the variables
defined up until the point that ``include_tasks`` was
called.

One use case for include is looping. When a loop is
used with an include, the included tasks or roles will
be executed once for each item in the loop.

Prefer ``import_tasks`` over ``include_tasks`` where possible.

::

  # playbook.yaml
  ---
  - hosts: all
    tasks:
      - name: Get log file path.
        whatever:
          whatever: whatever
        register: log_file_paths
      - include_taks: log_paths.yaml

  # log_paths.yaml
  ---
  - name: Check for existing log files in dynamic log_file_paths variable.
    find:
      paths: "{{item}}"
      patterns: '*.log'
    register: found_log_file_paths
    with_items: "{{log_file_paths}}"

Here is an example of contitionally including a task list::

  # playbook2.yaml
  ---
  - hosts: all
    tasks:

      - name: Check if extra_tasks.yaml is present at run time.
        stat:
          path: tasks/extra-tasks.yaml
        register: extra_tasks_file
        connection: local

      - include_tasks: tasks/extra-tasks.yml
        when: extra_tasks_file.stat.exists


Handler imports and includes
----------------------------
Handler can be imported or included just like tasks,
within a playbooks handlers section.

::

  handlers:
    - import_tasks: handlers.yaml


Playbook imports
----------------
::

  ---
  - name: Master playbook
    remote_user: root
    tasks:
      ...
  - import_playbook: web.yaml
  - import_playbook: db.yaml

So now that you've seen we can import or include pretty
much everything, you can refactor your playbook by
moving things into folders. But how do you organize
those folders?


Roles
-----
Roles are a standard structure for playbook organization.

Minimal directory structure. (Use ``ansible-galaxy role
init $dirname`` to create a full directory structure.)

::

  role_name/
    meta/
      main.yaml
    tasks/
      main.yaml

The ``meta/main.yaml`` file lists dependencies.
Assuming you have no dependencies, it will look like
this:

::

  ---
  dependencies: []

Each depenency is another role that must be run first.

Here's the tree of a project that uses the ``nodejs`` role.

::

  nodejs-app/
    playbook.yml
    app/
      app.js
      package.json
    roles/
      nodejs/
        meta/
          main.yml
        tasks/
          main.yml

Contents of ``nodejs-app/playbook.yml``::

  pre_tasks:
    # EPEL/GPG setup, firewall config...
  roles:
    - nodejs
  tasks:
    # Node.js app deployment tasks...

In the output of ``ansible-playbook``, each task from
the nodejs role will be prefixed with the role name.


