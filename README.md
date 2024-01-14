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

Generate a pass around TLS files so that the service can talk in an encrypted manner.



## Health checks 

The health checks in for the consul service have been provided so we can see the progress we are making towards the desired state. Test driven development and all of that jazz.