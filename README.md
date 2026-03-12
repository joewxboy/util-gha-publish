# Publish to Open Horizon

A Docker-based GitHub Action that validates and publishes service definition files to an Open Horizon management hub. The action reads configuration from an `agent-install.cfg` file, validates the provided service definition JSON for correct structure and syntax, then publishes it to the exchange using the `hzn` CLI with credentials supplied via GitHub Secrets.

## Usage

```yaml
- name: Publish to Open Horizon
  uses: <owner>/gha-publish@v1
  with:
    definition_file: service.definition.json
    config_file: agent-install.cfg
    hzn_org_id: ${{ vars.HZN_ORG_ID }}
    hzn_exchange_user_auth: ${{ secrets.HZN_EXCHANGE_USER_AUTH }}
```

## Inputs

| Name | Required | Description |
|------|----------|-------------|
| `definition_file` | Yes | Path to the service definition JSON file |
| `config_file` | Yes | Path to the Open Horizon agent config file (`agent-install.cfg`) |
| `hzn_org_id` | Yes | Open Horizon organization ID |
| `hzn_exchange_user_auth` | Yes | Exchange auth string (e.g., `iamapikey:<key>`) |

## Outputs

| Name | Description |
|------|-------------|
| `service_url` | The URL identifier of the published service |
| `service_version` | The version of the published service |

## Prerequisites

- An accessible Open Horizon management hub with a valid exchange endpoint.
- An `agent-install.cfg` file committed to your repository (or accessible at runtime) containing at minimum:
  - `HZN_EXCHANGE_URL` — the exchange API endpoint
  - `HZN_FSS_CSSURL` — the Cloud Sync Service URL
  - `HZN_AGBOT_URL` — the AgBot API endpoint
- A valid service definition JSON file containing the required fields: `org`, `url`, `version`, `arch`, and `deployment`.
- Exchange credentials stored as a GitHub Secret and passed via `hzn_exchange_user_auth`. Do not store credentials in `agent-install.cfg`.

## License

[Apache 2.0](LICENSE)
