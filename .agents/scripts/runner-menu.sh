#!/usr/bin/env bash
# ==============================================================================
# CrowKit — Selector y Configurador Interactivo de Workflows y Jobs 🦅
# Permite elegir eventos (PR, Push, etc.), configurar jobs (Docker/Local/Off)
# y ejecutar la validación localmente sin subir nada a GitHub Actions.
# ==============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Colores ANSI
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
MAGENTA='\033[0;35m'
BLUE='\033[0;34m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'
CLEAR_SCREEN='\033[2J\033[H'
HIDE_CURSOR='\033[?25l'
SHOW_CURSOR='\033[?25h'

cd "$REPO_ROOT"

# Guardar estado de la terminal para restauración segura
ORIGINAL_TTY_STATE=$(stty -g 2>/dev/null || true)
cleanup() {
    printf "${SHOW_CURSOR}"
    if [ -n "$ORIGINAL_TTY_STATE" ]; then
        stty "$ORIGINAL_TTY_STATE" 2>/dev/null || true
    fi
}
trap cleanup EXIT INT TERM

# Definición de Eventos
EVENTS=(
    "pull_request:Simula un Pull Request hacia development (Build, CTest, Sonar, Docs)"
    "push:Simula un commit/push a rama feature o desarrollo (Build rápido y pruebas)"
    "workflow_dispatch:Simula ejecución manual con parámetros configurables"
    "release:Simula pipeline de entrega continua CD (CPack y Docker packaging)"
    "custom:Modo libre: selecciona cualquier job de cualquier workflow"
)

# Catálogo Maestro de Jobs:
# Formato: id|nombre|workflow_file|eventos_compatibles|soporta_local|modo_inicial
JOB_REGISTRY=(
    "build|Build & Compilación C++20 (Universal)|.github/workflows/ci.yml|pull_request,push,workflow_dispatch,custom|true|docker"
    "test|Pruebas Unitarias GoogleTest / CTest (747 tests)|.github/workflows/ci.yml|pull_request,push,workflow_dispatch,custom|true|docker"
    "test-sanitizers|Análisis de Memoria (ASan & UBSan)|.github/workflows/ci.yml|pull_request,push,workflow_dispatch,custom|true|off"
    "test-windows|Compilación Windows MSVC (x64)|.github/workflows/ci.yml|pull_request,push,workflow_dispatch,custom|false|off"
    "cppcheck|Análisis Estático C++ (Cppcheck)|.github/workflows/ci.yml|pull_request,push,workflow_dispatch,custom|true|off"
    "clang-tidy|Análisis Estático (Clang-Tidy)|.github/workflows/ci.yml|pull_request,push,workflow_dispatch,custom|false|off"
    "sonar|SonarQube SAST & Calidad de Código|.github/workflows/ci.yml|pull_request,push,workflow_dispatch,custom|true|off"
    "docker-dry-run|Hardening y Build Docker (Alpine/Distroless)|.github/workflows/ci.yml|pull_request,push,workflow_dispatch,custom|false|off"
    "docs|Portal MkDocs, OpenAPI 3.1, Doxygen e i18n|.github/workflows/docs.yml|pull_request,push,workflow_dispatch,custom|true|local"
    "codeql|Análisis Semántico de Seguridad (CodeQL)|.github/workflows/codeql.yml|push,workflow_dispatch,custom|true|off"
    "package-distribution|Empaquetado CPack (.deb, .rpm, .zip)|.github/workflows/cd.yml|release,workflow_dispatch,custom|false|off"
    "publish-images|Construcción de Imágenes GHCR|.github/workflows/cd.yml|release,workflow_dispatch,custom|false|off"
)

CURRENT_EVENT="pull_request"
EVENT_INDEX=0

# Arreglos paralelos de jobs filtrados
ACTIVE_JOB_IDS=()
ACTIVE_JOB_NAMES=()
ACTIVE_JOB_FILES=()
ACTIVE_JOB_LOCAL_SUPPORT=()
ACTIVE_JOB_MODES=() # "docker", "local", "off"

# Cargar configuración desde verify.config si existe
load_existing_config() {
    local cfg_file="verify.config"
    [ ! -f "$cfg_file" ] && return 0

    local local_jobs docker_jobs
    local_jobs=$(grep -E '^local=' "$cfg_file" 2>/dev/null | cut -d'=' -f2- | tr ',' ' ')
    docker_jobs=$(grep -E '^docker=' "$cfg_file" 2>/dev/null | cut -d'=' -f2- | tr ',' ' ')

    for i in "${!ACTIVE_JOB_IDS[@]}"; do
        local jid="${ACTIVE_JOB_IDS[$i]}"
        ACTIVE_JOB_MODES[$i]="off"

        for lj in $local_jobs; do
            if [ "$lj" = "$jid" ] || [ "$lj" = "docs" -a "$jid" = "docs" ]; then
                ACTIVE_JOB_MODES[$i]="local"
            fi
        done

        for dj in $docker_jobs; do
            if [ "$dj" = "$jid" ]; then
                ACTIVE_JOB_MODES[$i]="docker"
            fi
        done
    done
}

filter_jobs_for_event() {
    local target_event="$1"
    ACTIVE_JOB_IDS=()
    ACTIVE_JOB_NAMES=()
    ACTIVE_JOB_FILES=()
    ACTIVE_JOB_LOCAL_SUPPORT=()
    ACTIVE_JOB_MODES=()

    for entry in "${JOB_REGISTRY[@]}"; do
        IFS='|' read -r jid jname jfile jevents jlocal jdefault <<< "$entry"
        if [ "$target_event" = "custom" ] || [[ ",$jevents," == *",$target_event,"* ]]; then
            ACTIVE_JOB_IDS+=("$jid")
            ACTIVE_JOB_NAMES+=("$jname")
            ACTIVE_JOB_FILES+=("$jfile")
            ACTIVE_JOB_LOCAL_SUPPORT+=("$jlocal")
            ACTIVE_JOB_MODES+=("$jdefault")
        fi
    done
}

# Captura de teclas portable con secuencias de escape
read_key() {
    local key=""
    local char=""
    IFS= read -rsn1 char
    if [ "$char" = $'\x1b' ]; then
        read -rsn2 -t 0.1 rest || true
        key="$char$rest"
    else
        key="$char"
    fi

    case "$key" in
        $'\x1b[A'|$'\x1bOA') echo "UP" ;;
        $'\x1b[B'|$'\x1bOB') echo "DOWN" ;;
        $'\x1b[C'|$'\x1bOC') echo "RIGHT" ;;
        $'\x1b[D'|$'\x1bOD') echo "LEFT" ;;
        "") echo "ENTER" ;;
        " ") echo "SPACE" ;;
        "m"|"M") echo "MODE" ;;
        "a"|"A") echo "ALL" ;;
        "n"|"N") echo "NONE" ;;
        "p"|"P") echo "PRESET" ;;
        "s"|"S") echo "SAVE" ;;
        "d"|"D") echo "DRYRUN" ;;
        "c"|"C") echo "COMMAND" ;;
        "b"|"B") echo "BACK" ;;
        "q"|"Q"|$'\x03') echo "QUIT" ;;
        *) echo "$key" ;;
    esac
}

draw_header() {
    local subtitle="$1"
    printf "${CLEAR_SCREEN}"
    printf "${CYAN}=============================================================================${NC}\n"
    printf "${BOLD}${CYAN}  🦅 CrowKit Workflow Runner — Orquestador Local & Docker (act)${NC}\n"
    printf "${CYAN}=============================================================================${NC}\n"
    if [ -n "$subtitle" ]; then
        printf "${YELLOW}%s${NC}\n" "$subtitle"
        printf "${DIM}-----------------------------------------------------------------------------${NC}\n"
    fi
}

# ------------------------------------------------------------------------------
# PANTALLA 1: Selección de Evento
# ------------------------------------------------------------------------------
select_event_screen() {
    stty -icanon -echo min 1 time 0 2>/dev/null || true
    printf "${HIDE_CURSOR}"

    while true; do
        draw_header "Paso 1: Selecciona el Evento de GitHub Actions a Simular"
        printf "${DIM}Usa las flechas [↑/↓] para navegar, [Enter] para seleccionar, [q] para salir.${NC}\n\n"

        for i in "${!EVENTS[@]}"; do
            IFS=':' read -r ev_name ev_desc <<< "${EVENTS[$i]}"
            if [ "$i" -eq "$EVENT_INDEX" ]; then
                printf "  ${BOLD}${GREEN}❯ [%-18s]${NC}  ${BOLD}%s${NC}\n" "$ev_name" "$ev_desc"
            else
                printf "    ${DIM}[%-18s]  %s${NC}\n" "$ev_name" "$ev_desc"
            fi
        done

        printf "\n${DIM}-----------------------------------------------------------------------------${NC}\n"
        printf "  ${BOLD}[Enter]${NC} Configurar Jobs  |  ${BOLD}[q]${NC} Salir\n"

        local key
        key=$(read_key)
        case "$key" in
            UP)
                if [ "$EVENT_INDEX" -gt 0 ]; then
                    EVENT_INDEX=$((EVENT_INDEX - 1))
                else
                    EVENT_INDEX=$((${#EVENTS[@]} - 1))
                fi
                ;;
            DOWN)
                if [ "$EVENT_INDEX" -lt $((${#EVENTS[@]} - 1)) ]; then
                    EVENT_INDEX=$((EVENT_INDEX + 1))
                else
                    EVENT_INDEX=0
                fi
                ;;
            ENTER)
                IFS=':' read -r CURRENT_EVENT _ <<< "${EVENTS[$EVENT_INDEX]}"
                filter_jobs_for_event "$CURRENT_EVENT"
                load_existing_config
                return 0
                ;;
            QUIT)
                printf "${CLEAR_SCREEN}${SHOW_CURSOR}"
                echo -e "${YELLOW}Operación cancelada por el usuario.${NC}"
                exit 0
                ;;
        esac
    done
}

# ------------------------------------------------------------------------------
# PANTALLA 2: Configuración de Jobs para el Evento
# ------------------------------------------------------------------------------
configure_jobs_screen() {
    local job_cursor=0
    stty -icanon -echo min 1 time 0 2>/dev/null || true
    printf "${HIDE_CURSOR}"

    while true; do
        draw_header "Paso 2: Configurar Jobs a Ejecutar para [Evento: ${CURRENT_EVENT}]"
        printf "${DIM}Navegar: [↑/↓] | Alternar On/Off: [Espacio] | Cambiar Modo (Docker/Local/Off): [m]${NC}\n"
        printf "${DIM}Acciones: [a] Todos ON | [n] Todos OFF | [p] Preset Rápido | [b] Cambiar Evento${NC}\n\n"

        printf "  %-3s  %-18s  %-35s  %-14s\n" "Sel" "Job ID" "Descripción" "Entorno"
        printf "  %-3s  %-18s  %-35s  %-14s\n" "---" "------" "-----------" "-------"

        for i in "${!ACTIVE_JOB_IDS[@]}"; do
            local jid="${ACTIVE_JOB_IDS[$i]}"
            local jname="${ACTIVE_JOB_NAMES[$i]}"
            local jmode="${ACTIVE_JOB_MODES[$i]}"
            local can_local="${ACTIVE_JOB_LOCAL_SUPPORT[$i]}"

            # Truncar nombre si excede
            if [ ${#jname} -gt 33 ]; then
                jname="${jname:0:30}..."
            fi

            local checkbox mode_badge
            case "$jmode" in
                docker)
                    checkbox="${GREEN}[✓]${NC}"
                    mode_badge="${BLUE}[🐳 DOCKER]${NC}"
                    ;;
                local)
                    checkbox="${GREEN}[✓]${NC}"
                    mode_badge="${MAGENTA}[🖥️  LOCAL ]${NC}"
                    ;;
                off)
                    checkbox="${DIM}[ ]${NC}"
                    mode_badge="${DIM}[❌ OMITIR]${NC}"
                    ;;
            esac

            local prefix="  "
            if [ "$i" -eq "$job_cursor" ]; then
                prefix="${BOLD}${GREEN}❯ ${NC}"
                printf "%b%b %-18s  ${BOLD}%-35s${NC}  %b\n" "$prefix" "$checkbox" "$jid" "$jname" "$mode_badge"
            else
                printf "%b%b %-18s  %-35s  %b\n" "$prefix" "$checkbox" "$jid" "$jname" "$mode_badge"
            fi
        done

        printf "\n${DIM}-----------------------------------------------------------------------------${NC}\n"
        printf "  ${BOLD}[Enter]${NC} Continuar / Menú de Acción  |  ${BOLD}[s]${NC} Guardar verify.config\n"
        printf "  ${BOLD}[d]${NC} Dry-Run (act -n)             |  ${BOLD}[b]${NC} Volver a Eventos  |  ${BOLD}[q]${NC} Salir\n"

        local key
        key=$(read_key)
        case "$key" in
            UP)
                if [ "$job_cursor" -gt 0 ]; then
                    job_cursor=$((job_cursor - 1))
                else
                    job_cursor=$((${#ACTIVE_JOB_IDS[@]} - 1))
                fi
                ;;
            DOWN)
                if [ "$job_cursor" -lt $((${#ACTIVE_JOB_IDS[@]} - 1)) ]; then
                    job_cursor=$((job_cursor + 1))
                else
                    job_cursor=0
                fi
                ;;
            SPACE)
                # Alternar entre activo (docker) y off
                if [ "${ACTIVE_JOB_MODES[$job_cursor]}" = "off" ]; then
                    ACTIVE_JOB_MODES[$job_cursor]="docker"
                else
                    ACTIVE_JOB_MODES[$job_cursor]="off"
                fi
                ;;
            MODE)
                # Ciclar: docker -> local (si soporta) -> off -> docker
                local current="${ACTIVE_JOB_MODES[$job_cursor]}"
                local can_loc="${ACTIVE_JOB_LOCAL_SUPPORT[$job_cursor]}"
                if [ "$current" = "docker" ]; then
                    if [ "$can_loc" = "true" ]; then
                        ACTIVE_JOB_MODES[$job_cursor]="local"
                    else
                        ACTIVE_JOB_MODES[$job_cursor]="off"
                    fi
                elif [ "$current" = "local" ]; then
                    ACTIVE_JOB_MODES[$job_cursor]="off"
                else
                    ACTIVE_JOB_MODES[$job_cursor]="docker"
                fi
                ;;
            ALL)
                for idx in "${!ACTIVE_JOB_MODES[@]}"; do
                    ACTIVE_JOB_MODES[$idx]="docker"
                done
                ;;
            NONE)
                for idx in "${!ACTIVE_JOB_MODES[@]}"; do
                    ACTIVE_JOB_MODES[$idx]="off"
                done
                ;;
            PRESET)
                # Preset estándar según el evento
                for idx in "${!ACTIVE_JOB_MODES[@]}"; do
                    local j="${ACTIVE_JOB_IDS[$idx]}"
                    if [ "$j" = "build" ] || [ "$j" = "test" ]; then
                        ACTIVE_JOB_MODES[$idx]="docker"
                    elif [ "$j" = "docs" ]; then
                        ACTIVE_JOB_MODES[$idx]="local"
                    else
                        ACTIVE_JOB_MODES[$idx]="off"
                    fi
                done
                ;;
            SAVE)
                save_to_verify_config
                printf "\n${GREEN}✔ Configuración guardada exitosamente en verify.config.${NC}\n"
                sleep 1.2
                ;;
            DRYRUN)
                execute_selection true
                return 0
                ;;
            BACK)
                return 1
                ;;
            ENTER)
                action_menu_screen
                local res=$?
                if [ "$res" -eq 2 ]; then
                    # Volver a editar jobs
                    continue
                else
                    return 0
                fi
                ;;
            QUIT)
                printf "${CLEAR_SCREEN}${SHOW_CURSOR}"
                echo -e "${YELLOW}Operación cancelada.${NC}"
                exit 0
                ;;
        esac
    done
}

# ------------------------------------------------------------------------------
# PANTALLA 3: Menú de Acción
# ------------------------------------------------------------------------------
action_menu_screen() {
    local act_cursor=0
    local actions=(
        "1. ▶️  Ejecutar Selección Ahora (Local + Docker act)"
        "2. 💾  Guardar Selección en 'verify.config'"
        "3. 🔍  Simular con Dry-Run (act -n sin contenedores)"
        "4. 📋  Mostrar Comando(s) CLI Generados"
        "5. ↩️   Volver a Editar Jobs"
        "6. 🚪  Salir sin Ejecutar"
    )

    while true; do
        draw_header "Paso 3: ¿Qué deseas hacer con la selección de [${CURRENT_EVENT}]?"
        printf "${DIM}Usa las flechas [↑/↓] y presiona [Enter].${NC}\n\n"

        for i in "${!actions[@]}"; do
            if [ "$i" -eq "$act_cursor" ]; then
                printf "  ${BOLD}${GREEN}❯ %s${NC}\n" "${actions[$i]}"
            else
                printf "    ${DIM}%s${NC}\n" "${actions[$i]}"
            fi
        done

        local key
        key=$(read_key)
        case "$key" in
            UP)
                act_cursor=$(( (act_cursor - 1 + ${#actions[@]}) % ${#actions[@]} ))
                ;;
            DOWN)
                act_cursor=$(( (act_cursor + 1) % ${#actions[@]} ))
                ;;
            ENTER)
                case "$act_cursor" in
                    0) # Ejecutar
                        execute_selection false
                        return 0
                        ;;
                    1) # Guardar
                        save_to_verify_config
                        printf "\n${GREEN}✔ Configuración guardada en verify.config.${NC}\n"
                        sleep 1.2
                        ;;
                    2) # Dry run
                        execute_selection true
                        return 0
                        ;;
                    3) # Mostrar comandos
                        show_generated_commands
                        ;;
                    4) # Volver
                        return 2
                        ;;
                    5) # Salir
                        printf "${CLEAR_SCREEN}${SHOW_CURSOR}"
                        exit 0
                        ;;
                esac
                ;;
            BACK)
                return 2
                ;;
            QUIT)
                printf "${CLEAR_SCREEN}${SHOW_CURSOR}"
                exit 0
                ;;
        esac
    done
}

save_to_verify_config() {
    local local_list=()
    local docker_list=()

    for i in "${!ACTIVE_JOB_IDS[@]}"; do
        local jid="${ACTIVE_JOB_IDS[$i]}"
        local jmode="${ACTIVE_JOB_MODES[$i]}"
        if [ "$jmode" = "local" ]; then
            local_list+=("$jid")
        elif [ "$jmode" = "docker" ]; then
            docker_list+=("$jid")
        fi
    done

    local local_str docker_str
    local_str=$(IFS=','; echo "${local_list[*]}")
    docker_str=$(IFS=','; echo "${docker_list[*]}")

    cat <<EOF > "verify.config"
# ==============================================================================
# CrowKit — Configuración de Verificación Local & Docker (verify.config) 🦅
# Generado interactivamente por .agents/scripts/runner-menu.sh
# Evento base: ${CURRENT_EVENT}
# ==============================================================================

# 1. Tareas a ejecutar directamente en el host local:
local=${local_str}

# 2. Tareas a delegar a contenedores Docker (vía act):
docker=${docker_str}
EOF
}

show_generated_commands() {
    draw_header "Comandos CLI Generados para Reproducción Manual"
    printf "\n${BOLD}1. Tareas Locales (Host):${NC}\n"
    local has_local=false
    for i in "${!ACTIVE_JOB_IDS[@]}"; do
        if [ "${ACTIVE_JOB_MODES[$i]}" = "local" ]; then
            has_local=true
            local jid="${ACTIVE_JOB_IDS[$i]}"
            case "$jid" in
                docs) echo "  • ./scripts/verify-docs.sh" ;;
                test) echo "  • ctest --test-dir build --output-on-failure" ;;
                build) echo "  • cmake --build build -j\$(nproc)" ;;
                cppcheck) echo "  • cppcheck --enable=warning,performance libs/ tools/" ;;
                codeql) echo "  • codeql database analyze ..." ;;
                *) echo "  • (ejecución nativa de $jid)" ;;
            esac
        fi
    done
    [ "$has_local" = false ] && echo "  (Ninguna tarea asignada al host local)"

    printf "\n${BOLD}2. Tareas en Docker (vía 'act'):${NC}\n"
    local has_docker=false
    for i in "${!ACTIVE_JOB_IDS[@]}"; do
        if [ "${ACTIVE_JOB_MODES[$i]}" = "docker" ]; then
            has_docker=true
            local jid="${ACTIVE_JOB_IDS[$i]}"
            local jfile="${ACTIVE_JOB_FILES[$i]}"
            echo "  • act ${CURRENT_EVENT} -j ${jid} -W ${jfile} --container-architecture linux/amd64"
        fi
    done
    [ "$has_docker" = false ] && echo "  (Ninguna tarea asignada a Docker)"

    printf "\n${DIM}Presiona cualquier tecla para regresar al menú de acciones...${NC}\n"
    read_key >/dev/null
}

execute_selection() {
    local is_dry_run="$1"
    stty echo icanon 2>/dev/null || true
    printf "${CLEAR_SCREEN}${SHOW_CURSOR}"

    printf "${CYAN}=============================================================================${NC}\n"
    if [ "$is_dry_run" = true ]; then
        printf "${BOLD}${YELLOW}  🔍 INICIANDO SIMULACIÓN DRY-RUN [Evento: ${CURRENT_EVENT}]${NC}\n"
    else
        printf "${BOLD}${GREEN}  ▶️  INICIANDO EJECUCIÓN ORQUESTADA [Evento: ${CURRENT_EVENT}]${NC}\n"
    fi
    printf "${CYAN}=============================================================================${NC}\n\n"

    local start_time=$(date +%s)
    local failed_jobs=()
    local success_jobs=()

    # 1. Ejecutar tareas locales primero
    for i in "${!ACTIVE_JOB_IDS[@]}"; do
        if [ "${ACTIVE_JOB_MODES[$i]}" = "local" ]; then
            local jid="${ACTIVE_JOB_IDS[$i]}"
            local jname="${ACTIVE_JOB_NAMES[$i]}"
            printf "${MAGENTA}[LOCAL] Ejecutando: %s (${jid})...${NC}\n" "$jname"

            if [ "$is_dry_run" = true ]; then
                printf "${DIM}  [DRY-RUN] Comando local simulado.${NC}\n"
                success_jobs+=("[LOCAL] $jid")
                continue
            fi

            local job_status=0
            case "$jid" in
                docs)
                    ./scripts/verify-docs.sh || job_status=$?
                    ;;
                test)
                    ctest --test-dir build --output-on-failure || job_status=$?
                    ;;
                build)
                    cmake --build build -j$(nproc) || job_status=$?
                    ;;
                cppcheck)
                    cppcheck --enable=warning,performance,portability --error-exitcode=1 libs/ tools/ || job_status=$?
                    ;;
                *)
                    printf "${YELLOW}  [AVISO] No hay runner local nativo para ${jid}, omitiendo.${NC}\n"
                    ;;
            esac

            if [ "$job_status" -eq 0 ]; then
                printf "${GREEN}✔ [LOCAL] %s completado con éxito.${NC}\n\n" "$jid"
                success_jobs+=("[LOCAL] $jid")
            else
                printf "${RED}✘ [LOCAL] %s falló con código ${job_status}.${NC}\n\n" "$jid"
                failed_jobs+=("[LOCAL] $jid")
            fi
        fi
    done

    # 2. Ejecutar tareas Docker vía act
    local docker_jobs_to_run=()
    for i in "${!ACTIVE_JOB_IDS[@]}"; do
        if [ "${ACTIVE_JOB_MODES[$i]}" = "docker" ]; then
            docker_jobs_to_run+=("${ACTIVE_JOB_IDS[$i]}")
        fi
    done

    if [ ${#docker_jobs_to_run[@]} -gt 0 ]; then
        printf "${BLUE}[DOCKER] Preparando ejecución en contenedores vía 'act'...${NC}\n"

        # Verificar docker y socket
        if [ -z "$DOCKER_HOST" ] && [ ! -S "/var/run/docker.sock" ]; then
            if [ -S "$HOME/.docker/desktop/docker.sock" ]; then
                export DOCKER_HOST="unix://$HOME/.docker/desktop/docker.sock"
            elif [ -S "/run/user/$(id -u)/docker.sock" ]; then
                export DOCKER_HOST="unix:///run/user/$(id -u)/docker.sock"
            fi
        fi

        for jid in "${docker_jobs_to_run[@]}"; do
            printf "${BLUE}-------------------------------------------------------------${NC}\n"
            printf "${BLUE}[DOCKER] Lanzando job: %s en 'act'...${NC}\n" "$jid"
            printf "${BLUE}-------------------------------------------------------------${NC}\n"

            # Encontrar el workflow file correspondiente
            local wfile=".github/workflows/ci.yml"
            for k in "${!ACTIVE_JOB_IDS[@]}"; do
                if [ "${ACTIVE_JOB_IDS[$k]}" = "$jid" ]; then
                    wfile="${ACTIVE_JOB_FILES[$k]}"
                    break
                fi
            done

            local act_args=("$CURRENT_EVENT" "-j" "$jid" "-W" "$wfile" "--container-architecture" "linux/amd64")
            if [ "$is_dry_run" = true ]; then
                act_args+=("-n")
            fi

            local act_status=0
            act "${act_args[@]}" || act_status=$?

            if [ "$act_status" -eq 0 ]; then
                printf "${GREEN}✔ [DOCKER] %s finalizado con éxito.${NC}\n\n" "$jid"
                success_jobs+=("[DOCKER] $jid")
            else
                printf "${RED}✘ [DOCKER] %s falló en act (código: %s).${NC}\n\n" "$jid" "$act_status"
                failed_jobs+=("[DOCKER] $jid")
            fi
        done
    fi

    local end_time=$(date +%s)
    local total_time=$((end_time - start_time))

    # Resumen final
    printf "${CYAN}=============================================================================${NC}\n"
    printf "${BOLD}                    RESUMEN DE EJECUCIÓN LOCAL CROWKIT                       ${NC}\n"
    printf "${CYAN}=============================================================================${NC}\n"
    for s in "${success_jobs[@]}"; do
        printf "  %-30s -> ${GREEN}✅ APROBADO${NC}\n" "$s"
    done
    for f in "${failed_jobs[@]}"; do
        printf "  %-30s -> ${RED}❌ FALLIDO${NC}\n" "$f"
    done
    printf "${DIM}-----------------------------------------------------------------------------${NC}\n"
    printf "  Tiempo total: ${BOLD}%ds${NC}\n" "$total_time"

    if [ ${#failed_jobs[@]} -eq 0 ]; then
        printf "  Estado Global: ${BOLD}${GREEN}✅ TODOS LOS JOBS APROBADOS LOCALMENTE${NC}\n"
        printf "${CYAN}=============================================================================${NC}\n"
        return 0
    else
        printf "  Estado Global: ${BOLD}${RED}❌ FALLARON ${#failed_jobs[@]} JOBS${NC}\n"
        printf "${CYAN}=============================================================================${NC}\n"
        return 1
    fi
}

# ------------------------------------------------------------------------------
# PUNTO DE ENTRADA PRINCIPAL
# ------------------------------------------------------------------------------
main() {
    # Soporte para argumentos directos por CLI si no se desea interactivo
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --event|-e)
                CURRENT_EVENT="$2"
                shift 2
                ;;
            --dry-run|-n)
                filter_jobs_for_event "${CURRENT_EVENT:-pull_request}"
                load_existing_config
                execute_selection true
                exit $?
                ;;
            --help|-h)
                echo "Uso: $0 [opciones]"
                echo ""
                echo "Opciones:"
                echo "  -i, --interactive    Lanza la TUI interactiva para seleccionar evento y jobs (por defecto)"
                echo "  -e, --event <evento> Define el evento base (pull_request, push, workflow_dispatch, release)"
                echo "  -n, --dry-run        Ejecuta simulación sin contenedores para la configuración actual"
                echo "  -h, --help           Muestra esta ayuda"
                exit 0
                ;;
            *)
                shift
                ;;
        esac
    done

    # Bucle de navegación entre pantallas interactivas
    while true; do
        select_event_screen
        configure_jobs_screen
        local status=$?
        # Si configure_jobs_screen retornó 1, regresa a seleccionar evento
        [ "$status" -eq 1 ] && continue
        break
    done
}

main "$@"
