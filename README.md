# Ansible Playground

## Playground links

## Lab

### Part 1. Defining inventory

Set up the inventory file with the hosts that we will be using for the playground and structure into groups
Show that the inventory is valid by running the ping command.

### Part 2. Base set up 

Use ansible to install required system packages and define the user and directories on the remote hosts.
Demonstrate deleting one of the directories and getting ansible to recreate it.

### Part 3. Pulling in data from outside of Ansbible 

Download and unzip Consul binaries using the uri modules

### Part 4. Templating

Set up a unit file for Consul using the J2 templating avalibe in Ansible 

### Part 5. Handlers

Set up a handler for Consul so that if the config is changed in any of the roles the Consul service is restarted.
For this step we will firstly be working in `roles/consul-common` and then `roles/consul-client/tasks/main.yaml` & `roles/consul-server/tasks/main.yaml`. 

1. Create a handler which will restart the Consul service if any config changes are made that might affect it.
- Add the below block to `roles/consul-common/handlers/main.yaml`: 
    ```
  - name    : Restart consul service
    service :
      name    : consul.service
      state   : restarted
      enabled : true
    ```

2. Notify the handler to restart the Consul service by adding the `notify` statement to any play that would require a service restart.
This will call the handler to trigger the restart at the end of that role group execution if a change is made by that play.

- In the `roles/consul-common/tasks/main.yaml` file, add the below line to the following tasks; `Expand consul binary`, `Create common consul config file` and `Create consul service file`:
    ```
    notify    : Restart consul service
    ```
- This should be indented at the same level as `name`.

3. The handler has already been created for the `consul-client` and `consul-server` roles. We just need to add the `notify` statements.
- Add the below `notify` statement:
    ```
    notify   : Restart consul service
    ```
- To the following files:
  - `consul-client` role tasks file in `roles/consul-client/tasks/main.yaml` 
  - `consul-server` role tasks file in `roles/consul-server/tasks/main.yaml`

### Part 6. Generate encryption key

Use command block to show that you can just execute custom commands on the server if there isn't a module available.

This needs to be done in the `consul-common` role in: `roles/consul-common/tasks/main.yaml` as it is required for the config files generated as part of the role

1. To store the encryption key, we're currently placing in a file on the server. So before doing anything, we want to check whether this file already exists.
To do this, we will use the `stat` module to register a variable (using the `register` attribute) for later plays.
Place the following block after the `Create directories for consul` play:
```
- name     : Check for encryption key
  stat     :
    path : "{{ encryption_key_file }}"
  register : key_file_present 
  when     : ("consul_servers" in group_names)
```

2. If there is not an encryption key already present, we will want to generate a new one.
This is done through a Consul command in which we will use a `shell` command to execute directly on the server.
Add the following block directly below the block from step 1:
```
- name    : Generate encryption key
  shell   : consul keygen
  register : consul_encryption_key
  when     : not key_file_present.stat.exists and ("consul_servers" in group_names)
  run_once : true
```

3. If we have generated a new encryption key, we want to store it in a file on one of the servers.
We can make use of the `copy` module to achieve this.
Add the following block directly below the block from step 2:
```
- name     : Store in local file
  copy     :
    content : "{{consul_encryption_key.stdout}}"
    dest    : "{{ encryption_key_file }}"
    mode    : 0600
  when     : not key_file_present.stat.exists and ("consul_servers" in group_names)
  run_once : true
```

4. Register the contents of the file (that contains the encryption key) to a variable.
```
- name     : Cat encryption key
  shell    : cat {{ encryption_key_file }}
  register : consul_encryption_key
  when     : ("consul_servers" in group_names)
  run_once : true
```

5. We want to update the value in our common config template (in `templates/common-config.hcl.j2`) to use the new encryption key that we're now dynamically generating.
Replace:
```
encrypt = "bGlrZSwgc2hhcmUsIHN1YnNjcmliZSBhbmQgYmVsbAo="
```
With:
```
encrypt = "{{ consul_encryption_key.stdout }}"
```

### Part 7. TLS time 

Generate and pass around TLS files so that the service can talk in an encrypted manner.

Add a `consul-tls` role to the main playbook `main.yaml` (in root directory):
```
- name: Consul internal networking encryption
  hosts: all
  become: true
  roles: 
    - consul-tls
```

In `roles/consul-tls/tasks/main.yaml` start adding the tasks to:

1. Generate TLS directories
```
- name : Create TLS directories
  file :
    path  : "{{ consul_tls_dir }}"
    state : directory
    owner : "{{ consul_user  }}"
    group : "{{ consul_user }}"
    mode  : "0750"
```

2. Initialise the Consul Certificate Authority
```
- name: Initialise consul's CA
  command:
    cmd: consul tls ca create
    creates: consul-agent-ca-key.pem
    chdir: "{{ consul_tls_dir }}"
  run_once: true
  when: ("consul_servers" in group_names)
  notify: Restart Consul
```

3. Create the required Consul client and server certificates
```
- name     : Generate server certs
  command  :
    cmd     : consul tls cert create -server 
    creates : dc1-server-consul-0-key.pem
    chdir   : "{{ consul_tls_dir }}"
  run_once : true
  when: ("consul_servers" in group_names)
  notify: Restart Consul

- name: Change the key permissions
  file:
    path: "{{ consul_tls_dir }}/dc1-server-consul-0-key.pem"
    group: "{{ consul_user }}"
    mode: "0640"
  run_once: true
  when: ("consul_servers" in group_names)
  
- name: Generating client certificates
  command:
    cmd: consul tls cert create -client 
    creates: dc1-client-consul-0-key.pem
    chdir: "{{ consul_tls_dir }}"
  run_once: true
  when: ("consul_servers" in group_names)

- name: Change dc1-client-consul-0-key.pem permission
  file:
    path: "{{ consul_tls_dir }}/dc1-client-consul-0-key.pem"
    group: consul
    mode: "0640"
  run_once: true
  when: ("consul_servers" in group_names)
```

4. We now need to transfer the client certificates over to the client
```
- name: Archive the tls directory for client
  archive:
    path: 
      - "{{ consul_tls_dir }}/dc1-client-consul-0.pem"
      - "{{ consul_tls_dir }}/dc1-client-consul-0-key.pem"
      - "{{ consul_tls_dir }}/consul-agent-ca.pem"
    dest: "{{ consul_tls_dir }}-client.tgz"
    mode: "0600"
  run_once: true
  when: ("consul_servers" in group_names)

- name: Register tls zipped directory
  command:
    cmd: cat {{ consul_tls_dir }}-client.tgz
  register: CLIENTTLS
  run_once: true
  when: ("consul_servers" in group_names)

- name: Load TLS into every Consul Client
  copy:
    dest: "{{ consul_tls_dir }}-client.tgz"
    content: "{{ CLIENTTLS.stdout }}"
    mode: "0600"
  when: ("consul_clients" in group_names)

- name: Unzip the client certificates
  unarchive:
    src: "{{ consul_tls_dir }}-client.tgz"
    dest: "{{ consul_tls_dir }}"
    remote_src: true
    creates: "{{ consul_tls_dir }}/dc1-client-consul-0-key.pem"
  when: ("consul_clients" in group_names)
  notify: Restart Consul
```

Run the ansible playbook to apply your configuration
```
ansible-playbook -i inventory main.yaml
```


## Health checks 

The health checks in for the consul service have been provided so we can see the progress we are making towards the desired state. Test driven development and all of that jazz.