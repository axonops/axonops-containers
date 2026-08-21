# Ejemplo 04 — AxonOps autoalojado con las alertas configuradas como código

[English](README.md) | [Français](README.fr.md) | **Español** | [Galego](README.gl.md)

<p align="center">
  <a href="https://axonops.com"><img src="https://digitalis-marketplace-assets.s3.us-east-1.amazonaws.com/axonops-small-logo.png" alt="AxonOps" height="60"></a>
</p>

AxonOps autoalojado monitorizando un nodo de Apache Cassandra, con las reglas de
alerta aplicadas desde un fichero en lugar de pulsadas en el panel. La pila es el
[ejemplo 01](../01-cassandra-cluster/) reducido a un único nodo monitorizado, más
un contenedor extra que ejecuta un playbook de Ansible contra la API de AxonOps y
después termina.

Úselo cuando quiera que sus alertas vivan en git: revisables, repetibles e
idénticas en todos los clústeres que gestione.

## Inicio rápido

```bash
cp env.example .env          # set AXONOPS_ORG_NAME
docker compose up -d
docker compose logs -f config
open http://localhost:3000
```

El contenedor `config` arranca el último, aplica [`config.yaml`](config.yaml) y
termina. Que `docker compose ps` lo muestre como `Exited (0)` es señal de éxito:
es un job de un solo uso, no un servicio. En el panel, las reglas aparecen bajo
**Alerts → Rules** para su clúster.

Alrededor de 6 GB de RAM con los valores por defecto. Cinco contenedores de larga
duración.

## Qué ejecuta

| Servicio | Imagen | Propósito |
|---|---|---|
| `axondb-timeseries` | `ghcr.io/axonops/axondb-timeseries` | Cassandra, almacén de métricas de AxonOps |
| `axondb-search` | `ghcr.io/axonops/axondb-search` | OpenSearch, almacén de registros y eventos |
| `axon-server` | `registry.axonops.com/axonops-public/axonops-docker/axon-server` | Backend de AxonOps, endpoint de los agentes en el 1888 |
| `axon-dash` | `registry.axonops.com/axonops-public/axonops-docker/axon-dash` | Panel en el 3000, que además hace de proxy de la API |
| `cassandra` | `ghcr.io/axonops/cassandra/cassandra` | El nodo monitorizado, Cassandra + agente |
| `config` | `ghcr.io/axonops/axonops-ansible-ee` | De un solo uso. Aplica `config.yaml` y termina |

La imagen `config` es el entorno de ejecución de Ansible de AxonOps. Ya contiene
Ansible y la colección
[`axonops.axonops`](https://galaxy.ansible.com/ui/repo/published/axonops/axonops/),
así que no se instala nada en tiempo de ejecución y el contenedor no necesita más
volúmenes que el propio playbook.

## Editar las alertas

Cambie [`config.yaml`](config.yaml) y vuelva a aplicarlo:

```bash
docker compose run --rm config
```

El playbook es idempotente —ejecutarlo dos veces no cambia nada la segunda vez—,
así que es seguro ejecutarlo en cada despliegue. Para aplicar sólo una parte,
sobrescriba el comando y use las etiquetas del rol:

```bash
docker compose run --rm config \
  ansible-playbook -i localhost, --connection=local -v /config.yaml --tags metrics
```

Etiquetas: `metrics`, `log_alerts`, `service_checks`, `routes`, `slack`, `teams`,
`pagerduty`, `backups`, `adaptive_repair`, `dashboards`.

## Reglas de alerta de métricas

Una alerta de métrica vigila un gráfico de un panel —los mismos nombres que se
ven en la interfaz de AxonOps— y se dispara cuando el valor cruza un umbral
durante más tiempo que `duration`:

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

| Campo | Obligatorio | Notas |
|---|---|---|
| `name` | sí | Se muestra en la interfaz y sirve para casar la regla al reaplicarla |
| `dashboard` | sí | Nombre del panel, exactamente como lo escribe la interfaz |
| `chart` | sí | Nombre del gráfico en ese panel, exactamente como lo escribe la interfaz |
| `operator` | sí | `>=`, `<=`, `>`, `<`, `==`, `!=`. Entrecomíllelo, o YAML lo lee como una etiqueta |
| `warning_value` | sí | Umbral de aviso |
| `critical_value` | sí | Umbral de alerta crítica |
| `duration` | sí | Cuánto debe mantenerse la condición: `5m`, `15m`, `1h` |
| `description` | no | Diga lo que significa para el operador, no lo que es la métrica |
| `present` | no | `false` borra la regla. Por defecto `true` |
| `scope`, `dc`, `rack`, `host_id`, `keyspace` | no | Acotan la regla a una parte del clúster |
| `group_by`, `percentile`, `consistency` | no | Casan con cómo agrega el gráfico |
| `routing` | no | Envía esta regla a otro sitio distinto de la ruta por defecto |

`dashboard` y `chart` deben coincidir con la interfaz carácter a carácter. Una
errata no es un error: la regla se crea y sencillamente nunca se evalúa.

## Más allá de las alertas de métricas

`config.yaml` trae el resto comentado. Descomente lo que necesite:

- **`axonops_log_alert_rule`**: alerta sobre el volumen de líneas de registro
  coincidentes que envía el agente (`content`, `level`, `type`, `source`).
- **`axonops_tcp_check`** / **`axonops_shell_check`**: comprobaciones de servicio
  que se ejecutan en el nodo monitorizado a través de su agente y alertan cuando
  fallan.
- **`axonops_slack_integrations`**: un destino de notificación. El webhook es un
  secreto: póngalo en `.env` como `SLACK_WEBHOOK_URL`, que el servicio `config`
  pasa al playbook. Nunca lo escriba en línea.
- **`axonops_alert_routes`**: envía una severidad a una integración.

El mismo rol gestiona además copias de seguridad, reparación adaptativa,
archivado del commitlog, paneles e integraciones con PagerDuty y Teams. Consulte
la [documentación de la colección](https://github.com/axonops/axonops-ansible-collection).

## Configuración

Todo se define en `.env`; no hace falta editar ningún fichero de este directorio
para ejecutarlo. Véase [`env.example`](env.example) para la lista completa con
los valores por defecto.

| Variable | Valor por defecto | Notas |
|---|---|---|
| `AXONOPS_ORG_NAME` | `example` | Organización. El agente, axon-server y el contenedor de configuración deben coincidir |
| `CASSANDRA_CLUSTER_NAME` | `demo-cluster` | Clúster al que se asocian las reglas de alerta |
| `CASSANDRA_IMAGE` | `ghcr.io/axonops/cassandra/cassandra:5.0.8-2.0.31-1.1.0` | Imagen del nodo monitorizado |
| `CASSANDRA_HEAP_SIZE` | `1G` | Valor de desarrollo |
| `AXONOPS_DB_PASSWORD` | `axonops` | Cámbiela. El valor por defecto es público |
| `AXONOPS_SEARCH_PASSWORD` | `MyS3cur3P@ss2025` | Cámbiela. La imagen aplica una política de contraseñas |
| `AXONOPS_LICENSE_KEY` | vacío | Opcional; sin ella, modo de prueba |
| `SLACK_WEBHOOK_URL` | vacío | Sólo hace falta para el bloque de Slack de `config.yaml` |

## Resolución de problemas

**`config` termina con código distinto de cero y «cluster not found».** La regla
de alerta se asocia a un clúster, y el clúster sólo existe en AxonOps una vez su
agente se ha registrado. El servicio espera al healthcheck de `cassandra`, lo que
normalmente basta; si el nodo tardó en registrarse, vuelva a ejecutar
`docker compose run --rm config`.

**Las tareas aparecen como `censored`.** Los módulos ocultan su salida por
defecto, porque esos mismos campos pueden llevar credenciales, lo que también
oculta los errores de la API. `enable_logging: true` en `config.yaml` la vuelve a
activar. Déjelo activado hasta que la configuración se aplique limpiamente.

**La regla se aplica pero nunca se dispara.** Compruebe `dashboard` y `chart`
contra la interfaz. Un nombre que no resuelve se acepta en silencio.

**No aparece nada en el panel.** Confirme que el agente se registró en la
organización que está mirando: `AXON_AGENT_ORG` en el servicio `cassandra` y
`AXONSERVER_ORGNAME` en `axon-server` salen ambos de `AXONOPS_ORG_NAME`, así que
sólo divergen si lo cambió después del primer arranque. Cámbielo antes del primer
arranque, no después.

**Usar AxonOps Cloud en lugar de esta pila.** Quite `AXONOPS_URL` de
`config.yaml` y ponga en `AXONOPS_TOKEN` un token de API de la consola. La
configuración de alertas en sí no cambia.

## Relacionado

- [00-axonops-platform](../00-axonops-platform/): AxonOps a solas, para clústeres que ya gestiona
- [01-cassandra-cluster](../01-cassandra-cluster/): la misma pila con tres nodos monitorizados
- [03-secure-3-rack-cluster](../03-secure-3-rack-cluster/): un clúster asegurado con forma de producción
- [VERSIONS.md](../../VERSIONS.md): el digest actual de cada imagen

## Soporte

Mantenido por [AxonOps](https://axonops.com). Para soporte, contacte con nosotros en
[axonops.com/contact](https://axonops.com/contact).
