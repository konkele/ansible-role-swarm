# Ansible Role: Swarm

The **`swarm` role** installs and configures a highly available Docker Swarm cluster with optional Keepalived VIPs and DNS adjustments. It is designed to be **cluster-aware and deterministic**, safe for repeated execution across large inventories.

This role is **idempotent** and enforces **quorum-aware pruning**, safe node joins, and optional forced rejoin for stale or reset nodes.

---

## Features

* **Swarm Cluster Management**

  * Detect managers and workers from inventory
  * Deterministic leader selection
  * Initialize Swarm on first manager only
  * Idempotent joins for managers and workers
  * Forced leave and rejoin per node via `swarm_force_rejoin`

* **Automatic Node Pruning**

  * Detect stale managers and workers
  * Enforce quorum when pruning
  * Optional auto-prune of nodes in `down`, `unreachable`, or `unknown` states

* **Keepalived VIPs**

  * Configurable VRRP instances
  * Health check scripts with failover weighting
  * Automatic configuration for swarm managers

* **DNS Adjustments**

  * Optional disabling of `DNSStubListener`
  * Correct `/etc/resolv.conf` symlink for container DNS
  * Enables a DNS server container to run on the cluster without port 53 bind conflicts

* **Safe Defaults**

  * Swarm quorum enforced by default
  * Auto-pruning enabled by default
  * DNS stub listener disabled by default

---

## Requirements

* **Ansible 2.14+**
* **Ubuntu 22.04 or 24.04**
* **Docker role dependency**: [ansible-role-docker](https://github.com/konkele/ansible-role-docker)

---

## Role Variables

All defaults are defined in `defaults/main.yml`.

| Variable                        | Default                        | Description                                    |
| ------------------------------- | ------------------------------ | ---------------------------------------------- |
| `swarm_cluster_name`            | `default`                      | Inventory-based cluster prefix                 |
| `swarm_quorum_enforce`          | `true`                         | Enforce quorum for manager pruning             |
| `swarm_force_rejoin`            | `false`                        | Force local node to leave and rejoin Swarm     |
| `swarm_auto_prune`              | `true`                         | Automatically remove stale nodes               |
| `swarm_prune_states`            | `[down, unreachable, unknown]` | Node states considered stale                   |
| `swarm_disable_dnsstublistener` | `true`                         | Disable systemd DNSStubListener for containers |
| `keepalived_script_user`        | `keepalived_script`            | User for keepalived health check scripts       |
| `keepalived_scripts`            | Configurable list              | Health check scripts for VIP tracking          |
| `keepalived_instances`          | Configurable list              | VRRP instances with VIPs and tracking scripts  |

### Example host variable override for forced rejoin

```yaml
# host_vars/swarm2-dev.yml
swarm_force_rejoin: true
```

> **Note:** Applying `swarm_force_rejoin: true` to all hosts will cause every node to leave and rejoin the Swarm. This can temporarily reduce availability and is **not recommended** for all nodes simultaneously.

---

## Inventory Groups

The role expects the following inventory groups:

* `<swarm_cluster_name>_managers`
* `<swarm_cluster_name>_workers` (optional)

### Example

```ini
[default_managers]
swarm1-dev.lab.konkel.us
swarm2-dev.lab.konkel.us

[default_workers]
swarm3-dev.lab.konkel.us
```

---

## Example Playbook

```yaml
- name: Setup Docker Swarm Cluster with Keepalived
  hosts: all
  become: true
  roles:
    - role: docker
    - role: swarm
```

---

## Design Principles

* Inventory expresses **intent**, not final state
* Swarm leader selection is **deterministic** and cluster-aware
* Node pruning respects **quorum** to avoid accidental outages
* Forced leave/rejoin is **optional and host-scoped**
* Keepalived configuration is **idempotent and manager-scoped**
* DNS adjustments are optional, container-safe, and reversible

---

## Tags

| Tag          | Description                               |
| ------------ | ----------------------------------------- |
| `swarm`      | Core swarm management (init, join, prune) |
| `keepalived` | VRRP VIPs and health checks               |
| `dns`        | DNSStubListener adjustments               |

---

## Outputs

The role exposes the following facts:

* `first_swarm_manager` – Inventory hostname of the deterministic leader
* `is_first_swarm_manager` – Boolean flag for leader node
* `safe_stale_manager_ids` – List of manager IDs safe to prune
* `stale_worker_ids` – List of worker IDs safe to prune

These facts can be used in downstream automation, monitoring, or debugging tasks.
