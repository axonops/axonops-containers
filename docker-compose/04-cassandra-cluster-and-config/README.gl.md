# Exemplo 04 — AxonOps autoaloxado coas alertas configuradas como código

[English](README.md) | [Français](README.fr.md) | [Español](README.es.md) | **Galego**

<p align="center">
  <a href="https://axonops.com"><img src="https://digitalis-marketplace-assets.s3.us-east-1.amazonaws.com/axonops-small-logo.png" alt="AxonOps" height="60"></a>
</p>

AxonOps autoaloxado monitorizando un nodo de Apache Cassandra, coas regras de
alerta aplicadas dende un ficheiro no canto de premidas no panel. A pila é o
[exemplo 01](../01-cassandra-cluster/) reducido a un único nodo monitorizado,
máis un contedor extra que executa un playbook de Ansible contra a API de AxonOps
e despois remata.

Úseo cando queira que as súas alertas vivan en git: revisables, repetibles e
idénticas en todos os clústeres que xestione.

## Inicio rápido

```bash
cp env.example .env          # set AXONOPS_ORG_NAME
docker compose up -d
docker compose logs -f config
open http://localhost:3000
```

O contedor `config` arranca o último, aplica [`config.yaml`](config.yaml) e
remata. Que `docker compose ps` o amose como `Exited (0)` é sinal de éxito: é un
job dun só uso, non un servizo. No panel, as regras aparecen baixo
**Alerts → Rules** para o seu clúster.

Arredor de 6 GB de RAM cos valores por defecto. Cinco contedores de longa
duración.

## Que executa

| Servizo | Imaxe | Propósito |
|---|---|---|
| `axondb-timeseries` | `ghcr.io/axonops/axondb-timeseries` | Cassandra, almacén de métricas de AxonOps |
| `axondb-search` | `ghcr.io/axonops/axondb-search` | OpenSearch, almacén de rexistros e eventos |
| `axon-server` | `registry.axonops.com/axonops-public/axonops-docker/axon-server` | Backend de AxonOps, endpoint dos axentes no 1888 |
| `axon-dash` | `registry.axonops.com/axonops-public/axonops-docker/axon-dash` | Panel no 3000, que ademais fai de proxy da API |
| `cassandra` | `ghcr.io/axonops/cassandra/cassandra` | O nodo monitorizado, Cassandra + axente |
| `config` | `ghcr.io/axonops/axonops-ansible-ee` | Dun só uso. Aplica `config.yaml` e remata |

A imaxe `config` é o entorno de execución de Ansible de AxonOps. Xa contén
Ansible e a colección
[`axonops.axonops`](https://galaxy.ansible.com/ui/repo/published/axonops/axonops/),
así que non se instala nada en tempo de execución e o contedor non precisa máis
volumes ca o propio playbook.

## Editar as alertas

Cambie [`config.yaml`](config.yaml) e volva aplicalo:

```bash
docker compose run --rm config
```

O playbook é idempotente —executalo dúas veces non cambia nada a segunda vez—,
así que é seguro executalo en cada despregamento. Para aplicar só unha parte,
sobrescriba o comando e use as etiquetas do rol:

```bash
docker compose run --rm config \
  ansible-playbook -i localhost, --connection=local -v /config.yaml --tags metrics
```

Etiquetas: `metrics`, `log_alerts`, `service_checks`, `routes`, `slack`, `teams`,
`pagerduty`, `backups`, `adaptive_repair`, `dashboards`.

## Regras de alerta de métricas

Unha alerta de métrica vixía unha gráfica dun panel —os mesmos nomes que se ven
na interface de AxonOps— e dispárase cando o valor cruza un limiar durante máis
tempo ca `duration`:

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

| Campo | Obrigatorio | Notas |
|---|---|---|
| `name` | si | Amósase na interface e serve para casar a regra ao reaplicala |
| `dashboard` | si | Nome do panel, exactamente como o escribe a interface |
| `chart` | si | Nome da gráfica nese panel, exactamente como o escribe a interface |
| `operator` | si | `>=`, `<=`, `>`, `<`, `==`, `!=`. Entrecomíleo, ou YAML leo como unha etiqueta |
| `warning_value` | si | Limiar de aviso |
| `critical_value` | si | Limiar de alerta crítica |
| `duration` | si | Canto debe manterse a condición: `5m`, `15m`, `1h` |
| `description` | non | Diga o que significa para o operador, non o que é a métrica |
| `present` | non | `false` borra a regra. Por defecto `true` |
| `scope`, `dc`, `rack`, `host_id`, `keyspace` | non | Acoutan a regra a unha parte do clúster |
| `group_by`, `percentile`, `consistency` | non | Casan con como agrega a gráfica |
| `routing` | non | Envía esta regra a outro sitio distinto da ruta por defecto |

`dashboard` e `chart` deben coincidir coa interface carácter a carácter. Unha
errata non é un erro: a regra créase e sinxelamente nunca se avalía.

## Máis alá das alertas de métricas

`config.yaml` trae o resto comentado. Descomente o que precise:

- **`axonops_log_alert_rule`**: alerta sobre o volume de liñas de rexistro
  coincidentes que envía o axente (`content`, `level`, `type`, `source`).
- **`axonops_tcp_check`** / **`axonops_shell_check`**: comprobacións de servizo
  que se executan no nodo monitorizado a través do seu axente e alertan cando
  fallan.
- **`axonops_slack_integrations`**: un destino de notificación. O webhook é un
  segredo: póñao no `.env` como `SLACK_WEBHOOK_URL`, que o servizo `config` lle
  pasa ao playbook. Nunca o escriba en liña.
- **`axonops_alert_routes`**: envía unha severidade a unha integración.

O mesmo rol xestiona ademais copias de seguranza, reparación adaptativa,
arquivado do commitlog, paneis e integracións con PagerDuty e Teams. Consulte a
[documentación da colección](https://github.com/axonops/axonops-ansible-collection).

## Configuración

Todo se define no `.env`; non fai falta editar ningún ficheiro deste directorio
para executalo. Véxase [`env.example`](env.example) para a lista completa cos
valores por defecto.

| Variable | Valor por defecto | Notas |
|---|---|---|
| `AXONOPS_ORG_NAME` | `example` | Organización. O axente, axon-server e o contedor de configuración deben coincidir |
| `CASSANDRA_CLUSTER_NAME` | `demo-cluster` | Clúster ao que se asocian as regras de alerta |
| `CASSANDRA_IMAGE` | `ghcr.io/axonops/cassandra/cassandra:5.0.8-2.0.31-1.1.0` | Imaxe do nodo monitorizado |
| `CASSANDRA_HEAP_SIZE` | `1G` | Valor de desenvolvemento |
| `AXONOPS_DB_PASSWORD` | `axonops` | Cámbiea. O valor por defecto é público |
| `AXONOPS_SEARCH_PASSWORD` | `MyS3cur3P@ss2025` | Cámbiea. A imaxe aplica unha política de contrasinais |
| `AXONOPS_LICENSE_KEY` | baleiro | Opcional; sen ela, modo de proba |
| `SLACK_WEBHOOK_URL` | baleiro | Só fai falta para o bloque de Slack de `config.yaml` |

## Resolución de problemas

**`config` remata con código distinto de cero e «cluster not found».** A regra de
alerta asóciase a un clúster, e o clúster só existe en AxonOps unha vez o seu
axente se rexistrou. O servizo agarda polo healthcheck de `cassandra`, o que
normalmente abonda; se o nodo tardou en rexistrarse, volva executar
`docker compose run --rm config`.

**As tarefas aparecen como `censored`.** Os módulos ocultan a súa saída por
defecto, porque eses mesmos campos poden levar credenciais, o que tamén oculta os
erros da API. `enable_logging: true` no `config.yaml` volve activala. Déixeo
activado ata que a configuración se aplique limpamente.

**A regra aplícase pero nunca se dispara.** Comprobe `dashboard` e `chart` contra
a interface. Un nome que non resolve acéptase en silencio.

**Non aparece nada no panel.** Confirme que o axente se rexistrou na organización
que está a mirar: `AXON_AGENT_ORG` no servizo `cassandra` e `AXONSERVER_ORGNAME`
en `axon-server` saen ambos de `AXONOPS_ORG_NAME`, así que só diverxen se o
cambiou despois do primeiro arranque. Cámbieo antes do primeiro arranque, non
despois.

**Usar AxonOps Cloud no canto desta pila.** Quite `AXONOPS_URL` do `config.yaml`
e poña en `AXONOPS_TOKEN` un token de API da consola. A configuración de alertas
en si non cambia.

## Relacionado

- [00-axonops-platform](../00-axonops-platform/): AxonOps a soas, para clústeres que xa xestiona
- [01-cassandra-cluster](../01-cassandra-cluster/): a mesma pila con tres nodos monitorizados
- [03-secure-3-rack-cluster](../03-secure-3-rack-cluster/): un clúster asegurado con forma de produción
- [VERSIONS.md](../../VERSIONS.md): o digest actual de cada imaxe

## Soporte

Mantido por [AxonOps](https://axonops.com). Para soporte, contacte connosco en
[axonops.com/contact](https://axonops.com/contact).
