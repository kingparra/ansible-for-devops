****************************************************
 Chapter 7: Ansible plugins and content collections
****************************************************

Content collections are a distribution format for Ansible content that can include
playbooks, roles, modules, and plugins.

Projects associated with this chapter:

* test-plugin: A simple test plugin that verifies a given value is representative of the color blue.
* collection: An example local collection to demonstrate the basic structure of content collections.


Creating our first Ansible plugin - A jinja filter
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
If you start writing complex jinja filters that look almost like Python in YAML format,
it's time to modularize that logic into a plugin.

Project tree that was created with the ``ansible-galaxy collection init
local.colors --init-path ./collections/ansible_collections``.

::

  (ansible-venv) ∿ tree --dirsfirst --noreport --gitignore -I __pycache__
  .
  ├── collection
  │   ├── collections
  │   │   └── ansible_collections
  │   │       └── local
  │   │           └── colors
  │   │               ├── plugins
  │   │               │   └── test
  │   │               │       └── blue.py
  │   │               └── galaxy.yml
  │   ├── main.yml
  │   └── README.md

Contents of ``blue.py``. Because blue is a test plugin, the
entry point to the program is the ``TesetModule`` class::

  # Ansible custom 'blue' test plugin definition.

  def is_blue(string):
      ''' Return True if a valid CSS value of 'blue'. '''
      blue_values = [
          'blue',
          '#0000ff',
          '#00f',
          'rgb(0,0,255)',
          'rgb(0%,0%,100%)',
      ]
      if string in blue_values:
          return True
      else:
          return False

  class TestModule(object):
      ''' Return dict of custom jinja tests. '''

      def tests(self):
          return {
              'blue': is_blue
          }

To use the collection, you must modify the playbook::

  ---
  - hosts: all
    collections:
      - local.colors
    vars:
      my_color_choice: blue
    tasks:
      - name: "Verify {{ my_color_choice }} is a form of blue."
        assert:
          that: my_color_choice is local.colors.blue

Notice that you had to use the fully-qualified collection name when calling the
test plugin.

Where are collections installed to on the FS?
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
* ``~/.ansible/collections``
* ``/usr/share/ansible/collections``

You can change this in ``ansible.cfg`` with the ``collections_path`` directive.

