# Configuration DNS Cloudflare

## Enregistrements A requis

Remplacez `YOUR_K3S_IP` par l'IP publique de votre VM K3s.

| Type | Nom | Valeur | Proxy | TTL |
|------|-----|--------|-------|-----|
| A | vault1.keltio.fr | YOUR_K3S_IP | ❌ OFF | Auto |
| A | status.keltio.fr | YOUR_K3S_IP | ❌ OFF | Auto |
| A | prometheus.keltio.fr | YOUR_K3S_IP | ❌ OFF | Auto |
| A | pgadmin.solya.app | YOUR_K3S_IP | ❌ OFF | Auto |

## ⚠️ Important

- **Proxy DÉSACTIVÉ** : Le nuage orange doit être gris/désactivé
- **SSL/TLS** : Mode "Full (strict)" recommandé
- **Always Use HTTPS** : Activé

## Configuration via API Cloudflare

```bash
# Variables
CLOUDFLARE_EMAIL="your-email@example.com"
CLOUDFLARE_API_KEY="your-global-api-key"
ZONE_ID="your-zone-id"
K3S_IP="your-k3s-ip"

# Fonction pour créer un enregistrement
create_dns_record() {
    local name=$1
    local ip=$2
    
    curl -X POST "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records" \
        -H "X-Auth-Email: $CLOUDFLARE_EMAIL" \
        -H "X-Auth-Key: $CLOUDFLARE_API_KEY" \
        -H "Content-Type: application/json" \
        --data "{\"type\":\"A\",\"name\":\"$name\",\"content\":\"$ip\",\"proxied\":false}"
}

# Créer les enregistrements
create_dns_record "vault1.keltio.fr" "$K3S_IP"
create_dns_record "status.keltio.fr" "$K3S_IP"
create_dns_record "prometheus.keltio.fr" "$K3S_IP"
create_dns_record "pgadmin.solya.app" "$K3S_IP"
```

## Vérification

```bash
# Tester la résolution DNS
dig vault1.keltio.fr +short
dig status.keltio.fr +short
dig prometheus.keltio.fr +short
dig pgadmin.solya.app +short

# Ou avec nslookup
nslookup vault1.keltio.fr
nslookup status.keltio.fr
```
