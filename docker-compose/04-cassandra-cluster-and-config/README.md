# Example 04 — Self-hosted AxonOps with alerts configured as code

**English** | [Français](README.fr.md)

<p align="center">
  <a href="https://axonops.com"><img src="https://digitalis-marketplace-assets.s3.us-east-1.amazonaws.com/axonops-small-logo.png" alt="AxonOps" height="60"></a>
</p>

Self-hosted AxonOps monitoring one Apache Cassandra node, with alert rules
applied from a file instead of clicked into the dashboard. The stack is
[example 01](../01-cassandra-cluster/) cut down to a single monitored node, plus
one extra container that runs an Ansible playbook against the AxonOps API and
then exits.

Use it when you want your alerting to live in git: reviewable, repeatable, and
identical across every cluster you run.

## Quick start

```bash
cp env.example .env          # set AXONOPS_ORG_NAME
docker compose up -d
docker compose logs -f config
open http://localhost:3000
```

The `config` container starts last, applies [`config.yaml`](config.yaml), and
exits. `docker compose ps` showing it as `Exited (0)` is success — it is a
one-shot job, not a service. In the dashboard the rules appear under
**Alerts → Rules** for your cluster.

Roughly 6 GB of RAM at the defaults. Five long-running containers.

## What it runs

| Service | Image | Purpose |
|---|---|---|
| `axondb-timeseries` | `ghcr.io/axonops/axondb-timeseries` | Cassandra, metrics store for AxonOps |
| `axondb-search` | `ghcr.io/axonops/axondb-search` | OpenSearch, log and event store |
| `axon-server` | `registry.axonops.com/axonops-public/axonops-docker/axon-server` | AxonOps backend, agent endpoint on 1888 |
| `axon-dash` | `registry.axonops.com/axonops-public/axonops-docker/axon-dash` | Dashboard on 3000, also proxies the API |
| `cassandra` | `ghcr.io/axonops/cassandra/cassandra` | The monitored node, Cassandra + agent |
| `config` | `ghcr.io/axonops/axonops-ansible-ee` | One-shot. Applies `config.yaml`, then exits |

The `config` image is the AxonOps Ansible execution environment. It already
contains Ansible and the [`axonops.axonops`](https://galaxy.ansible.com/ui/repo/published/axonops/axonops/)
collection, so nothing is installed at run time and the container needs no
volumes beyond the playbook itself.

## Editing the alerts

Change [`config.yaml`](config.yaml), then re-apply:

```bash
docker compose run --rm config
```

The playbook is idempotent — running it twice changes nothing the second time —
so it is safe to run on every deploy. To apply only part of it, override the
command and use the role's tags:

```bash
docker compose run --rm config \
  ansible-playbook -i localhost, --connection=local -v /config.yaml --tags metrics
```

Tags: `metrics`, `log_alerts`, `service_checks`, `routes`, `slack`, `teams`,
`pagerduty`, `backups`, `adaptive_repair`, `dashboards`.

## Metric alert rules

A metric alert watches one chart on one dashboard — the same names shown in the
AxonOps UI — and fires when the value crosses a threshold for longer than
`duration`:

```yaml
axonops_alert_rules:
  - name: CPU usage per host
    dashboard: System
    chart: CPU usage per host
    operator: '>='
    warning_value: 90
    critical_value: 99
    duration: 1h
    description: Sustained high CPU on a Cassandra host
```

| Field | Required | Notes |
|---|---|---|
| `name` | yes | Shown in the UI and used to match the rule on re-apply |
| `dashboard` | yes | Dashboard name, exactly as the UI spells it |
| `chart` | yes | Chart name on that dashboard, exactly as the UI spells it |
| `operator` | yes | `>=`, `<=`, `>`, `<`, `==`, `!=`. Quote it, or YAML reads it as a tag |
| `warning_value` | yes | Threshold for a warning |
| `critical_value` | yes | Threshold for a critical alert |
| `duration` | yes | How long the condition must hold: `5m`, `15m`, `1h` |
| `description` | no | Say what it means for the operator, not what the metric is |
| `present` | no | `false` deletes the rule. Default `true` |
| `scope`, `dc`, `rack`, `host_id`, `keyspace` | no | Narrow the rule to part of the cluster |
| `group_by`, `percentile`, `consistency` | no | Match how the chart aggregates |
| `routing` | no | Send this rule somewhere other than the default route |

`dashboard` and `chart` must match the UI character for character. A typo is not
an error — the rule is created and simply never evaluates.

## Beyond metric alerts

`config.yaml` ships the rest commented out. Uncomment what you need:

- **`axonops_log_alert_rule`** — alert on the volume of matching log lines the
  agent ships (`content`, `level`, `type`, `source`).
- **`axonops_tcp_check`** / **`axonops_shell_check`** — service checks that run
  on the monitored node via its agent and alert when they fail.
- **`axonops_slack_integrations`** — a notification target. The webhook is a
  secret: put it in `.env` as `SLACK_WEBHOOK_URL`, which the `config` service
  passes through to the playbook. Never inline it.
- **`axonops_alert_routes`** — send a severity to an integration.

The same role also manages backups, adaptive repair, commitlog archiving,
dashboards, and PagerDuty and Teams integrations. See the
[collection documentation](https://github.com/axonops/axonops-ansible-collection).

## Configuration

Everything is set in `.env`; no file in this directory needs editing to run.
See [`env.example`](env.example) for the full list with defaults.

| Variable | Default | Notes |
|---|---|---|
| `AXONOPS_ORG_NAME` | `example` | Organisation. The agent, axon-server and the config container must agree |
| `CASSANDRA_CLUSTER_NAME` | `demo-cluster` | Cluster the alert rules attach to |
| `CASSANDRA_IMAGE` | `ghcr.io/axonops/cassandra/cassandra:5.0.8-2.0.31-1.1.0` | Monitored node image |
| `CASSANDRA_HEAP_SIZE` | `1G` | Development value |
| `AXONOPS_DB_PASSWORD` | `axonops` | Change it. The default is public |
| `AXONOPS_SEARCH_PASSWORD` | `MyS3cur3P@ss2025` | Change it. The image enforces a password policy |
| `AXONOPS_LICENSE_KEY` | empty | Optional; trial mode without it |
| `SLACK_WEBHOOK_URL` | empty | Only needed for the Slack block in `config.yaml` |

## Troubleshooting

**`config` exits non-zero with "cluster not found".** The alert rule is attached
to a cluster, and the cluster only exists in AxonOps once its agent has
registered. The service waits for the `cassandra` healthcheck, which normally
covers it; if the node was slow to register, just re-run
`docker compose run --rm config`.

**Tasks are marked `censored`.** The modules hide their output by default,
because the same fields can carry credentials — which also hides API errors.
`enable_logging: true` in `config.yaml` turns it back on. Leave it on until the
configuration applies cleanly.

**The rule applies but never fires.** Check `dashboard` and `chart` against the
UI. A name that does not resolve is accepted silently.

**Nothing appears in the dashboard at all.** Confirm the agent registered into
the organisation you are looking at: `AXON_AGENT_ORG` on the `cassandra` service
and `AXONSERVER_ORGNAME` on `axon-server` both come from `AXONOPS_ORG_NAME`, so
they only diverge if you changed it after first start. Change it before first
start, not after.

**Using AxonOps Cloud instead of this stack.** Remove `AXONOPS_URL` from
`config.yaml` and set `AXONOPS_TOKEN` to an API token from the console. The
alert configuration itself is unchanged.

## Related

- [00-axonops-platform](../00-axonops-platform/) — AxonOps alone, for clusters you already run
- [01-cassandra-cluster](../01-cassandra-cluster/) — the same stack with three monitored nodes
- [03-secure-3-rack-cluster](../03-secure-3-rack-cluster/) — a production-shaped, secured cluster
- [VERSIONS.md](../../VERSIONS.md) — current digest of every image

## Support

Maintained by [AxonOps](https://axonops.com). For support, contact us at
[axonops.com/contact](https://axonops.com/contact).
