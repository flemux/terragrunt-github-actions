#!/bin/bash

function stripColors {
  echo "${1}" | sed 's/\x1b\[[0-9;]*m//g'
}

function hasPrefix {
  case ${2} in
    "${1}"*)
      true
      ;;
    *)
      false
      ;;
  esac
}

function parseInputs {
  # Required inputs
  if [ "${INPUT_TF_ACTIONS_VERSION}" != "" ]; then
    tfVersion=${INPUT_TF_ACTIONS_VERSION}
  else
    echo "Input terraform_version cannot be empty"
    exit 1
  fi

  if [ "${INPUT_TG_ACTIONS_VERSION}" != "" ]; then
    tgVersion=${INPUT_TG_ACTIONS_VERSION}
  else
    echo "Input terragrunt_version cannot be empty"
    exit 1
  fi

  if [ "${INPUT_TF_ACTIONS_SUBCOMMAND}" != "" ]; then
    tfSubcommand=${INPUT_TF_ACTIONS_SUBCOMMAND}
  else
    echo "Input terraform_subcommand cannot be empty"
    exit 1
  fi

  # Optional inputs
  tfWorkingDir="."
  if [[ -n "${INPUT_TF_ACTIONS_WORKING_DIR}" ]]; then
    tfWorkingDir=${INPUT_TF_ACTIONS_WORKING_DIR}
  fi

  tfBinary="terragrunt"
  if [[ -n "${INPUT_TF_ACTIONS_BINARY}" ]]; then
    tfBinary=${INPUT_TF_ACTIONS_BINARY}
  fi

  tfComment=0
  if [ "${INPUT_TF_ACTIONS_COMMENT}" == "1" ] || [ "${INPUT_TF_ACTIONS_COMMENT}" == "true" ]; then
    tfComment=1
  fi

  tfCLICredentialsHostname=""
  if [ "${INPUT_TF_ACTIONS_CLI_CREDENTIALS_HOSTNAME}" != "" ]; then
    tfCLICredentialsHostname=${INPUT_TF_ACTIONS_CLI_CREDENTIALS_HOSTNAME}
  fi

  tfCLICredentialsToken=""
  if [ "${INPUT_TF_ACTIONS_CLI_CREDENTIALS_TOKEN}" != "" ]; then
    tfCLICredentialsToken=${INPUT_TF_ACTIONS_CLI_CREDENTIALS_TOKEN}
  fi

  sshPrivateKey=""
  if [ "${INPUT_SSH_PRIVATE_KEY}" != "" ]; then
    sshPrivateKey=${INPUT_SSH_PRIVATE_KEY}
  fi

  knownHosts=""
  if [ "${INPUT_KNOWN_HOSTS}" != "" ]; then
    knownHosts=${INPUT_KNOWN_HOSTS}
  fi

  tfFmtWrite=0
  if [ "${INPUT_TF_ACTIONS_FMT_WRITE}" == "1" ] || [ "${INPUT_TF_ACTIONS_FMT_WRITE}" == "true" ]; then
    tfFmtWrite=1
  fi

  tfWorkspace="default"
  if [ -n "${TF_WORKSPACE}" ]; then
    tfWorkspace="${TF_WORKSPACE}"
  fi
}

function configureCLICredentials {
  if [[ ! -f "${HOME}/.terraformrc" ]] && [[ "${tfCLICredentialsToken}" != "" ]]; then
    cat > ${HOME}/.terraformrc << EOF
credentials "${tfCLICredentialsHostname}" {
  token = "${tfCLICredentialsToken}"
}
EOF
  fi
}

function installTerraform {
  if [[ "${tfVersion}" == "latest" ]]; then
    echo "Checking the latest version of Terraform"
    tfVersion=$(curl -sL https://releases.hashicorp.com/terraform/index.json | jq -r '.versions[].version' | grep -v '[-].*' | sort -rV | head -n 1)

    if [[ -z "${tfVersion}" ]]; then
      echo "Failed to fetch the latest version"
      exit 1
    fi
  fi

  url="https://releases.hashicorp.com/terraform/${tfVersion}/terraform_${tfVersion}_linux_amd64.zip"

  echo "Downloading Terraform v${tfVersion}"
  curl -s -S -L -o /tmp/terraform_${tfVersion} ${url}
  if [ "${?}" -ne 0 ]; then
    echo "Failed to download Terraform v${tfVersion}"
    exit 1
  fi
  echo "Successfully downloaded Terraform v${tfVersion}"

  echo "Unzipping Terraform v${tfVersion}"
  unzip -d /usr/local/bin /tmp/terraform_${tfVersion} &> /dev/null
  if [ "${?}" -ne 0 ]; then
    echo "Failed to unzip Terraform v${tfVersion}"
    exit 1
  fi
  echo "Successfully unzipped Terraform v${tfVersion}"
}

function setupSSHAgent {
   if [[ "${sshPrivateKey}" != "" ]]; then
    echo "Setting up SSH agent"
    echo "${sshPrivateKey}" > /ssh/id_rsa
#    echo "\ngithub.com ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEAq2A7hRGmdnm9tUDbO9IDSwBK6TbQa+PXYPCPy6rbTrTtw7PHkccKrpp0yVhp5HdEIcKr6pLlVDBfOLX9QUsyCOV0wzfjIJNlGEYsdlLJizHhbn2mUjvSAHQqZETYP81eFzLQNnPHt4EVVUh7VfDESU84KezmD5QlWpXLmvU31/yMf+Se8xhHTvKSCZIFImWwoG6mbUoWf9nzpIoaSjB+weqqUUmpaaasXVal72J+UX2B+2RPW3RcT0eOzQgqlJL3RKrTJvdsjE3JEAvGq3lGHSZXy28G3skua2SmVi/w4yCE6gbODqnTWlg7+wC604ydGXA8VJiS5ap43JXiUFFAaQ==\n" >> /ssh/known_hosts
#    echo "\ngithub.com ssh-dss AAAAB3NzaC1kc3MAAACBANGFW2P9xlGU3zWrymJgI/lKo//ZW2WfVtmbsUZJ5uyKArtlQOT2+WRhcg4979aFxgKdcsqAYW3/LS1T2km3jYW/vr4Uzn+dXWODVk5VlUiZ1HFOHf6s6ITcZvjvdbp6ZbpM+DuJT7Bw+h5Fx8Qt8I16oCZYmAPJRtu46o9C2zk1AAAAFQC4gdFGcSbp5Gr0Wd5Ay/jtcldMewAAAIATTgn4sY4Nem/FQE+XJlyUQptPWMem5fwOcWtSXiTKaaN0lkk2p2snz+EJvAGXGq9dTSWHyLJSM2W6ZdQDqWJ1k+cL8CARAqL+UMwF84CR0m3hj+wtVGD/J4G5kW2DBAf4/bqzP4469lT+dF2FRQ2L9JKXrCWcnhMtJUvua8dvnwAAAIB6C4nQfAA7x8oLta6tT+oCk2WQcydNsyugE8vLrHlogoWEicla6cWPk7oXSspbzUcfkjN3Qa6e74PhRkc7JdSdAlFzU3m7LMkXo1MHgkqNX8glxWNVqBSc0YRdbFdTkL0C6gtpklilhvuHQCdbgB3LBAikcRkDp+FCVkUgPC/7Rw==\n" >> /ssh/known_hosts
#    # echo "${knownHosts}" > /ssh/known_hosts
#    ssh-keyscan github.com >> /ssh/known_hosts

    chmod 600 /ssh/id_rsa
#    chmod 644 /ssh/known_hosts
    ssh -o StrictHostKeyChecking=no
    eval `ssh-agent` # create the process
    ssh-add /ssh/id_rsa # add the key
  fi
}

function installTerragrunt {
  if [[ "${tgVersion}" == "latest" ]]; then
    echo "Checking the latest version of Terragrunt"
    latestURL=$(curl -Ls -o /dev/null -w %{url_effective} https://github.com/gruntwork-io/terragrunt/releases/latest)
    tgVersion=${latestURL##*/}

    if [[ -z "${tgVersion}" ]]; then
      echo "Failed to fetch the latest version"
      exit 1
    fi
  fi

  url="https://github.com/gruntwork-io/terragrunt/releases/download/${tgVersion}/terragrunt_linux_amd64"

  echo "Downloading Terragrunt ${tgVersion}"
  curl -s -S -L -o /tmp/terragrunt ${url}
  if [ "${?}" -ne 0 ]; then
    echo "Failed to download Terragrunt ${tgVersion}"
    exit 1
  fi
  echo "Successfully downloaded Terragrunt ${tgVersion}"

  echo "Moving Terragrunt ${tgVersion} to PATH"
  chmod +x /tmp/terragrunt
  mv /tmp/terragrunt /usr/local/bin/terragrunt 
  if [ "${?}" -ne 0 ]; then
    echo "Failed to move Terragrunt ${tgVersion}"
    exit 1
  fi
  echo "Successfully moved Terragrunt ${tgVersion}"
}

function main {
  # Source the other files to gain access to their functions
  scriptDir=$(dirname ${0})
  source ${scriptDir}/terragrunt_fmt.sh
  source ${scriptDir}/terragrunt_init.sh
  source ${scriptDir}/terragrunt_validate.sh
  source ${scriptDir}/terragrunt_plan.sh
  source ${scriptDir}/terragrunt_apply.sh
  source ${scriptDir}/terragrunt_output.sh
  source ${scriptDir}/terragrunt_import.sh
  source ${scriptDir}/terragrunt_taint.sh
  source ${scriptDir}/terragrunt_destroy.sh

  parseInputs
  configureCLICredentials
  setupSSHAgent
  installTerraform
  cd ${GITHUB_WORKSPACE}/${tfWorkingDir}

  case "${tfSubcommand}" in
    fmt)
      installTerragrunt
      terragruntFmt ${*}
      ;;
    init)
      installTerragrunt
      terragruntInit ${*}
      ;;
    validate)
      installTerragrunt
      terragruntValidate ${*}
      ;;
    plan)
      installTerragrunt
      terragruntPlan ${*}
      ;;
    apply)
      installTerragrunt
      terragruntApply ${*}
      ;;
    output)
      installTerragrunt
      terragruntOutput ${*}
      ;;
    import)
      installTerragrunt
      terragruntImport ${*}
      ;;
    taint)
      installTerragrunt
      terragruntTaint ${*}
      ;;
    destroy)
      installTerragrunt
      terragruntDestroy ${*}
      ;;
    *)
      echo "Error: Must provide a valid value for terragrunt_subcommand"
      exit 1
      ;;
  esac
}

main "${*}"
