node_name = "consul-client-{{ ansible_hostname }}"
datacenter = "dc1"
data_dir   = "/opt/consul/data"
log_level  = "INFO"
connect {
  enabled = true
}
verify_incoming = true
verify_outgoing = true
verify_server_hostname = true
ca_file = "/etc/consul.d/tls/consul-agent-ca.pem"
cert_file = "/etc/consul.d/tls/dc1-client-consul-0.pem"
key_file = "/etc/consul.d/tls/dc1-client-consul-0-key.pem"
