#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
FIXTURES_DIR="${SCRIPT_DIR}/fixtures"

PASS=0
FAIL=0

assert_success() {
  local desc="${1}"
  shift
  if "$@" >/dev/null 2>&1; then
    echo "  PASS: ${desc}"
    PASS=$(( PASS + 1 ))
  else
    echo "  FAIL: ${desc}"
    FAIL=$(( FAIL + 1 ))
  fi
}

assert_failure() {
  local desc="${1}"
  shift
  if "$@" >/dev/null 2>&1; then
    echo "  FAIL: ${desc} (expected failure, got success)"
    FAIL=$(( FAIL + 1 ))
  else
    echo "  PASS: ${desc}"
    PASS=$(( PASS + 1 ))
  fi
}

source_functions() {
  validate_json() {
    local file="${1}"
    if ! jq empty "${file}" 2>/dev/null; then
      echo "::error::Invalid JSON: ${file}"
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
      echo "::error::Definition file is missing required fields:${missing}"
      return 1
    fi
  }
}

test_validate_json() {
  echo "--- validate_json ---"
  source_functions

  assert_success "accepts valid JSON" \
    validate_json "${FIXTURES_DIR}/valid_service.definition.json"

  assert_failure "rejects invalid JSON" \
    validate_json "${FIXTURES_DIR}/malformed.json"
}

test_validate_required_fields() {
  echo "--- validate_required_fields ---"
  source_functions

  assert_success "accepts definition with all required fields" \
    validate_required_fields "${FIXTURES_DIR}/valid_service.definition.json"

  assert_failure "rejects definition missing required fields" \
    validate_required_fields "${FIXTURES_DIR}/invalid_service.definition.json"
}

test_input_validation() {
  echo "--- input validation ---"

  assert_failure "fails when INPUT_DEFINITION_FILE is unset" \
    bash -c '
      unset INPUT_DEFINITION_FILE
      export INPUT_CONFIG_FILE=x INPUT_HZN_ORG_ID=x INPUT_HZN_EXCHANGE_USER_AUTH=x
      source "'"${PROJECT_DIR}/entrypoint.sh"'"
    '

  assert_failure "fails when INPUT_CONFIG_FILE is unset" \
    bash -c '
      export INPUT_DEFINITION_FILE=x INPUT_HZN_ORG_ID=x INPUT_HZN_EXCHANGE_USER_AUTH=x
      unset INPUT_CONFIG_FILE
      source "'"${PROJECT_DIR}/entrypoint.sh"'"
    '

  assert_failure "fails when INPUT_HZN_ORG_ID is unset" \
    bash -c '
      export INPUT_DEFINITION_FILE=x INPUT_CONFIG_FILE=x INPUT_HZN_EXCHANGE_USER_AUTH=x
      unset INPUT_HZN_ORG_ID
      source "'"${PROJECT_DIR}/entrypoint.sh"'"
    '

  assert_failure "fails when INPUT_HZN_EXCHANGE_USER_AUTH is unset" \
    bash -c '
      export INPUT_DEFINITION_FILE=x INPUT_CONFIG_FILE=x INPUT_HZN_ORG_ID=x
      unset INPUT_HZN_EXCHANGE_USER_AUTH
      source "'"${PROJECT_DIR}/entrypoint.sh"'"
    '
}

test_file_not_found() {
  echo "--- file not found ---"

  assert_failure "fails when definition file does not exist" \
    bash -c '
      export INPUT_DEFINITION_FILE=nonexistent.json
      export INPUT_CONFIG_FILE=agent-install.cfg
      export INPUT_HZN_ORG_ID=testorg
      export INPUT_HZN_EXCHANGE_USER_AUTH=user:pass
      export GITHUB_WORKSPACE="'"${FIXTURES_DIR}"'"
      bash "'"${PROJECT_DIR}/entrypoint.sh"'"
    '

  assert_failure "fails when config file does not exist" \
    bash -c '
      export INPUT_DEFINITION_FILE=valid_service.definition.json
      export INPUT_CONFIG_FILE=nonexistent.cfg
      export INPUT_HZN_ORG_ID=testorg
      export INPUT_HZN_EXCHANGE_USER_AUTH=user:pass
      export GITHUB_WORKSPACE="'"${FIXTURES_DIR}"'"
      bash "'"${PROJECT_DIR}/entrypoint.sh"'"
    '
}

test_successful_publish() {
  echo "--- successful publish (mocked hzn) ---"

  local mock_dir
  mock_dir="$(mktemp -d)"
  cat > "${mock_dir}/hzn" <<'MOCK'
#!/bin/bash
exit 0
MOCK
  chmod +x "${mock_dir}/hzn"

  assert_success "publishes with valid inputs and mocked hzn" \
    bash -c '
      export PATH="'"${mock_dir}"':${PATH}"
      export INPUT_DEFINITION_FILE=valid_service.definition.json
      export INPUT_CONFIG_FILE=agent-install.cfg
      export INPUT_HZN_ORG_ID=testorg
      export INPUT_HZN_EXCHANGE_USER_AUTH=user:pass
      export GITHUB_WORKSPACE="'"${FIXTURES_DIR}"'"
      export GITHUB_OUTPUT=/dev/null
      export GITHUB_STEP_SUMMARY=/dev/null
      bash "'"${PROJECT_DIR}/entrypoint.sh"'"
    '

  rm -rf "${mock_dir}"
}

setup_malformed_fixture() {
  echo '{this is not valid json' > "${FIXTURES_DIR}/malformed.json"
}

cleanup_malformed_fixture() {
  rm -f "${FIXTURES_DIR}/malformed.json"
}

main() {
  echo "Running entrypoint tests..."
  echo ""

  setup_malformed_fixture

  test_validate_json
  test_validate_required_fields
  test_input_validation
  test_file_not_found
  test_successful_publish

  cleanup_malformed_fixture

  echo ""
  echo "Results: ${PASS} passed, ${FAIL} failed"

  if [[ "${FAIL}" -gt 0 ]]; then
    exit 1
  fi
}

main
