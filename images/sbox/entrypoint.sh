#!/usr/bin/env bash
# Copyright (c) 2026 Mydriss

set -euo pipefail

CONTAINER_HOME="${CONTAINER_HOME:-/home/container}"
WINEPREFIX="${WINEPREFIX:-/home/container/.wine}"
BAKED_WINEPREFIX="${SBOX_BAKED_WINEPREFIX:-/opt/sbox-wine-prefix}"
BAKED_SERVER_TEMPLATE="${SBOX_BAKED_SERVER_TEMPLATE:-/opt/sbox-server-template}"

SBOX_INSTALL_DIR="${SBOX_INSTALL_DIR:-/home/container/sbox}"
SBOX_SERVER_EXE="${SBOX_SERVER_EXE:-${SBOX_INSTALL_DIR}/sbox-server.exe}"
SBOX_APP_ID="${SBOX_APP_ID:-1892930}"
SBOX_AUTO_UPDATE="${SBOX_AUTO_UPDATE:-1}"
SBOX_BRANCH="${SBOX_BRANCH:-}"
SBOX_STEAMCMD_TIMEOUT="${SBOX_STEAMCMD_TIMEOUT:-600}"

GAME="${GAME:-mydriss.darkrp}"
MAP="${MAP:-}"
SERVER_NAME="${SERVER_NAME:-}"
HOSTNAME_FALLBACK="${HOSTNAME:-}"
MAX_PLAYERS="${MAX_PLAYERS:-}"
ENABLE_DIRECT_CONNECT="${ENABLE_DIRECT_CONNECT:-0}"
TOKEN="${TOKEN:-}"
SBOX_PROJECT="${SBOX_PROJECT:-}"
SBOX_PROJECTS_DIR="/home/container/projects"
SBOX_EXTRA_ARGS="${SBOX_EXTRA_ARGS:-}"

SERVER_PID=""

LOG_DIR="${CONTAINER_HOME}/logs"
LOG_FILE="${LOG_DIR}/sbox-server.log"
ERROR_LOG="${LOG_DIR}/sbox-error.log"
UPDATE_LOG="${LOG_DIR}/sbox-update.log"

mkdir -p "${LOG_DIR}"

log_info() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] INFO: $*" | tee -a "${LOG_FILE}" >&2
}

log_warn() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] WARN: $*" | tee -a "${LOG_FILE}" >&2
}

log_error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $*" | tee -a "${ERROR_LOG}" >&2
}

seed_runtime_files() {
    local seed_sbox=0
    local seed_reason=""
    local baked_server_exe="${BAKED_SERVER_TEMPLATE}/sbox-server.exe"

    if [ ! -d "${SBOX_INSTALL_DIR}" ]; then
        seed_sbox=1
        seed_reason="missing install directory"
    elif [ -z "$(find "${SBOX_INSTALL_DIR}" -mindepth 1 -print -quit 2>/dev/null)" ]; then
        seed_sbox=1
        seed_reason="empty install directory"
    fi

    mkdir -p "${WINEPREFIX}"

    if [ "${seed_sbox}" = "1" ]; then
        mkdir -p "${SBOX_INSTALL_DIR}"
    fi

    if [ ! -f "${WINEPREFIX}/system.reg" ] && [ -d "${BAKED_WINEPREFIX}/drive_c" ]; then
        log_info "seeding Wine prefix from ${BAKED_WINEPREFIX}"
        cp -r "${BAKED_WINEPREFIX}/." "${WINEPREFIX}/"
    fi

    if [ "${seed_sbox}" = "1" ] && [ -f "${baked_server_exe}" ]; then
        log_info "seeding S&Box files from ${BAKED_SERVER_TEMPLATE} (${seed_reason})"
        cp -r "${BAKED_SERVER_TEMPLATE}/." "${SBOX_INSTALL_DIR}/"
        if [ -f "${SBOX_SERVER_EXE}" ]; then
            log_info "prebaked S&Box seed complete (${SBOX_SERVER_EXE})"
        else
            log_warn "prebaked seed copy completed but ${SBOX_SERVER_EXE} is still missing"
        fi
    elif [ "${seed_sbox}" = "1" ]; then
        log_warn "${SBOX_INSTALL_DIR} requires reseed (${seed_reason}) but prebaked Windows template is missing ${baked_server_exe}"
    fi
}

canonicalize_existing_path() {
    local input_path="$1"
    local input_dir=""
    local input_base=""

    if [ -z "${input_path}" ] || [ ! -e "${input_path}" ]; then
        return 1
    fi

    input_dir="$(dirname "${input_path}")"
    input_base="$(basename "${input_path}")"

    (
        cd "${input_dir}" 2>/dev/null || exit 1
        printf '%s/%s' "$(pwd -P)" "${input_base}"
    )
}

path_is_within_root() {
    local candidate_path="$1"
    local root_path="$2"

    case "${candidate_path}" in
        "${root_path}"|"${root_path}"/*) return 0 ;;
        *) return 1 ;;
    esac
}

resolve_project_target() {
    local projects_root="${SBOX_PROJECTS_DIR}"
    
    if [ ! -d "${projects_root}" ]; then
        log_warn "Projects directory '${projects_root}' not found. Skipping local detection."
        printf '%s' ""
        return 0
    fi

    local project_file="${projects_root}/darkrp_public.sbproj"
    
    if [ -f "${project_file}" ]; then
        log_info "Local project detected directly in projects directory: darkrp_public.sbproj"
        printf '%s' "${projects_root}"
        return 0
    fi

    local first_sbproj
    first_sbproj=$(find "${projects_root}" -maxdepth 2 -name "*.sbproj" -print -quit)
    if [ -n "${first_sbproj}" ]; then
        log_info "Discovered local project: $(basename "${first_sbproj}")"
        printf '%s' "$(dirname "${first_sbproj}")"
        return 0
    fi

    printf '%s' ""
    return 0
}

find_latest_cloud_scene() {
    local cloud_assets_root="/home/container/sbox/download/assets"
    
    if [ ! -d "${cloud_assets_root}" ]; then
        return 1
    fi

    local latest_scene
    latest_scene=$(find "${cloud_assets_root}" -type f -name "darkrp.*.scene" -not -name "*.scene_c" -not -name "*.scene_d" | xargs -r ls -t 2>/dev/null | head -n 1)
    
    if [ -n "${latest_scene}" ]; then
        printf '%s' "${latest_scene}"
        return 0
    fi

    return 1
}

adaptive_scene_merge() {
    local local_scene_path="$1"
    local cloud_scene_path="$2"

    if [ ! -f "${cloud_scene_path}" ]; then
        log_warn "Cloud scene not found at ${cloud_scene_path}, skipping merge."
        return 0
    fi

    local local_dir
    local_dir="$(dirname "${local_scene_path}")"
    if [ ! -d "${local_dir}" ]; then
        log_info "Creating missing local scene directory: ${local_dir}"
        mkdir -p "${local_dir}"
    fi

    if [ ! -f "${local_scene_path}" ]; then
        log_info "Initial boot: Copying cloud scene to ${local_scene_path}"
        cp "${cloud_scene_path}" "${local_scene_path}"
        return 0
    fi

    log_info "Merging Cloud updates with local server additions..."
    cp "${local_scene_path}" "${local_scene_path}.bak"

    jq -s '
        .[0] as $cloud |
        .[1] as $local |
        ($cloud.GameObjects | map({key: .__guid, value: .}) | from_entries) as $cloud_map |
        ($local.GameObjects | map({key: .__guid, value: .}) | from_entries) as $local_map |
        
        # Merge GameObjects:
        # - Objects only in Cloud: Keep Cloud version
        # - Objects in both: Take Cloud version (updates)
        # - Objects only in Local: Keep Local version (preservation)
        $cloud | .GameObjects = (
            [
                $cloud.GameObjects[],
                ($local.GameObjects[] | select($cloud_map[.__guid] == null))
            ]
        )
    ' "${cloud_scene_path}" "${local_scene_path}" > "${local_scene_path}.tmp" && mv "${local_scene_path}.tmp" "${local_scene_path}"

    log_info "Adaptive merge successful. Local additions preserved."
}

ensure_project_libraries_dir() {
    local project_target="$1"
    local project_path=""
    local projects_root=""
    local project_dir=""
    local libraries_dir=""

    if [ -z "${project_target}" ]; then
        return 0
    fi

    if [[ "${project_target}" = /* ]]; then
        project_path="${project_target}"
    else
        project_path="${SBOX_PROJECTS_DIR}/${project_target}"
    fi

    if [ ! -e "${project_path}" ]; then
        return 1
    fi

    projects_root="$(canonicalize_existing_path "${SBOX_PROJECTS_DIR}" || true)"
    project_path="$(canonicalize_existing_path "${project_path}" || true)"

    if [ -z "${projects_root}" ] || [ -z "${project_path}" ]; then
        return 1
    fi

    if ! path_is_within_root "${project_path}" "${projects_root}"; then
        return 1
    fi

    if [ -f "${project_path}" ]; then
        project_dir="$(dirname "${project_path}")"
    else
        project_dir="${project_path}"
    fi

    if ! path_is_within_root "${project_dir}" "${projects_root}"; then
        return 1
    fi

    libraries_dir="${project_dir}/Libraries"
    if [ ! -d "${libraries_dir}" ]; then
        mkdir -p "${libraries_dir}"
        log_info "created required local project folder ${libraries_dir}"
    fi
}

resolve_steamcmd_binary() {
    local candidate=""

    for candidate in \
        "/usr/bin/steamcmd" \
        "/usr/games/steamcmd"
    do
        if [ -f "${candidate}" ]; then
            printf '%s' "${candidate}"
            return 0
        fi
    done

    return 1
}

run_steamcmd() {
    local -a args=("$@")
    local steamcmd_bin=""
    local steamcmd_library_path="/lib:/usr/lib/games/steam"

    mkdir -p "${CONTAINER_HOME}/.steam" "${CONTAINER_HOME}/.local/share" "${CONTAINER_HOME}/Steam"
    ln -sfn "${CONTAINER_HOME}/Steam" "${CONTAINER_HOME}/.steam/root"
    ln -sfn "${CONTAINER_HOME}/Steam" "${CONTAINER_HOME}/.steam/steam"

    steamcmd_bin="$(resolve_steamcmd_binary || true)"

    if [ -z "${steamcmd_bin}" ]; then
        log_warn "SteamCMD binary not found in expected locations"
        return 1
    fi

    HOME="${CONTAINER_HOME}" LD_LIBRARY_PATH="${steamcmd_library_path}" "${steamcmd_bin}" "${args[@]}"
}

run_steamcmd_with_timeout() {
    local timeout_seconds="$1"
    shift
    local -a args=("$@")
    local steamcmd_bin=""
    local steamcmd_library_path="/lib:/usr/lib/games/steam"

    mkdir -p "${CONTAINER_HOME}/.steam" "${CONTAINER_HOME}/.local/share" "${CONTAINER_HOME}/Steam"
    ln -sfn "${CONTAINER_HOME}/Steam" "${CONTAINER_HOME}/.steam/root"
    ln -sfn "${CONTAINER_HOME}/Steam" "${CONTAINER_HOME}/.steam/steam"

    steamcmd_bin="$(resolve_steamcmd_binary || true)"
    if [ -z "${steamcmd_bin}" ]; then
        log_warn "SteamCMD binary not found in expected locations"
        return 1
    fi

    if [[ "${timeout_seconds}" == *.* ]]; then
        timeout_seconds="${timeout_seconds%%.*}"
    fi
    if [ -z "${timeout_seconds}" ]; then
        timeout_seconds=0
    fi

    if [ "${timeout_seconds}" -gt 0 ] && command -v timeout >/dev/null 2>&1; then
        HOME="${CONTAINER_HOME}" LD_LIBRARY_PATH="${steamcmd_library_path}" timeout "${timeout_seconds}" "${steamcmd_bin}" "${args[@]}"
        return $?
    fi

    HOME="${CONTAINER_HOME}" LD_LIBRARY_PATH="${steamcmd_library_path}" "${steamcmd_bin}" "${args[@]}"
}

update_sbox() {
    local -a steam_args
    local -a steam_args_retry
    local -a probe_args
    local force_platform="windows"
    local steamcmd_status=0

    : > "${UPDATE_LOG}"

    probe_args=(
        +@ShutdownOnFailedCommand 1
        +@NoPromptForPassword 1
        +quit
    )

    steam_args=(
        +@ShutdownOnFailedCommand 1
        +@NoPromptForPassword 1
        +@sSteamCmdForcePlatformType "${force_platform}"
        +force_install_dir "${SBOX_INSTALL_DIR}"
        +login anonymous
        +app_update "${SBOX_APP_ID}"
    )

    if [ -n "${SBOX_BRANCH}" ]; then
        steam_args+=( -beta "${SBOX_BRANCH}" )
    fi

    steam_args_retry=("${steam_args[@]}")
    steam_args+=( validate +quit )
    steam_args_retry+=( +quit )

    set +e
    run_steamcmd_with_timeout "${SBOX_STEAMCMD_TIMEOUT}" "${probe_args[@]}" 2>&1 | tee -a "${UPDATE_LOG}"
    steamcmd_status=${PIPESTATUS[0]}
    set -e
    if [ "${steamcmd_status}" -ne 0 ]; then
        log_warn "SteamCMD runtime probe failed; cannot run auto-update"
        if [ "${steamcmd_status}" -eq 124 ]; then
            log_warn "SteamCMD probe timed out after ${SBOX_STEAMCMD_TIMEOUT}s (common hang point: Steam API/user info)"
        fi
        log_warn "see ${UPDATE_LOG} for details"
        if [ ! -f "${SBOX_SERVER_EXE}" ]; then
            log_error "${SBOX_SERVER_EXE} was not found"
            log_error "run the egg installation script, or enable auto-update after SteamCMD has been installed"
            return 1
        fi
        log_warn "continuing startup with existing server files because ${SBOX_SERVER_EXE} already exists"
        return 0
    fi

    log_info "running SteamCMD app_update for app ${SBOX_APP_ID} with forced platform '${force_platform}'"
    set +e
    run_steamcmd_with_timeout "${SBOX_STEAMCMD_TIMEOUT}" "${steam_args[@]}" 2>&1 | tee -a "${UPDATE_LOG}"
    steamcmd_status=${PIPESTATUS[0]}
    set -e
    if [ "${steamcmd_status}" -ne 0 ]; then
        if grep -q "Missing configuration" "${UPDATE_LOG}"; then
            log_warn "SteamCMD reported missing configuration; retrying app_update once without validate"
            set +e
            run_steamcmd_with_timeout "${SBOX_STEAMCMD_TIMEOUT}" "${steam_args_retry[@]}" 2>&1 | tee -a "${UPDATE_LOG}"
            steamcmd_status=${PIPESTATUS[0]}
            set -e
        fi

        if [ "${steamcmd_status}" -eq 0 ]; then
            log_info "SteamCMD retry completed successfully"
            return 0
        fi

        log_warn "SteamCMD update failed with forced platform '${force_platform}'; refusing Linux fallback to preserve Wine-compatible server files"
        if [ "${steamcmd_status}" -eq 124 ]; then
            log_warn "SteamCMD update timed out after ${SBOX_STEAMCMD_TIMEOUT}s"
        fi
        log_warn "see ${UPDATE_LOG} for details"
        if [ -f "${SBOX_SERVER_EXE}" ]; then
            log_warn "continuing startup with existing server files because ${SBOX_SERVER_EXE} already exists"
            return 0
        fi
        return 1
    fi

    if [ ! -f "${SBOX_SERVER_EXE}" ] && [ -d "${SBOX_INSTALL_DIR}/linux64" ]; then
        log_warn "update finished but Windows server executable is still missing while linux64 content exists in ${SBOX_INSTALL_DIR}"
    fi
}

check_dependencies() {
    if ! command -v jq >/dev/null 2>&1; then
        log_error "Dependency 'jq' is missing! Please rebuild your Docker image with the updated Dockerfile."
        exit 1
    fi
}

run_sbox() {
    local -a cli_args=("$@")
    local -a args=()
    local -a filtered_cli_args=()
    local -a extra=()
    local -a launch_env=()
    local -a redacted_args=()
    local project_target=""
    local resolved_server_name="${SERVER_NAME}"
    local cli_has_game=0
    local skip_next=0
    local cli_arg=""

    if [ ! -f "${SBOX_SERVER_EXE}" ]; then
        log_error "${SBOX_SERVER_EXE} was not found. Cannot start S&Box server."
        log_info "try deleting the /sbox folder to trigger a reseed from the prebaked template."
        exit 1
    fi

    project_target="$(resolve_project_target)"

    if ! cli_has_flag "+maxplayers" && [ -n "${MAX_PLAYERS}" ] && [ "${MAX_PLAYERS}" -gt 0 ]; then
        args+=( +maxplayers "${MAX_PLAYERS}" )
    fi

    if ! cli_has_flag "+tickrate" && [ -n "${TICKRATE}" ] && [ "${TICKRATE}" -gt 0 ]; then
        args+=( +tickrate "${TICKRATE}" )
    fi

    local cli_has_game=0
    for arg in "${cli_args[@]}"; do
        if [ "${arg}" = "+game" ]; then
            cli_has_game=1
        fi
        
        if [ "${skip_next}" -eq 1 ]; then
            skip_next=0
            continue
        fi
        if [ "${arg}" = "+game" ]; then
            skip_next=1
            continue
        fi
        filtered_cli_args+=( "${arg}" )
    done

    cli_has_flag() {
        local flag="$1"
        for arg in "${filtered_cli_args[@]}"; do
            if [ "${arg}" = "${flag}" ]; then
                return 0
            fi
        done
        return 1
    }

    local launch_map="${MAP}"
    if [ -z "${launch_map}" ] && ! cli_has_flag "+map"; then
        log_info "No map specified, and no +map in startup command. Defaulting to facepunch.flatgrass"
        launch_map="facepunch.flatgrass"
    fi

    if [ -n "${project_target}" ]; then
        log_info "Local project detected at: ${project_target}"
        check_dependencies
        
        log_info "Creating symlink for identity '${GAME}'..."
        ensure_project_libraries_dir "${project_target}" || log_warn "Failed to ensure Libraries directory"
        
        if [ -d "${SBOX_INSTALL_DIR}/${GAME}" ] && [ ! -L "${SBOX_INSTALL_DIR}/${GAME}" ]; then
            log_warn "Target '${SBOX_INSTALL_DIR}/${GAME}' is a directory, removing it to create symlink..."
            rm -rf "${SBOX_INSTALL_DIR}/${GAME}"
        fi
        
        ln -sfn "${project_target}" "${SBOX_INSTALL_DIR}/${GAME}" || log_error "Failed to create symlink!"
        
        local scene_local_path="${project_target}/Assets/scenes/darkrp.scene"
        local scene_cloud_path
        
        log_info "Searching for newest cloud scene..."
        scene_cloud_path=$(find_latest_cloud_scene || true)

        if [ -n "${scene_cloud_path}" ]; then
            log_info "Found cloud scene: ${scene_cloud_path}. Starting adaptive merge..."
            adaptive_scene_merge "${scene_local_path}" "${scene_cloud_path}"
        else
            log_info "No cloud scene found in downloads. Skipping merge."
        fi

        if [ "${cli_has_game}" -eq 0 ]; then
            if [ -n "${launch_map}" ]; then
                args+=( +game "${GAME}" "${launch_map}" )
            else
                args+=( +game "${GAME}" )
            fi
        fi
    elif [ -n "${GAME}" ]; then
        log_info "No local project found. Falling back to s&box cloud."
        if [ "${cli_has_game}" -eq 0 ]; then
            if [ -n "${launch_map}" ]; then
                args+=( +game "${GAME}" "${launch_map}" )
            else
                args+=( +game "${GAME}" )
            fi
        fi
    else
        log_error "Missing startup target! GAME variable is empty and no local project found."
        exit 1
    fi

    if [ -z "${resolved_server_name}" ] && [ -n "${HOSTNAME_FALLBACK}" ] && [[ ! "${HOSTNAME_FALLBACK}" =~ ^[0-9a-f]{12,64}$ ]]; then
        resolved_server_name="${HOSTNAME_FALLBACK}"
    fi

    if ! cli_has_flag "+hostname" && [ -n "${resolved_server_name}" ]; then
        args+=( +hostname "${resolved_server_name}" )
    fi

    if ! cli_has_flag "+net_game_server_token" && [ -n "${STEAM_TOKEN}" ]; then
        args+=( +net_game_server_token "${STEAM_TOKEN}" )
    fi

    if [ "${ENABLE_DIRECT_CONNECT}" = "1" ]; then
        if ! cli_has_flag "+net_hide_address"; then args+=( +net_hide_address 0 ); fi
        if ! cli_has_flag "+port"; then args+=( +port ${SERVER_PORT:-27015} ); fi
    fi

    if ! cli_has_flag "+server_key" && [ -n "${SERVER_KEY:-}" ]; then
        args+=( +server_key "${SERVER_KEY}" )
    fi
    if ! cli_has_flag "+owner_steamid" && [ -n "${OWNER_STEAMID:-}" ]; then
        args+=( +owner_steamid "${OWNER_STEAMID}" )
    fi
    if ! cli_has_flag "+server_id" && [ -n "${SERVER_ID:-}" ]; then
        args+=( +server_id "${SERVER_ID}" )
    fi
    if ! cli_has_flag "+server_description" && [ -n "${SERVER_DESCRIPTION:-}" ]; then
        args+=( +server_description "${SERVER_DESCRIPTION}" )
    fi

    if [ -n "${SBOX_EXTRA_ARGS}" ]; then
        read -ra extra <<< "${SBOX_EXTRA_ARGS}"
        args+=( "${extra[@]}" )
    fi

    if [ "${#filtered_cli_args[@]}" -gt 0 ]; then
        args+=( "${filtered_cli_args[@]}" )
    fi

    unset DOTNET_ROOT DOTNET_ROOT_X86 DOTNET_ROOT_X64

    launch_env=(
        LD_LIBRARY_PATH=/usr/lib:/lib
        DOTNET_EnableWriteXorExecute=0
        DOTNET_TieredCompilation=0
        DOTNET_ReadyToRun=0
        DOTNET_ZapDisable=1
    )

    for arg in "${args[@]}"; do
        if [[ "${arg}" == "+net_game_server_token" ]]; then
            redacted_args+=( "+net_game_server_token" "[REDACTED]" )
            continue
        fi

        if [ -z "${skip_next_redact:-}" ]; then
            redacted_args+=( "${arg}" )
        else
            unset skip_next_redact
        fi
    done

    if [ "${ENABLE_DIRECT_CONNECT}" = "1" ]; then
        log_info "Starting S&Box server in direct-connect mode (port=${SERVER_PORT:-27015})"
    else
        log_info "Starting S&Box server in Steam relay mode"
    fi
    log_info "Command: wine \"${SBOX_SERVER_EXE}\" ${redacted_args[*]}"

    cd "${SBOX_INSTALL_DIR}"
    env "${launch_env[@]}" wine "${SBOX_SERVER_EXE}" "${args[@]}" &
    SERVER_PID=$!
    
    if ! wait "${SERVER_PID}"; then
        log_error "S&Box server process exited unexpectedly (pid=${SERVER_PID}, exit=$?)"
        return 1
    fi
}

if [ "${1:-}" = "start-sbox" ]; then
    shift
fi

seed_runtime_files

if [ "${1:-}" = "" ] || [[ "${1}" = +* ]]; then
    if [ "${SBOX_AUTO_UPDATE}" = "1" ] || [ ! -f "${SBOX_SERVER_EXE}" ]; then
        log_info "updating S&Box server files on boot..."
        update_sbox
    fi
    
    run_sbox "$@"
fi

exec "$@"
