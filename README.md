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
* Correctly calculates maximum safe manager removals
* Optional automatic pruning of nodes in `down`, `unreachable`, or `unknown` states

### Keepalived VIP Management

* Optional, opt-in Keepalived configuration
* Keepalived is managed **only when `keepalived_instances` is defined and non-empty**
* Automatically installs Keepalived when enabled
* Stops and disables Keepalived if configuration is removed
* Configurable VRRP instances and VIPs
* Health check scripts with weighted failover
* Supports Docker label-based VIP elections via included helper script
* Automatically scoped to Swarm managers only
* Safe first-run behavior:

  * Keepalived is **not installed** unless configured

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
* `python3-docker`
* `python3-jsondiff`
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

> **Keepalived is enabled only when `keepalived_instances` is non-empty.**

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
    - role: swarm
```

---

## Docker Label-Based VIP Elections

The role includes a helper script:

```
/etc/keepalived/chk_docker_label.sh
```

This allows Keepalived to determine VIP ownership based on running Docker containers with a specific label.

Example usage in `keepalived_scripts`:

```yaml
keepalived_scripts:
  - name: adguard_vip_check
    script: "/etc/keepalived/chk_docker_label.sh keepalived.vip=adguard"
    interval: 2
    timeout: 2
    fall: 2
    rise: 3
    weight: -20
```

Any node running a container with:

```
--label keepalived.vip=adguard
```

will become eligible to hold the VIP.

This enables application-aware VIP failover driven directly by Docker scheduling.

---

## Example Keepalived Configuration

```yaml
keepalived_instances:
  - name: generic_vip
    interface: "{{ ansible_default_ipv4.interface }}"
    vrid: 100
    priority: 100
    advert_int: 1
    auth_pass: "securepass"
    vips:
      - address: "192.168.1.100"
        cidr: 24
    track_scripts:
      - adguard_vip_check
```

---

## Operational Notes

* Inventory expresses **desired cluster membership**, not transient runtime state
* Leader selection is deterministic and repeatable
* All pruning operations are quorum-safe by default
* Safe manager removal calculations prevent accidental quorum loss
* Forced leave/rejoin is **host-scoped** and should be used sparingly
* Keepalived is fully optional and self-guarding
* VIP ownership can be driven dynamically from Docker labels
* DNS changes are reversible and opt-in

---

## Exposed Facts

The role sets the following facts for downstream use:

* `first_swarm_manager` – Inventory hostname of the elected leader
* `is_first_swarm_manager` – Boolean leader flag
* `safe_stale_manager_ids` – Manager node IDs safe to prune
* `stale_worker_ids` – Worker node IDs safe to prune

These facts may be consumed by monitoring, reporting, or higher-level orchestration roles.
