# NUT Exporter on Pasiv Black Box

Pasiv Black Box supplies an inactive Quadlet template for the DRuggeri NUT Exporter. The exporter reads a local Network UPS Tools (NUT) server and exposes selected UPS metrics to Prometheus.

The supplied template uses:

```text
ghcr.io/druggeri/nut_exporter:3.3.0
```

## Prerequisite

A working local NUT server is required before deploying this module. The validated design connects to NUT on:

```text
127.0.0.1:3493
```

NUT hardware, driver, user, listener, and UPS naming configuration remain site specific and are not included in this reusable module.

## Files

Template:

```text
/usr/share/pasiv-black-box/quadlets/nut-exporter/nut-exporter.container
```

Example Prometheus scrape jobs:

```text
/usr/share/pasiv-black-box/quadlets/nut-exporter/examples/prometheus-job.yml
```

## Listen address placeholder

The public template intentionally contains:

```text
@@NUT_EXPORTER_LISTEN_ADDRESS@@
```

Replace it with the private host-side gateway address of the `pasiv-monitoring` Podman network before starting the service. Binding the exporter only to that private bridge address lets Prometheus containers reach TCP 9199 without exposing the exporter on the LAN or other host interfaces.

Inspect the monitoring network locally:

```bash
sudo podman network inspect pasiv-monitoring
```

Do not commit deployment-specific addresses to the reusable public library.

The Prometheus example also contains:

```text
@@NUT_UPS_NAME@@
```

Replace that placeholder with the NUT UPS name returned by `upsc -l` on the local deployment.

## Deployment

Copy the Quadlet into the system Quadlet directory, replace the listen-address placeholder, reload systemd, and start the service:

```bash
sudo cp \
  /usr/share/pasiv-black-box/quadlets/nut-exporter/nut-exporter.container \
  /etc/containers/systemd/nut-exporter.container
sudo sed -i \
  's/@@NUT_EXPORTER_LISTEN_ADDRESS@@/REPLACE_WITH_PRIVATE_BRIDGE_GATEWAY/' \
  /etc/containers/systemd/nut-exporter.container
sudo systemctl daemon-reload
sudo systemctl start nut-exporter.service
```

The unit depends on `pasiv-monitoring-network.service` so the private bridge exists before the exporter binds its socket. It also waits for `network-online.target`.

## Exported metrics

The validated metric set is intentionally focused on common UPS telemetry:

- `battery.charge`
- `battery.runtime`
- `battery.voltage`
- `input.voltage`
- `output.voltage`
- `ups.load`
- `ups.status`

These are exposed with the `network_ups_tools_` Prometheus namespace, for example:

```text
network_ups_tools_battery_charge
network_ups_tools_battery_runtime
network_ups_tools_battery_voltage
network_ups_tools_input_voltage
network_ups_tools_output_voltage
network_ups_tools_ups_load
network_ups_tools_ups_status
```

The status metric uses labels such as `OL`, `OB`, `LB`, `RB`, `BYPASS`, `BOOST`, and others supported by the exporter. Availability still depends on the NUT driver and UPS hardware.

## Device metadata is disabled

The template includes:

```text
--nut.disable_device_info
```

This is deliberate. Upstream `device_info` can expose hardware-identifying metadata such as a UPS serial number. Pasiv Black Box does not require that metadata for battery, load, voltage, runtime, or status monitoring, so the reusable template disables it by default.

## Endpoints

The exporter listens on TCP 9199.

Exporter process metrics:

```text
/metrics
```

UPS metrics:

```text
/ups_metrics?ups=<UPS_NAME>
```

## Prometheus integration

Copy the supplied example into the local Prometheus `scrape_configs` section and replace both placeholders:

```yaml
- job_name: nut-exporter
  static_configs:
    - targets:
        - "@@NUT_EXPORTER_LISTEN_ADDRESS@@:9199"

- job_name: nut-ups
  metrics_path: /ups_metrics
  params:
    ups:
      - "@@NUT_UPS_NAME@@"
  static_configs:
    - targets:
        - "@@NUT_EXPORTER_LISTEN_ADDRESS@@:9199"
      labels:
        ups: "@@NUT_UPS_NAME@@"
```

The `nut-exporter` job monitors the exporter process itself. The `nut-ups` job reads the UPS telemetry endpoint and adds an explicit `ups` label for cleaner dashboards and alert rules.

Validate the complete Prometheus configuration with `promtool` before reloading or restarting Prometheus.

## Upstream version display note

The official `3.3.0` container image has OCI metadata identifying version `3.3.0`, but the exporter process can log or print:

```text
version=testing
```

This comes from the upstream container build path, which does not inject the GoReleaser version linker value used by the release binaries. It does not indicate that the `3.3.0` container tag resolved to an untagged development image.

## Validation

This design was validated on physical Pasiv Black Box hardware with NUT Exporter 3.3.0. Validation covered:

- exact upstream container image pull and OCI version metadata;
- local NUT connectivity over `127.0.0.1:3493`;
- battery charge, runtime, battery voltage, input voltage, output voltage, load, and UPS status metrics;
- `device_info` disabled so hardware serial metadata is not exported;
- private-only binding on the monitoring bridge gateway;
- reachability from the Prometheus network namespace;
- separate Prometheus jobs for exporter self-metrics and UPS telemetry;
- Prometheus target health for both jobs;
- direct Prometheus queries for battery charge and online status;
- successful Prometheus `remote_write` delivery to VictoriaMetrics;
- automatic NUT, NUT Exporter, Prometheus, and metrics-path recovery after a full host reboot;
- successful post-reboot queries from both Prometheus and VictoriaMetrics;
- zero failed systemd units after reboot.

The public template remains inactive and deliberately unresolved until the administrator supplies the local monitoring bridge address and NUT UPS name.
