# Inventaire Ansible généré automatiquement par Terraform
# Ne pas modifier manuellement - sera écrasé lors du prochain 'terraform apply'

[k3s_servers]
%{ for host, config in ansible_inventory.hosts ~}
${host} ansible_host=${config.ansible_host} ansible_user=${config.ansible_user} ansible_ssh_private_key_file=${config.ansible_ssh_private_key_file} ansible_ssh_common_args="${config.ansible_ssh_common_args}"
%{ endfor ~}

[k3s_servers:vars]
%{ for key, value in ansible_inventory.vars ~}
${key}=${value}
%{ endfor ~}

[all:vars]
# Configuration globale
ansible_python_interpreter=/usr/bin/python3
ansible_ssh_pipelining=true
ansible_ssh_retries=3
host_key_checking=false
