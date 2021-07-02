#!/usr/bin/env sh
# ======================================================================
#
# NAME
#
#     galyleo.sh
#
# DESCRIPTION
#
#     A shell utility to help you launch Jupyter notebooks on a remote
#     system in a secure way.
#
# USAGE
#
# DEPENDENCIES
#
#     jupyter
#     jupyterlab
#     satellite - https://github.com/sdsc-hpc-training-org/satellite
#
# TODO
#
#     Add support for non-jupyter-based web services; 
#       e.g., Spark and TensorBoard
#
# AUTHOR(S)
#
#     Marty Kandes, Ph.D.
#     Computational & Data Science Research Specialist
#     High-Performance Computing User Services Group
#     San Diego Supercomputer Center
#     University of California, San Diego
#
# LAST UPDATED
#
#     Thursday, July 1st, 2021
#
# ----------------------------------------------------------------------

# Declare a global environment variable to set the installation location
# of galyleo. DO NOT leave as PWD when deployed in production. In the
# future, may include a Makefile with a PREFIX option to install
# correctly and set this variable. e.g., https://github.com/oyvinev/log.sh

declare -xr GALYLEO_INSTALL_DIR="${PWD}"

# Declare a global environment variable to set the galyleo cache
# directory, which will hold all output files generated by galyleo.
# e.g., Slurm batch job scripts, Slurm standard output files, etc.

declare -xr GALYLEO_CACHE_DIR="${HOME}/.galyleo"

# Declare a set of global environment variables used to identify a
# specific execution of galyleo. e.g., used to label a unique id of the
# generated batch job script.

declare -xr CURRENT_LOCAL_TIME="$(date +'%Y%m%dT%H%M%S%z')"
declare -xir CURRENT_UNIX_TIME="$(date +'%s')"
declare -xir RANDOM_ID="${RANDOM}"

# Source all shell libraries required for galyleo.
source "${GALYLEO_INSTALL_DIR}/lib/slog.sh"

# Source the galyleo configuration file. If it does not exist yet, then
# one must be created with the galyleo configure command. A galyleo.conf
# file must be created prior to end-user use of its launch capabilities.
if [[ ! -f "${GALYLEO_INSTALL_DIR}/galyleo.conf" ]]; then
  slog warning -m 'galyleo.conf file does not exist yet.'
else
  source "${GALYLEO_INSTALL_DIR}/galyleo.conf"
  if [[ "${?}" -ne 0 ]]; then
    slog error -m 'Failed to source galyleo.conf file.'
    exit 1
  fi
fi

# ----------------------------------------------------------------------
# galyleo_launch
#
#   Launches a Jupyter notebook server on a remote system. There will be
#   several modes of operation that are supported with the 'launch'
#   command. However, only the 'local' launch mode is available at this
#   time. i.e., 'local' -> no SSH involved.
#
# Globals:
#
#   GALYLEO_CACHE_DIR
#   SLOG_LEVEL
#
# Arguments:
#
#      | --mode <mode>
#   -A | --account <account>
#   -R | --reservation <reservation>
#   -p | --partition <partition>
#   -q | --qos <qos>
#   -N | --nodes <nodes>
#   -n | --ntasks-per-node <ntasks_per_node>
#   -c | --cpus-per-task <cpus_per_node>
#   -M | --memory-per-node <memory_per_node> (in units of GB)
#   -m | --memory-per-cpu <memory_per_cpu> (in units of GB)
#   -G | --gpus <gpus>
#      | --gres <gres>
#   -t | --time-limit <time_limit>
#   -C | --constraint <constraint>
#   -j | --jupyter <jupyter_interface>
#   -d | --notebook-dir <jupyter_notebook_dir>
#   -s | --sif <singularity_image_file>
#   -B | --bind <singularity_bind_mounts>
#      | --nv
#   -e | --env-modules <env_modules>
#      | --conda-env <conda_env>
#   -Q | --quiet
#
# Returns:
#
#   True  (0) if the launch was successful.
#   False (1) if the launch failed and/or was halted.
#
# ----------------------------------------------------------------------
function galyleo_launch() {

  # Declare galyleo launch mode variable and set its default to 'local'.
  local mode='local'

  # Declare input variables associated with scheduler.
  local account=''
  local reservation=''
  local partition="${GALYLEO_DEFAULT_PARTITION}"
  local qos=''
  local -i nodes=1
  local -i ntasks_per_node=1
  local -i cpus_per_task=1
  local -i memory_per_node=-1
  local -i memory_per_cpu=2
  local gpus=''
  local gres=''
  local time_limit='00:30:00'
  local constraint=''

  # Declare input variables associated with Jupyter runtime environment.
  local jupyter_interface="${GALYLEO_DEFAULT_JUPYTER_INTERFACE}"
  local jupyter_notebook_dir=''

  # Declare input variables associated with Singularity containers.
  local singularity_image_file=''
  local singularity_bind_mounts=''
  local singularity_gpu_type=''

  # Declare input variables associated with environment modules.
  local env_modules=''

  # Declare input variables associated with conda environments.
  local conda_env=''

  # Declare internal galyelo_launch variables not affected by input variables.
  local job_name="galyleo-${CURRENT_LOCAL_TIME}-${CURRENT_UNIX_TIME}-${RANDOM_ID}"
  local -i job_id=-1
  local http_response=''
  local -i http_status_code=-1

  # Read in command-line options and assign input variables to local
  # variables.
  while (("${#}" > 0)); do
    case "${1}" in
      --mode )
        mode="${2}"
        shift 2
        ;;
      -A | --account )
        account="${2}"
        shift 2
        ;;
      -R | --reservation )
        reservation="${2}"
        shift 2
        ;;
      -p | --partition )
        partition="${2}"
        shift 2
        ;;
      -q | --qos )
        qos="${2}"
        shift 2
        ;;
      -N | --nodes )
        nodes="${2}"
        shift 2
        ;;
      -n | --ntasks-per-node )
        ntasks_per_node="${2}"
        shift 2
        ;;
      -c | --cpus-per-task )
        cpus_per_task="${2}"
        shift 2
        ;;
      -M | --memory-per-node )
        memory_per_node="${2}"
        shift 2
        ;;
      -m | --memory-per-cpu )
        memory_per_cpu="${2}"
        shift 2
        ;;
      -G | --gpus )
        gpus="${2}"
        shift 2
        ;;
      --gres )
        gres="${2}"
        shift 2
        ;;
      -t | --time-limit )
        time_limit="${2}"
        shift 2
        ;;
      -C | --constraint )
        constraint="${2}"
        shift 2
        ;;
      -j | --jupyter )
        jupyter_interface="${2}"
        shift 2
        ;;
      -d | --notebook-dir )
        jupyter_notebook_dir="${2}"
        shift 2
        ;;
      -s | --sif )
        singularity_image_file="${2}"
        shift 2
        ;;
      -B | --bind )
        singularity_bind_mounts="${2}"
        shift 2
        ;;
      --nv )
        singularity_gpu_type='nv'
        shift 1
        ;;
      --rocm )
        singularity_gpu_type='rocm'
        shift 1
        ;;
      -e | --env-modules )
        env_modules="${2}"
        shift 2
        ;;
      --conda-env )
        conda_env="${2}"
        shift 2
        ;;
      -Q | --quiet )
        SLOG_LEVEL=0
        shift 1
        ;;
      *)
        slog error -m "Command-line option ${1} not recognized or not supported."
        return 1
    esac
  done

  # Print all command-line options read in for launch to standard output.
  slog output -m 'Preparing galyleo for launch into Jupyter orbit ...'
  slog output -m 'Listing all launch parameters ...'
  slog output -m '  command-line option      : value'
  slog output -m "       | --mode            : ${mode}"
  slog output -m "    -A | --account         : ${account}"
  slog output -m "    -R | --reservation     : ${reservation}"
  slog output -m "    -p | --partition       : ${partition}"
  slog output -m "    -q | --qos             : ${qos}"
  slog output -m "    -N | --nodes           : ${nodes}"
  slog output -m "    -n | --ntasks-per-node : ${ntasks_per_node}"
  slog output -m "    -c | --cpus-per-task   : ${cpus_per_task}"
  slog output -m "    -M | --memory-per-node : ${memory_per_node} GB"
  slog output -m "    -m | --memory-per-cpu  : ${memory_per_cpu} GB"
  slog output -m "    -G | --gpus            : ${gpus}"
  slog output -m "       | --gres            : ${gres}"
  slog output -m "    -t | --time-limit      : ${time_limit}"
  slog output -m "    -j | --jupyter         : ${jupyter_interface}"
  slog output -m "    -d | --notebook-dir    : ${jupyter_notebook_dir}"
  slog output -m "    -s | --sif             : ${singularity_image_file}"
  slog output -m "    -B | --bind            : ${singularity_bind_mounts}"
  slog output -m "       | --nv              : ${singularity_gpu_type}"
  slog output -m "    -e | --env-modules     : ${env_modules}"
  slog output -m "       | --conda-env       : ${conda_env}"
  slog output -m "    -Q | --quiet           : ${SLOG_LEVEL}"

  # Check if the user specified a Jupyter user interface. If the user
  # did not specify a user interface, then set JupyterLab ('lab') as the
  # default interface.
  if [[ -z "${jupyter_interface}" ]]; then
    jupyter_interface='lab'
  fi

  # Check if a valid Jupyter user interface was specified. At 
  # present, the only two valid user interfaces are JupyterLab ('lab')
  # OR Jupyter Notebook ('notebook'). If an invalid interface name is
  # provided by the user, then halt the launch.
  case "${jupyter_interface}" in
    'lab' )
      ;;
    'notebook' )
      ;;
    *)
    slog error -m "Not a valid Jupyter user interface: ${jupyter_interface}"
    slog error -m "Only --jupyter lab OR --jupyter notebook are allowed."
    return 1
  esac

  # Check if the user specified a working directory for their Jupyter
  # notebook session. If the user did not specify a working directory,
  # then set the working directory to the user's $HOME directory.
  if [[ -z "${jupyter_notebook_dir}" ]]; then
    jupyter_notebook_dir="${HOME}"
  fi

  # Change the present working directory to the Jupyter notebook
  # directory. If the directory does not exist, then halt the launch.
  cd "${jupyter_notebook_dir}"
  if [[ "${?}" -ne 0 ]]; then
    if [[ ! -d "${jupyter_notebook_dir}" ]]; then
      slog error -m "Jupyter notebook directory does not exist: ${jupyter_notebook_dir}"
    else
      slog error -m "Unable to change to the Jupyter notebook directory: ${jupyter_notebook_dir}"
    fi
    return 1
  fi

  # Check if all environment modules specified by the user, if any, are
  # available and can be loaded successfully. If not, then halt the launch.
  if [[ -n "${env_modules}" ]]; then
    IFS=','
    read -r -a modules <<< "${env_modules}"
    unset IFS
    for module in "${modules[@]}"; do
      module load "${module}"
      if [[ $? -ne 0 ]]; then
        slog error -m "module not found: ${module}"
        return 1
      fi
    done
  fi

  # Check if the conda environment specified by the user, if any, has
  # been initialized, configured in the user's .bashrc file, and can be
  # activated successfully. If not, then halt the launch.
  if [[ -n "${conda_env}" ]]; then
    source ~/.bashrc
    conda activate "${conda_env}"
    if [[ $? -ne 0 ]]; then
      slog error -m "conda environment not found: ${conda_env}"
      return 1
    fi
  fi

  # Check if the Singularity container image file specified by the user,
  # if any, exists. If it does not exist, then halt the launch.
  if [[ -n "${singularity_image_file}" ]]; then
    if [[ ! -f "${singularity_image_file}" ]]; then
      slog error -m "Singularity image file does not exist: ${singularity_image_file}"
      return 1
    fi
  fi

  # Request a subdomain connection token from reverse proxy service. If the 
  # reverse proxy service returns an HTTP/S error, then halt the launch.
  http_response="$(curl -s -w %{http_code} https://manage.${GALYLEO_REVERSE_PROXY_FQDN}/getlink.cgi -o -)"
  slog output -m "${http_response}"
  http_status_code="$(echo ${http_response} | awk '{print $NF}')"
  if (( "${http_status_code}" != 200 )); then
    slog error -m "Unable to connect to the Satellite reverse proxy service: ${http_status_code}"
    return 1
  fi

  # Extract the reverse proxy connection token and export it as a
  # read-only environment variable.
  declare -xr REVERSE_PROXY_TOKEN="$(echo ${http_response} | awk 'NF>1{printf $((NF-1))}' -)"

  # Generate an authentication token to be used for first-time 
  # connections to the Jupyter notebook server and export it as a 
  # read-only environment variable.
  declare -xr JUPYTER_TOKEN="$(openssl rand -hex 16)"

  # Change present working directory to GALYLEO_CACHE_DIR. Generate and
  # store all Jupyter launch scripts and standard output files in the
  # GALYLEO_CACHE_DIR. Users should not need to access these files when
  # the service is working properly. They will generally only be useful
  # for debugging purposes by SDSC staff. A cleanup function to clear
  # the cache will be provided. We will eventually do some default
  # purging of older files to prevent cache buildup.
  if [[ ! -d "${GALYLEO_CACHE_DIR}" ]]; then
    mkdir -p "${GALYLEO_CACHE_DIR}"
    chmod u+rwx "${GALYLEO_CACHE_DIR}"
    chmod g-rwx "${GALYLEO_CACHE_DIR}"
    chmod o-rwx "${GALYLEO_CACHE_DIR}"
    if [[ "${?}" -ne 0 ]]; then
      slog error -m "Failed to create GALYLEO_CACHE_DIR at ${GALYLEO_CACHE_DIR}."
      return 1
    fi
  fi
  cd "${GALYLEO_CACHE_DIR}"

  # Generate a Jupyter launch script.
  slog output -m 'Generating Jupyter launch script ...'
  if [[ ! -f "${job_name}.sh" ]]; then

    slog append -f "${job_name}.sh" -m '#!/usr/bin/env sh'
    slog append -f "${job_name}.sh" -m ''
    slog append -f "${job_name}.sh" -m "#SBATCH --job-name=${job_name}"

    if [[ -n "${account}" ]]; then
      slog append -f "${job_name}.sh" -m "#SBATCH --account=${account}"
    else
      slog error -m 'No account specified. Every job must be charged to an account.'
      rm "${job_name}.sh"
      return 1
    fi

    if [[ -n "${reservation}" ]]; then
      slog append -f "${job_name}.sh" -m "#SBATCH --reservation=${reservation}"
    fi

    if [[ -n "${qos}" ]]; then
      slog append -f "${job_name}.sh" -m "#SBATCH --qos=${qos}"
    fi

    slog append -f "${job_name}.sh" -m "#SBATCH --partition=${partition}"
    slog append -f "${job_name}.sh" -m "#SBATCH --nodes=${nodes}"
    slog append -f "${job_name}.sh" -m "#SBATCH --ntasks-per-node=${ntasks_per_node}"
    slog append -f "${job_name}.sh" -m "#SBATCH --cpus-per-task=${cpus_per_task}"

    if (( "${memory_per_node}" > 0 )); then
      slog append -f "${job_name}.sh" -m "#SBATCH --mem=${memory_per_node}G"
    else
      slog append -f "${job_name}.sh" -m "#SBATCH --mem-per-cpu=${memory_per_cpu}G"
    fi

    if [[ -n "${gpus}" && -z "${gres}" ]]; then
      slog append -f "${job_name}.sh" -m "#SBATCH --gpus=${gpus}"
    elif [[ -z "${gpus}" && -n "${gres}" ]]; then
      slog append -f "${job_name}.sh" -m "#SBATCH --gres=${gres}"
    fi

    slog append -f "${job_name}.sh" -m "#SBATCH --time=${time_limit}"

    if [[ -n "${constraint}" ]]; then
      slog append -f "${job_name}.sh" -m "#SBATCH --constraint=${constraint}"
    fi

    slog append -f "${job_name}.sh" -m "#SBATCH --no-requeue"
    slog append -f "${job_name}.sh" -m "#SBATCH --export=ALL"
    slog append -f "${job_name}.sh" -m "#SBATCH --output=${job_name}.o%j.%N"
    slog append -f "${job_name}.sh" -m ''

    slog append -f "${job_name}.sh" -m 'declare -xr JUPYTER_RUNTIME_DIR="${HOME}/.jupyter/runtime"'
    slog append -f "${job_name}.sh" -m 'declare -xi JUPYTER_PORT=-1'
    slog append -f "${job_name}.sh" -m 'declare -xir LOWEST_EPHEMERAL_PORT=49152'
    slog append -f "${job_name}.sh" -m 'declare -i random_ephemeral_port=-1'
    slog append -f "${job_name}.sh" -m ''

    # Load environment modules specified by the user.
    slog append -f "${job_name}.sh" -m 'module purge'
    if [[ -n "${env_modules}" ]]; then
      IFS=','
      read -r -a modules <<< "${env_modules}"
      unset IFS
      for module in "${modules[@]}"; do
        slog append -f "${job_name}.sh" -m  "module load ${module}"
      done
    fi

    # Activate a conda environment specified by the user.
    if [[ -n "${conda_env}" ]]; then
      slog append -f "${job_name}.sh" -m 'source ~/.bashrc'
      slog append -f "${job_name}.sh" -m "conda activate ${conda_env}"
    fi
    slog append -f "${job_name}.sh" -m ''

    # Choose an open ephemeral port at random.
    slog append -f "${job_name}.sh" -m 'while (( "${JUPYTER_PORT}" < 0 )); do'
    slog append -f "${job_name}.sh" -m '  while (( "${random_ephemeral_port}" < "${LOWEST_EPHEMERAL_PORT}" )); do'
    slog append -f "${job_name}.sh" -m '    random_ephemeral_port="$(od -An -N 2 -t u2 -v < /dev/urandom)"'
    slog append -f "${job_name}.sh" -m '  done'
    slog append -f "${job_name}.sh" -m '  ss -nutlp | cut -d : -f2 | grep "^${random_ephemeral_port})" > /dev/null'
    slog append -f "${job_name}.sh" -m '  if [[ "${?}" -ne 0 ]]; then'
    slog append -f "${job_name}.sh" -m '    JUPYTER_PORT="${random_ephemeral_port}"'
    slog append -f "${job_name}.sh" -m '  fi'
    slog append -f "${job_name}.sh" -m 'done'
    slog append -f "${job_name}.sh" -m ''

    # Structure the singularity exec command and its command-line
    # options specified by the user.
    if [[ -n "${singularity_image_file}" ]]; then
      slog append -f "${job_name}.sh" -m 'singularity exec \'
      if [[ -n "${singularity_bind_mounts}" ]]; then
        slog append -f "${job_name}.sh" -m "  --bind ${singularity_bind_mounts} \\"
      fi
      if [[ -n "${singularity_gpu_type}" ]]; then
        slog append -f "${job_name}.sh" -m "  --${singularity_gpu_type} \\"
      fi
      slog append -f "${job_name}.sh" -m "  ${singularity_image_file} \\"
    fi

    # Run the Jupyter server process in the backgroud.
    slog append -f "${job_name}.sh" -m "jupyter ${jupyter_interface} --ip=\"\$(hostname -s).${GALYLEO_DNS_DOMAIN}\" --notebook-dir='${jupyter_notebook_dir}' --port=\"\${JUPYTER_PORT}\" --NotebookApp.allow_origin='*' --KernelManager.transport='ipc' --no-browser &"
    slog append -f "${job_name}.sh" -m 'if [[ "${?}" -ne 0 ]]; then'
    slog append -f "${job_name}.sh" -m "  echo 'ERROR: Failed to launch Jupyter.'"
    slog append -f "${job_name}.sh" -m '  exit 1'
    slog append -f "${job_name}.sh" -m 'fi'
    slog append -f "${job_name}.sh" -m ''

    # Redeem the connection token from reverse proxy service to enable
    # proxy mapping.
    slog append -f "${job_name}.sh" -m 'curl "https://manage.${GALYLEO_REVERSE_PROXY_FQDN}/redeemtoken.cgi?token=${REVERSE_PROXY_TOKEN}&port=${JUPYTER_PORT}"'
    slog append -f "${job_name}.sh" -m ''

    # Wait for the Jupyter server to be shutdown by the user.
    slog append -f "${job_name}.sh" -m 'wait'
    slog append -f "${job_name}.sh" -m ''

    # Revoke the connection token from reverse proxy service once the
    # Jupyter server has been shutdown.
    slog append -f "${job_name}.sh" -m 'curl "https://manage.${GALYLEO_REVERSE_PROXY_FQDN}/destroytoken.cgi?token=${REVERSE_PROXY_TOKEN}"'

  else

    slog error -m 'Jupyter launch script already exists. Cannot overwrite.'
    return 1

  fi

  # Submit Jupyter launch script to Slurm.
  job_id="$(sbatch ${job_name}.sh | grep -o '[[:digit:]]*')"
  if [[ "${?}" -ne 0 ]]; then
    slog error -m 'Failed job submission to Slurm.'
    http_response="$(curl -s https://manage.${GALYLEO_REVERSE_PROXY_FQDN}/destroytoken.cgi?token=${REVERSE_PROXY_TOKEN})"
    slog output -m "${http_response}"
    return 1
  else
    slog output -m "Submitted Jupyter launch script to Slurm. Your SLURM_JOB_ID is ${job_id}."
  fi

  # Associate batch job id to the connection token from the reverse proxy service.
  http_response="$(curl -s https://manage.${GALYLEO_REVERSE_PROXY_FQDN}/linktoken.cgi?token=${REVERSE_PROXY_TOKEN}\&jobid=${job_id})"
  slog output -m "${http_response}"

  # Always print to standard output the URL where the Jupyter notebook 
  # server may be accessed by the user.
  slog output -m 'Please copy and paste the HTTPS URL provided below into your web browser.'
  slog output -m 'Do not share this URL with others. It is the password to your Jupyter notebook session.'
  slog output -m 'Your Jupyter notebook session will begin once compute resources are allocated to your Slurm job by the scheduler.'
  echo "https://${REVERSE_PROXY_TOKEN}.${GALYLEO_REVERSE_PROXY_FQDN}?token=${JUPYTER_TOKEN}"

  return 0

}

# ----------------------------------------------------------------------
# galyleo_configure
#
#   Sets the GALYLEO_INSTALL_DIR to a fixed, absolute path and creates a
#   global configuration file (galyleo.conf), where system-specifc
#   deployment variables like the fully-qualified domain name of the
#   Satellite reverse proxy server and the default Slurm partition for
#   all galyleo launches can be set.
#
# Globals:
#
#   GALYLEO_INSTALL_DIR
#
# Arguments:
#
#   -r | --reverse-proxy <reverse_proxy_fqdn>
#   -D | --dns-domain <dns_domain>
#   -p | --partition <partition>
#   -j | --jupyter <jupyter_interface>
#
# Returns:
#
#   True (0) if galyleo was configured successfully.
#   False (1) if galyleo configuration failed.
#
# ----------------------------------------------------------------------
function galyleo_configure() {

  # Declare local variables associated with reverse proxy service.
  local reverse_proxy_fqdn='expanse-user-content.sdsc.edu'
  local dns_domain='eth.cluster'

  # Declare default variables associated with scheduler.
  local partition='shared'

  # Declare default variables associated with Jupyter runtime environment.
  local jupyter_interface='lab'

  # Read in command-line options and assign input variables to local
  # variables.
  while (("${#}" > 0)); do
    case "${1}" in
      -r | --reverse-proxy )
        reverse_proxy_fqdn="${2}"
        shift 2
        ;;
      -D | --dns-domain )
        dns_domain="${2}"
        shift 2
        ;;
      -p | --partition )
        partition="${2}"
        shift 2
        ;;
      -j | --jupyter )
        jupyter_interface="${2}"
        shift 2
        ;;
      *)
        slog error -m "Command-line option ${1} not recognized or not supported."
        return 1
    esac
  done

  # If the galyleo configuration file already exists, do not let the
  # galyleo configure command reconfigure and overwrite it. This is
  # intended to force the original configuration file owner --- e.g.,
  # the system administrator who deployed galyleo --- to manually
  # remove the existing configuration file first. If the configuration
  # file does not exist yet, then create it.
  if [[ -f "${GALYLEO_INSTALL_DIR}/galyleo.conf" ]]; then

    slog error -m 'galyleo.conf cannot be overwritten with this command.'
    return 1

  else

     slog output -m 'Setting GALYLEO_INSTALL_DIR ... '

     sed -i "s|\"\${PWD}\"|'${PWD}'|" 'galyleo.sh'

     slog output -m 'Creating galyleo.conf file ... '

     slog append -f 'galyleo.conf' -m '#!/usr/bin/env sh'
     slog append -f 'galyleo.conf' -m "declare -xr GALYLEO_REVERSE_PROXY_FQDN='${reverse_proxy_fqdn}'"
     slog append -f 'galyleo.conf' -m "declare -xr GALYLEO_DNS_DOMAIN='${dns_domain}'"
     slog append -f 'galyleo.conf' -m "declare -xr GALYLEO_DEFAULT_PARTITION='${partition}'"
     slog append -f 'galyleo.conf' -m "declare -xr GALYLEO_DEFAULT_JUPYTER_INTERFACE='${jupyter_interface}'"

  fi

  slog output -m 'galyleo configuration complete.'

  return 0

}

# ----------------------------------------------------------------------
# galyleo_clean
#
#   Clean up the GALYLEO_CACHE_DIR. 
#
# Globals:
#
#   None
#
# Arguments:
#
#   None
#
# Returns:
#
#   True (0) always.
#
# ----------------------------------------------------------------------
function galyleo_clean() {

  rm -r "${GALYLEO_CACHE_DIR}"

  return 0

}

# ----------------------------------------------------------------------
# galyleo_help
#
#   Provides usage information to help users run galyleo.
#
# Globals:
#
#   None
#
# Arguments:
#
#   None
#
# Returns:
#
#   True (0) always.
#
# ----------------------------------------------------------------------
function galyleo_help() {

  slog output -m 'USAGE: galyleo.sh launch [command-line option] {value}'
  slog output -m ''
  slog output -m "    -A | --account         : ${account}"
  slog output -m "    -R | --reservation     : ${reservation}"
  slog output -m "    -p | --partition       : ${partition}"
  slog output -m "    -q | --qos             : ${qos}"
  slog output -m "    -N | --nodes           : ${nodes}"
  slog output -m "    -n | --ntasks-per-node : ${ntasks_per_node}"
  slog output -m "    -c | --cpus-per-task   : ${cpus_per_task}"
  slog output -m "    -M | --memory-per-node : ${memory_per_node} GB"
  slog output -m "    -m | --memory-per-cpu  : ${memory_per_cpu} GB"
  slog output -m "    -G | --gpus            : ${gpus}"
  slog output -m "       | --gres            : ${gres}"
  slog output -m "    -t | --time-limit      : ${time_limit}"
  slog output -m "    -j | --jupyter         : ${jupyter_interface}"
  slog output -m "    -d | --notebook-dir    : ${jupyter_notebook_dir}"
  slog output -m "    -s | --sif             : ${singularity_image_file}"
  slog output -m "    -B | --bind            : ${singularity_bind_mounts}"
  slog output -m "       | --nv              : ${singularity_gpu_type}"
  slog output -m "    -e | --env-modules     : ${env_modules}"
  slog output -m "       | --conda-env       : ${conda_env}"
  slog output -m "    -Q | --quiet           : ${SLOG_LEVEL}"
  slog output -m ''

  return 0

}

# ----------------------------------------------------------------------
# galyleo
#
#   This is the main function used to control the execution of galyleo
#   and its auxiliary functions.
#
# Globals:
#
#   @
#
# Arguments:
#
#   @
#
# Returns:
#
#   True  (0) if galyleo executed successfully without issue.
#   False (1) if galyleo failed to execute properly.
#
# ----------------------------------------------------------------------
function galyleo() {

  # Define local variables.
  local galyleo_command

  # Assign default values to local variables.
  galyleo_command=''

  # If at least one command-line argument was provided by the user, then
  # start parsing the command-line arguments. Otherwise, throw an error.
  if (( "${#}" > 0 )); then
 
    # Read in the first command-line argument, which is expected to be 
    # the main command issued by the user.
    galyleo_command="${1}"
    shift 1

    # Determine if the command provided by user is a valid. If it is a
    # valid command, then execute that command. Otherwise, throw an error.
    if [[ "${galyleo_command}" = 'launch' ]]; then

      galyleo_launch "${@}"
      if [[ "${?}" -ne 0 ]]; then
        slog error -m 'galyleo_launch command failed.'
        exit 1
      fi

    elif [[ "${galyleo_command}" = 'configure' ]]; then

      galyleo_configure "${@}"
      if [[ "${?}" -ne 0 ]]; then
        slog error -m 'galyleo_configure command failed.'
        exit 1
      fi

    elif [[ "${galyleo_command}" = 'clean' ]]; then
    
      galyleo_clean
      if [[ "${?}" -ne 0 ]]; then
        slog error -m 'galyleo_clean command failed.'
        exit 1
      fi

    elif [[ "${galyleo_command}" = 'help' || \
            "${galyleo_command}" = '-h' || \
            "${galyleo_command}" = '--help' ]]; then

      galyleo_help
      if [[ "${?}" -ne 0 ]]; then
        slog error -m 'galyleo_help command failed.'
        exit 1
      fi
    
    else
    
      slog error -m 'Command not recognized or not supported.'
      exit 1

    fi

  else

    slog error -m 'No command-line arguments were provided.'
    exit 1

  fi
  
  exit 0

}

# ----------------------------------------------------------------------

galyleo "${@}"

# ======================================================================
