# Shared helpers for deploy scripts. Source this file; do not execute it.
# shellcheck shell=bash

# Assign KEY=VALUE lines into the environment without executing the file.
# Blank lines and #-comments are ignored. Values may be bare or wrapped in
# matching single or double quotes (so "La Nonna" is one value). An already
# set variable is left alone. Command substitutions in the file are not run.
load_unset_env_file() {
  local file="$1"
  local line key value
  while IFS= read -r line || [[ -n "${line}" ]]; do
    line="${line#"${line%%[![:space:]]*}"}"
    line="${line%"${line##*[![:space:]]}"}"
    [[ -z "${line}" || "${line}" == \#* ]] && continue
    if [[ "${line}" != *=* ]]; then
      echo "Invalid env line in ${file}: ${line}" >&2
      return 1
    fi
    key="${line%%=*}"
    key="${key%"${key##*[![:space:]]}"}"
    value="${line#*=}"
    if [[ ! "${key}" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
      echo "Invalid env name in ${file}: ${key}" >&2
      return 1
    fi
    if [[ "${value}" =~ ^\".*\"$ ]]; then
      value="${value:1:${#value}-2}"
    elif [[ "${value}" =~ ^\'.*\'$ ]]; then
      value="${value:1:${#value}-2}"
    fi
    if [[ -z "${!key+x}" ]]; then
      printf -v "${key}" '%s' "${value}"
      export "${key}"
    fi
  done < "${file}"
}
