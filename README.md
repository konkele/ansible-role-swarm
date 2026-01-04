# Ansible Role: Swarm

The **`swarm` role** installs and configures a highly available Docker Swarm cluster with optional Keepalived virtual IPs (VIPs) and host-level DNS adjustments. It is designed to be **cluster-aware, defensive, and deterministic**, and is safe for repeated execution across large inventories and first-time runs.

The role is **idempotent by default** and includes internal guards to ensure that optional components (such as Keepalived) are only installed, configured, or stopped when explicitly enabled via variables.

---

## Features

### Swarm Cluster Management

* Detects managers and workers from inventory
* Deterministic leader selection based on inventory ordering
* Initializes the Swarm on the first manager only
* Idempotent joins for managers and workers
* Optional forced leave and rejoin per node via `swarm_force_rejoin`

### Automatic Node Pruning

* Detects stale managers and workers
* Enforces quorum safety before pruning managers
* Optional automatic pruning of nodes in `down`, `unreachable`, or `unknown` states

### Keepalived VIP Management

* Optional, opt-in Keepalived configuration
* Configurable VRRP instances and VIPs
* Health check scripts with weighted failover
* Automatically scoped to Swarm managers only
* Safe first-run behavior:

  * Keepalived is **not installed** unless configured
  * Keepalived is **stopped and disabled** only if already installed

### DNS Adjustments

* Optional disabling of `systemd-resolved` DNSStubListener
* Correct `/etc/resolv.conf` symlink for container DNS
* Allows DNS containers (e.g., AdGuard, CoreDNS) to bind to port 53

### Defensive Defaults

* Swarm quorum enforcement enabled by default
* Automatic node pruning enabled by default
* Keepalived disabled unless explicitly configured
* All destructive actions guarded by inventory intent and runtime checks

---

## Requirements


* **Ansible 2.14+**
* **Ubuntu 22.04 or 24.04**
* **Docker** – required for Swarm functionality.
The role will **automatically install Docker** if it is not already present, so a separate Docker role is **not required**. This includes:
  * `docker-ce` and `docker-ce-cli`
  * `containerd.io`
  * `docker-compose-plugin`
  * Necessary system packages (`ca-certificates`, `curl`, `gnupg`, `lsb-release`)


> **Note:** If Docker is already installed, the role will detect it and skip installation.

---

## Role Variables

All defaults are defined in `defaults/main.yml`.

### Swarm Variables

| Variable                        | Default                        | Description                                   |
| ------------------------------- | ------------------------------ | --------------------------------------------- |
| `swarm_cluster_name`            | `default`                      | Inventory-based cluster name prefix           |
| `swarm_quorum_enforce`          | `true`                         | Prevent manager pruning if quorum is violated |
| `swarm_force_rejoin`            | `false`                        | Force local node to leave and rejoin Swarm    |
| `swarm_auto_prune`              | `true`                         | Automatically remove stale nodes              |
| `swarm_prune_states`            | `[down, unreachable, unknown]` | Node states considered stale                  |
| `swarm_disable_dnsstublistener` | `false`                        | Disable systemd DNSStubListener               |

### Keepalived Variables

| Variable                       | Default             | Description                                  |
| ------------------------------ | ------------------- | -------------------------------------------- |
| `keepalived_script_user`       | `keepalived_script` | User for Keepalived health check scripts     |
| `keepalived_script_user_group` | `docker`            | Group for Keepalived health check scripts    |
| `keepalived_instances`         | `[]`                | VRRP instances and VIP definitions           |
| `keepalived_scripts`           | `[]`                | Health check scripts referenced by instances |

> **Note:** Keepalived is considered *enabled* only when `keepalived_instances` is non-empty.

---

## Inventory Groups

The role expects the following inventory groups:

* `<swarm_cluster_name>_managers` (required)
* `<swarm_cluster_name>_workers` (optional)

### Example

```ini
[default_managers]
swarm1.example.com
swarm2.example.com

[default_workers]
swarm3.example.com
```

---

## Example Playbook

```yaml
- name: Configure Docker Swarm cluster
  hosts: all
  become: true
  roles:
    - role: docker
    - role: swarm
```

---

## Example Keepalived Configuration

```yaml
# Health check scripts
keepalived_scripts:
  - name: generic_service_check
    script: "/etc/keepalived/chk_docker_label.sh keepalived.vip=service"
    interval: 2        # seconds between checks
    timeout: 2         # check timeout in seconds
    fall: 2            # consecutive failures before script is considered failed
    rise: 3            # consecutive successes before script is considered healthy
    weight: -20        # priority adjustment on failure

# VRRP instance and virtual IP
keepalived_instances:
  - name: generic_vip
    interface: "{{ ansible_default_ipv4.interface }}"   # network interface to bind VIP
    vrid: 100                # unique VRRP ID in the cluster
    priority: 100            # starting priority for this node
    advert_int: 1            # advertisement interval in seconds
    auth_pass: "securepass" # password for VRRP authentication
    vips:
      - address: "192.168.1.100"  # virtual IP address
        cidr: 24                   # subnet mask
    track_scripts:
      - generic_service_check
```

---

## Operational Notes

* Inventory expresses **desired cluster membership**, not transient runtime state
* Leader selection is deterministic and repeatable
* All pruning operations are quorum-safe by default
* Forced leave/rejoin is **host-scoped** and should be used sparingly
* Keepalived is fully optional and self-guarding
* DNS changes are reversible and opt-in

---

## Exposed Facts

The role sets the following facts for downstream use:

* `first_swarm_manager` – Inventory hostname of the elected leader
* `is_first_swarm_manager` – Boolean leader flag
* `safe_stale_manager_ids` – Manager node IDs safe to prune
* `stale_worker_ids` – Worker node IDs safe to prune

These facts may be consumed by monitoring, reporting, or higher-level orchestration roles.
