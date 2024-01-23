**********************************************
Chapter 5: Ansible playbooks beyond the basics
**********************************************


Handlers
--------
Here's a simple example of a handler from the last playbook.

::

  handlers:

    - name: restart apache
      service: name=apache2 state=restarted

  tasks:

    - name: Enable Apache rewrite module.
      apache2_module: name=rewrite state=present
      notify: restart apache

To notify multiple handlers you can use a list argument for the notify option.

One handler can notify another handler, creating a chain.

::

  handlers:

    - name: restart apache
      service: name=apache2 state=restarted
      notify: restart memcached

    - name: restart memcached
      service: name=memcached state=restarted

Some things to be aware of when using handlers:

* Handlers will only be run if a task notifies the handler.

* Handlers will run once, and only once, at the end of a play.

* If the play fails on a host before handlers are notified,
  the handlers will never be run.

* If a task runs but there are no changes the handler will not be notified.

You can force execution of the handlers with the
``ansible-playbook ... --force-handlers`` option.


Environment variables
---------------------

Per-task environment variables
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
You can set environment variables for use in a single task
with the ``environment`` keyword::

  - name: Download a file, using example-proxy as a proxy.
    get_url:
      url: http://www.example.com/file.tar.gz
      dest: ~/Downloads/
    environment:
      http_proxy: http://example-proxy:80/

Here's an example where a group of variables are factored out::

	vars:
		proxy_vars:
			http_proxy: http://example-proxy:80/
			https_proxy: https://example-proxy:443/
		[etc...]

	tasks:
		- name: Download a file, using example-proxy as a proxy.
			get_url:
				url: http://www.example.com/file.tar.gz
				dest: ~/Downloads/
			environment: proxy_vars

Persistent environment variables
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
You can of course set environment variables using built-in OS facilities.
I have some notes on that here:
https://gist.github.com/kingparra/a2075d427fad2b0e313fec34d3a2baa1

Here is an example of editing the ``/etc/environment`` file using the
``lineinfile`` module::

  vars:
    proxy_state: present
  tasks:
    - name: Configure the proxy.
      lineinfile:
        dest: /etc/environment
        regexp: "{{item.regexp}}"
        line:   "{{item.line}}"
        state:  "{{proxy_state}}"
      with_items:
        - regexp: "^http_proxy="
          line:   "http_proxy=http://example-proxy:80/"
        - regexp: "^https_proxy="
          line:   "https_proxy=https://example-proxy:80/"
        - regexp: "^ftp_proxy="
          line:   "ftp_proxy=http://example-proxy:80/"


Variables
---------
The goal of this section is to show many examples of setting and retrieving
variable values, in varous different locations.

Command-line::

  ansible-playbook example.yaml --extra-vars "foo=bar"

  ansible-playbook example.yaml --extra-vars "@even_more_vars.yaml"

  ansible-playbook example.yaml --extra-vars "@even_more_vars.json"

Playbook::

  ---
  - hosts: example
    vars:
      foo: bar
    tasks:
      - name: some task, bro
        ...

  ---
  - hosts: all
    vars_prompt:
      - name: username
        prompt: What is your username?
        private: false
      - name: password
        prompt: What is your password?

    tasks:
      - name: Print a message
        ansible.builtin.debug:
          msg: 'Logging in as {{ username }}'

  ---
  - hosts: example
    vars_files:
      - vars.yaml
    tasks:
      - name: some task, bro
        ...

  ---
  - hosts: example
    pre_tasks:
      - include_vars: "{{item}}"
        with_first_found:
          # lets assume you have multiple files with this naming convention
          # the ansible_os_family identifier is an ansible _fact_.
          - "apache_{{ansible_os_family}}.yml"
          - "apache_default.yml"
    tasks:
      - name: Ensure apache is running.
        service:
          # depends on which os_family is interpolated into varsfile name
          name: "{{apache_service_name}}"
          state: running

Inventory::

  [washington]
  app1.example.com proxy_state=present

  [washington:vars]
  cdn_host=washington.static.example.com
  api_version=3.0.1

Using automatically loaded ``(host|group)_vars`` files (eg ./group_vars/washington)::

  ---
  # these vars will be applied to all hosts in the washington group
  foo: bar
  baz: qux

Registering the output of a task as a new variable::

  - name: "Node: Check list of Node.js apps running."
    command: forever list
    register: forever_list
    changed_when: false

  - name: "Node: Start example Node.js app."
    command: forever start {{node_apps_location}}/app/app.js
    when: "forever_list.stdout.find(node_apps_location + '/app/app.js') == 1"

Accessing a registered variable::

  # Ansible uses the Jinja2 templating library to
  # interpolate variables into strings.

  # Strings
  #########
  "/opt/my-app/rebuild {{my_environment}}"

  # Lists
  ########
  # Get the first element of a list
  {{ foo[0] }}

  # Dicts/Objects
  ###############
  # There are two ways to access sub-elements in Jinja
  # and both of them will return either an attribute or
  # dict item, it doesn't matter which.

  # If you use the attribute reference operator, the attribute name
  # must be a valid identifier (no special chars), and cannot be a dunder.
  # Dunders are names like __init__, __mult__, or __whatever_maann__.
  {{ ansible_eth0.ipv4.address }}

  # Use the subscript operator if your keys not valid identifiers,
  # or are dunders, or shadow any of the known public attribute names.
  {{ ansible_eth0['ipv4']['address'] }}

  # Jinja2 filters
  ################
  https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_filters.html#playbooks-filters

Ansible defines a magic ``hostvars`` variable
containing all the defined host vars from all sources.


Advanced syntax
---------------

Escaping Jinja2
^^^^^^^^^^^^^^^
If you want to prevent Jinja2 from interpolating
values, you can use the unsafe type.

::

  ---
  mypass: !unsafe 234%234{435lkj{{lkjsdf

This is more comprehensive than excaping with
``{% raw %} ... {% endraw %}``.

You can mark values supplied by ``vars_prompt`` as
unsafe.

YAML anchors and aliases
^^^^^^^^^^^^^^^^^^^^^^^^
You define an anchor with &, then refer to it using an
alias, denoted with ``*``.

Here’s an example that sets three values with an
anchor, uses two of those values with an alias, and
overrides the third value:

::

  ---
  ...
  vars:
      app1:
          jvm: &jvm_opts
              opts: '-Xms1G -Xmx2G'
              port: 1000
              path: /usr/lib/app1
      app2:
          jvm:
              <<: *jvm_opts
              path: /usr/lib/app2
  ...

The value for path is merged by ``<<`` or merge operator.


Facts (variables derived from system information)
-------------------------------------------------
Ansible facts are data related to your remote systems, including operating
systems, IP addresses, attached filesystems, and more.

To see all facts, run ``ansible -m setup``.

You can access this data in the ``ansible_facts`` variable.

If you don't need facts, and would like to save a few seconds per host,
you can turn them off with::

  ---
  - hosts: db
    gather_facts: no


Local facts (facts.d)
---------------------
Another way to define host-specific facts is to place a ``*.fact`` file
in a special directory on the remote host, ``/etc/ansible/facts.d/``.

::

  # /etc/ansible/facts.d/settings.fact

  [users]
  admin=jane,john
  normal=jim

  # notice the filter argument

  $ ansible hostname -m setup -a "filter=ansible_local"
  munin.midwesternmac.com | success >> {
      "ansible_facts": {
          "ansible_local": {
              "settings": {
                  "users": {
                      "admin": "jane,john",
                      "normal": "jim"
                  }
              }
          }
      },
      "changed": false
  }


Vault
-----
Let's say we have an inventory that looks like this::

  ---
  hosts: all
  vars_files:
    - api_key.yaml
  tasks:
    - name: Echo API key.
      shell: echo "$API_KEY"
      environment:
        API_KEY: "{{ myapp_api_key }}"
      register: echo_result
    - name: Show the result.
      debug:
        var: echo_result.stdout

And a file named api_key.yaml that looks like this::

  ---
  myapp_api_key: "asdfaaaaasdf"

To encrypt it, we can use ``ansible-vault encrypt $x``.
Then, to use it with the playbook, we can run::

  $ ansible-playbook playbook.yaml --ask-vault-pass

(You can use ``-J`` for short.)

Some other useful vault commands::

  $ ansible-vault edit $x
  $ ansible-vault view $x
  $ ansible-vault encrypt_string $x

For automated playbook runs, you can supply the
password from a file. This is also a long-lived
secret, so don't check it into vcs.

::

  ∿ echo 'abcd' > vault_pass.txt
  ∿ ansible-vault view --vault-password-file=vault_pass.txt api_key.yaml


Variable precedence
-------------------
You can set variables in at least 22 different locations.
That's too much to remember.
How do you know which variable definition takes precedence?

In general, Ansible gives precedence to variables that
were defined more recently, more actively, and with
more explicit scope.

Here is an abbreviated version of the precedence rules, to give you an idea:
**-e > include params > role params > task > block > playbook > inventory > role defaults**.

.. Use g<C-a> to increment a column of numbers in Vim.

Where should you set variables when you're writing code?

* Roles should provide sane default values via the fole's ``defaults`` variables.
  These are the fallback.

* Playbooks should rarely define variables, prefer ``vars_files``, or less often, inventory.

* Only truly host/group specific variables should be defined in host/group inventories.

* Dynamic and static inventory sources should contain a minimum of variables.

* Command-line variables should be avoided when possible. Use it only for one-offs.


Breaking tasks into separate files
----------------------------------
There are a few tools you can use to split up tasks:

* ``import_tasks`` static, like import in Haskell.
* ``include_tasks`` dynamic, like include in C, or source in Bash.
* roles

Generally, I would prefer to use roles, but import/include may be useful some day.


Conditionals - if/then/when
---------------------------
::

  - name: Run with items greater than 5
    ansible.builtin.command: echo {{ item }}
    loop: [ 0, 2, 4, 6, 8, 10 ]
    when: item > 5

The when keywords
^^^^^^^^^^^^^^^^^
You can use these keywords in a task::

  when          # when to run a task
  changed_when  # when to consider a task as changed status
  failed_when   # when to consider a task as failed status
  ignore_errors

Creating expressions for when
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
You can use python operators within tests like when::

  == != >= <=
  and or not

Here's how you set variables as mandatory or optional.
This relies on functions provided by Jinja2::

  varname | mandatory      # make var mandatory
  varname | default(omit)  # make var optional
  varname | default(5)     # set default value if undefined
  varname is defined       # check if defined

Jinja2 provides a lot of functions, and you can
encode complicated logic in it if you want::

  # pretty print and convert to yaml
  varname | to_nice_yaml(indent=2, width=99999

  # find all matches
  'CAR\ntar\nfoo\nbar\n' | regex_findall('^.ar$', multiline=True, ignorecase=True)

  # change "ansible" to "able"
  'ansible' | regex_replace('^a.*i(.*)$', 'a\\1')

Docs here https://jinja.palletsprojects.com/en/3.1.x/templates/#builtin-filters

Ansible also provides functions through plugins::

  vars:
    file_contents: "{{ lookup('file', 'path/to/file.txt') }}"

A sidebar about transforming values
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
Can you register an transform a variable in one step?
For example, can you take a return value from shell
and gets the ``.stdout`` attribute, then assign that
to a registered var named output in one step?

No, but there is a feature proposal for projection,
which seems to do just that. It doesn't look like
anyone is actively working on it.

https://github.com/ansible/ansible/pull/72553

Selection constructs in jinja
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
::

  ---
  - name: set fact/case example
    hosts: localhost
    tasks:

      - set_fact:
          one:   hello
          two:   "{{ ansible_domain }}"
          three: "{{ ansible_distribution_file_variety }}"
          # the -%} strips whitespace
          DC: >
            {% if ansible_domain == 'eu-west-1.compute.internal' -%}
              DC1
            {% elif ansible_domain == 'eu-west-2.compute.internal' -%}
              DC2
            {% else -%}
              DC3
            {% endif %}

      - name: dc
        debug:
          msg: Your DC is {{ DC }}
        when: DC == 'DC2'

      - name: combine
        debug:
          msg: "{{ one }}-{{ two }}-{{ three }}-{{ DC }}"

..
  {% ... %} statements
  {{ ... }} expressions
  {# ... #} comments


Delegation, local actions, and pauses
-------------------------------------
https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_delegation.html

Take a box out of the load balancer pool,
update it, and then return it to the pool.
The argument to ``delegate_to`` is an ip
or hostname to perform the task on.

::

  ---
  - hosts: webservers
    serial: 5

    tasks:
      - name: Take out of load balancer pool.
        ansible.builtin.command: /usr/bin/take_out_of_pool {{ inventory_hostname }}
        delegate_to: {{ lb_endpoint }}

      - name: Actual steps would go here.
        ansible.builtin.yum:
          name: acme-web-stack
          state: latest

      - name: Add back to load balancer pool.
        ansible.builtin.command: /usr/bin/add_back_to_pool {{ inventory_hostname }}
        delegate_to: {{ lb_endpoint }}

If you're delegating to localhost, Ansible has a
shorthand you can use, ``local_action``.

.. TODO Make sure you're using local_action correctly, look for examples
::

  - name: Update local repo on host machine
    local_action:
      module: git
      src: https://github.com/kingparra/hpfp
      dest: ~/Projects/hpfp

Pausing playbook execution with ``wait_for``
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
::

    - name: Wait for web server to start
      local_action:
        module: wait_for
        host: "{{ inventory_hostname }}"
        port: "{{ webserver_port }}"
        delay: 10
        timeout: 300
        state: started

Running an entire playbook locally
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
::

  $ ansible-playbook playbook.yaml --connection=local


Prompts
-------
Prompts are a simple way to gather user-specific
information, but in most cases, you should avoid
them.

::

  ---
  - hosts: all
    vars_prompt:
      - name: share_user
        prompt: What is your network username?

Useful options:

* ``private`` disables echo
* ``default`` set def val
* ``confirm`` force user to enter text twice


Tags
----
::

  - name: Notify on completion.
    local_action:
      module: osx_say
      msg: "{{inventory_hostname}} is finished!"
      voice: Zarvox
    tags:
      - notifications
      - say

  $ ansible-playbook playbook.yaml --tag notifications

  $ ansible-playbook playbook.yaml --skip-tags say


Blocks
------
If you want to perform a series of tasks with one set
of task parameters (with_items, when, become) applied
blocks are quite handy.

::

  - name: Install and configure apache on RHEL/CentOS hosts.
    block:
      - dnf: name=httpd state=present
      - template: src=httpd.conf.j2 dest=/etc/httpd/conf/httpd.conf
      - service: name=httpd state=started enabled=yes
    when: ansible_os_family == 'RedHat'
    become: yes

They're also useful to handle task failures.

::

  - block:
      - name: Script to connect the app to a monitoring service
        script: monitoring-connect.sh
    rescue:
      - name: This will only run in case of an error in the block.
        debug: msg="There was an error in the block."
    always:
      - name: This will always run, no matter what.
        debug: msg="This always executes."

Looks like a try/except/else/finally block, huh?

