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

Playbook::

  ---
  - hosts: example
    vars:
      foo: bar
    tasks:
      - name: some task, bro
        ...

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

Using ``(host|group)_vars`` files (eg ./group_vars/washington)::

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

  "/opt/my-app/rebuild {{my_environment}}"

  {{ ansible_eth0.ipv4.address }}

  {{ ansible_eth0['ipv4']['address'] }}


