# Ansible variables generated automatically by Terraform
# Do not modify manually - will be overwritten on next 'terraform apply'

# Instance information
instance_name: "${instance_name}"
instance_type: "${instance_type}"
public_ip: "${public_ip}"
environment: "${environment}"

# Tool versions
k3s_version: "${k3s_version}"
kubectl_version: "${kubectl_version}"
helm_version: "${helm_version}"

# K3s configuration
k3s_server_location: "/var/lib/rancher/k3s"
k3s_config_file: "/etc/rancher/k3s/k3s.yaml"
k3s_token_file: "/var/lib/rancher/k3s/server/node-token"

# Cluster configuration
k3s_server_args:
  - "--write-kubeconfig-mode=644"
  - "--disable=traefik"  # We use nginx-ingress
  - "--disable=servicelb" # We manage services ourselves
  - "--disable-cloud-controller"
  - "--kubelet-arg=eviction-hard=imagefs.available<1%,nodefs.available<1%"
  - "--kubelet-arg=eviction-minimum-reclaim=imagefs.available=1%,nodefs.available=1%"

# Helm configuration
helm_repositories:
  - name: ingress-nginx
    url: https://kubernetes.github.io/ingress-nginx
  - name: jetstack
    url: https://charts.jetstack.io
  - name: external-dns
    url: https://kubernetes-sigs.github.io/external-dns/
  - name: external-secrets
    url: https://charts.external-secrets.io
  - name: bitnami
    url: https://charts.bitnami.com/bitnami

# Scaleway credentials for External DNS
scaleway_access_key: "${scaleway_access_key}"
scaleway_secret_key: "${scaleway_secret_key}"
scaleway_organization_id: "${scaleway_organization_id}"
scaleway_project_id: "${scaleway_project_id}"

# Network configuration
pod_cidr: "10.42.0.0/16"
service_cidr: "10.43.0.0/16"
cluster_dns: "10.43.0.10"

# Resource limits
max_pods_per_node: 110

# Logging configuration
log_level: "info"
audit_log_enabled: false
