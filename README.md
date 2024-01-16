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

Set up a handler for Consul so that if the config is changed in any of the roles it is restarted.

### Part 6. Generate encryption key

Use command block to show that you can just execute custom commands on the server if there isn't a module available.

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