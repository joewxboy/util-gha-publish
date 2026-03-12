#!/bin/bash
set -euo pipefail

log_info() {
  echo "::notice::$1"
}

log_warn() {
  echo "::warning::$1"
}

log_error() {
  echo "::error::$1"
}

validate_json() {
  local file="${1}"
  if ! jq empty "${file}" 2>/dev/null; then
    log_error "Invalid JSON: ${file}"
    return 1
  fi
}

validate_required_fields() {
  local file="${1}"
  local missing=""

  for field in org url version arch deployment; do
    if ! jq -e ".${field}" "${file}" >/dev/null 2>&1; then
      missing="${missing} ${field}"
    fi
  done

  if [[ -n "${missing}" ]]; then
    log_error "Definition file is missing required fields:${missing}"
    return 1
  fi
}

: "${INPUT_DEFINITION_FILE:?'definition_file input is required'}"
: "${INPUT_CONFIG_FILE:?'config_file input is required'}"
: "${INPUT_HZN_ORG_ID:?'hzn_org_id input is required'}"
: "${INPUT_HZN_EXCHANGE_USER_AUTH:?'hzn_exchange_user_auth input is required'}"

# Security: mask auth token to prevent accidental log exposure
echo "::add-mask::${INPUT_HZN_EXCHANGE_USER_AUTH}"

export HZN_ORG_ID="${INPUT_HZN_ORG_ID}"
export HZN_EXCHANGE_USER_AUTH="${INPUT_HZN_EXCHANGE_USER_AUTH}"

DEFINITION_FILE="${GITHUB_WORKSPACE:-.}/${INPUT_DEFINITION_FILE}"
CONFIG_FILE="${GITHUB_WORKSPACE:-.}/${INPUT_CONFIG_FILE}"

if [[ ! -f "${DEFINITION_FILE}" ]]; then
  log_error "Definition file not found: ${INPUT_DEFINITION_FILE}"
  exit 1
fi

if [[ ! -f "${CONFIG_FILE}" ]]; then
  log_error "Config file not found: ${INPUT_CONFIG_FILE}"
  exit 1
fi

log_info "Loading configuration from ${INPUT_CONFIG_FILE}"

# shellcheck source=/dev/null
source "${CONFIG_FILE}"

: "${HZN_EXCHANGE_URL:?'HZN_EXCHANGE_URL not set in config file'}"
export HZN_EXCHANGE_URL
export HZN_FSS_CSSURL="${HZN_FSS_CSSURL:-}"
export HZN_AGBOT_URL="${HZN_AGBOT_URL:-}"

log_info "Validating ${INPUT_DEFINITION_FILE}"

validate_json "${DEFINITION_FILE}"
validate_required_fields "${DEFINITION_FILE}"

log_info "Definition file is valid"

log_info "Publishing service definition to ${HZN_EXCHANGE_URL}"

hzn exchange service publish -f "${DEFINITION_FILE}"

SERVICE_URL="$(jq -r '.url' "${DEFINITION_FILE}")"
SERVICE_VERSION="$(jq -r '.version' "${DEFINITION_FILE}")"

echo "service_url=${SERVICE_URL}" >> "${GITHUB_OUTPUT:-/dev/null}"
echo "service_version=${SERVICE_VERSION}" >> "${GITHUB_OUTPUT:-/dev/null}"

{
  echo "## Open Horizon Service Published"
  echo ""
  echo "| Field | Value |"
  echo "|-------|-------|"
  echo "| **Organization** | \`${HZN_ORG_ID}\` |"
  echo "| **Service URL** | \`${SERVICE_URL}\` |"
  echo "| **Version** | \`${SERVICE_VERSION}\` |"
  echo "| **Exchange** | \`${HZN_EXCHANGE_URL}\` |"
} >> "${GITHUB_STEP_SUMMARY:-/dev/null}"

log_info "Successfully published ${HZN_ORG_ID}/${SERVICE_URL}:${SERVICE_VERSION}"
