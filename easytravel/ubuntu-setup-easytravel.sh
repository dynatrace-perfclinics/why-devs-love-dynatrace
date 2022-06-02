#!/bin/bash
## Commands for Ubuntu Server 20.04 LTS (HVM), SSD Volume Type - ami-06d51e91cea0dac8d
## These script will install the following components:
# - OneAgent
# - Docker
# - BankJobs shinojosa/bankjob:v0.2 from DockerHub
# - Chromium for the Load generation of the EasyTravel Angular Shop
# - EasyTravel, Legacy 8080,8079 / Angular 9080 and 80 / WebLauncher 8094 / EasyTravel REST 8091 1697

## Set DT_TENANT_URL and API TOKEN
# ---- Define Dynatrace Environment ----
# Sample: https://{your-domain}/e/{your-environment-id} for managed or https://{your-environment-id}.live.dynatrace.com for SaaS
DT_TENANT_URL=
DT_PAAS_TOKEN=

# Not used on this script ATM. Used before for installing the ActigeGate automatically
DT_API_TOKEN=

# For 3rd party server (images, cdn...). by default it takes the public IP
DOMAIN=
# ==================================================
#      ----- Variables Definitions -----           #
# ==================================================
LOGFILE='/tmp/install-easytravel.log'
touch $LOGFILE
chmod 775 $LOGFILE
pipe_log=true

USER="ubuntu"

programname=$0

# ---- Workshop User  ----
# The flag 'create_workshop_user'=true is per default set to false. If it's set to to it'll clone the home directory from USER and allow SSH login with the given text password )
create_workshop_user=false
NEWUSER="dynatrace"
NEWPWD="secr3t"

pipeLog() {
  ## ----  Write all output to the logfile ----
  if [ "$pipe_log" = true ]; then
    echo "Piping all output to logfile $LOGFILE"
    echo "Type 'less +F $LOGFILE' for viewing the output of installation on realtime"
    echo "If you did not send the job to the background, type \"CTRL + Z\" and \"bg\""
    echo "CTRL + Z (for pausing this job)"
    echo "then"
    echo "bg (for resuming back this job and send it to the background)"
    # Saves file descriptors so they can be restored to whatever they were before redirection or used
    # themselves to output to whatever they were before the following redirect.
    exec 3>&1 4>&2
    # Restore file descriptors for particular signals. Not generally necessary since they should be restored when the sub-shell exits.
    trap 'exec 2>&4 1>&3' 0 1 2 3
    # Redirect stdout to file log.out then redirect stderr to stdout. Note that the order is important when you
    # want them going to the same file. stdout must be redirected before stderr is redirected to stdout.
    exec 1>$LOGFILE 2>&1
  else
    echo "Not piping stdout stderr to the logfile, writing the installation to the console"
  fi
}

# Comfortable function for setting the sudo user.
if [ -n "${SUDO_USER}" ]; then
  USER=$SUDO_USER
fi
echo "running sudo commands as $USER"

# ======================================================================
#          ------- Util Functions -------                              #
#  A set of util functions for logging, validating and                 #
#  executing commands.                                                 #
# ======================================================================
thickline="======================================================================"
halfline="============"
thinline="______________________________________________________________________"

setBashas() {
  # Wrapper for runnig commands for the real owner and not as root
  alias bashas="sudo -H -u ${USER} bash -c"
  # Expand aliases for non-interactive shell
  shopt -s expand_aliases
}

# FUNCTIONS DECLARATIONS
timestamp() {
  date +"[%Y-%m-%d %H:%M:%S]"
}

printInfo() {
  echo "[EasyTravel-Installation|INFO] $(timestamp) |>->-> $1 <-<-<|"
}

printInfoSection() {
  echo "[EasyTravel-Installation|INFO] $(timestamp) |$thickline"
  echo "[EasyTravel-Installation|INFO] $(timestamp) |$halfline $1 $halfline"
  echo "[EasyTravel-Installation|INFO] $(timestamp) |$thinline"
}

printError() {
  echo "[EasyTravel-Installation|ERROR] $(timestamp) |x-x-> $1 <-x-x|"
}

validateSudo() {
  if [[ $EUID -ne 0 ]]; then
    printError "EasyTravel-Installation must be run with sudo rights. Exiting installation"
    exit 1
  fi
  printInfo "EasyTravel-Installation installing with sudo rights:ok"
}

dynatracePrintValidateCredentials() {
  printInfoSection "Printing Dynatrace Credentials"
  if [ -n "${DT_TENANT_URL}" ]; then
    printInfo "-------------------------------"
    printInfo "Dynatrace Tenant: $DT_TENANT_URL"
    printInfo "Dynatrace API Token: $DT_API_TOKEN"
    printInfo "Dynatrace PaaS Token: $DT_PAAS_TOKEN"
  else
    printInfoSection "Dynatrace Variables not set, Dynatrace wont be installed"
  fi
}

utilsInstall() {
  printInfoSection "Updating Ubuntu apt registry"
  apt update
  printInfoSection "Installing Docker, Chromium, J Query"
  printInfo "Install J Query"
  apt install jq -y
  printInfo "Install Docker"
  apt install docker.io -y
  printInfo "Setting default logging for Docker to avoid disk issues"
  echo '{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
    }
  }' > /etc/docker/daemon.json
  service docker start
  usermod -a -G docker $USER
  printInfo "Installation of Libraries for the Angular Loadtest to work on the system "
  apt-get -y install libasound2 libatk-bridge2.0-0 libatk1.0-0 libc6:amd64 libcairo2 libcups2 libgdk-pixbuf2.0-0 libgtk-3-0 libnspr4 libnss3 libxss1 xdg-utils libminizip-dev libgbm-dev libflac8

  printInfo "Installation of lates Java  "
  apt install -y default-jdk
}

setupProAliases() {
  printInfoSection "Adding Bash and Kubectl Pro CLI aliases to .bash_aliases for user ubuntu and root "
  echo "
      # Alias for ease of use of the CLI
      alias las='ls -las' 
      alias hg='history | grep' 
      alias h='history' 
      alias vaml='vi -c \"set syntax:yaml\" -' 
      alias vson='vi -c \"set syntax:json\" -' 
      alias pg='ps -aux | grep' " >/root/.bash_aliases
  homedir=$(eval echo ~$USER)
  cp /root/.bash_aliases $homedir/.bash_aliases
}

installDynatrace() {
  if [ -n "${DT_TENANT_URL}" ]; then
    printInfoSection "Installation of OneAgent"
    wget -nv -O oneagent.sh "$DT_TENANT_URL/api/v1/deployment/installer/agent/unix/default/latest?Api-Token=$DT_PAAS_TOKEN&arch=x86&flavor=default"
    sh oneagent.sh --set-app-log-content-access=true --set-system-logs-access-enabled=true --set-infra-only=false --set-host-name=easytravel.staging
  fi
}

createWorkshopUser() {
  if [ "$create_workshop_user" = true ]; then
    printInfoSection "Creating Workshop User from user($USER) into($NEWUSER)"
    homedirectory=$(eval echo ~$USER)
    cp -R $homedirectory /home/$NEWUSER
    useradd -s /bin/bash -d /home/$NEWUSER -m -G sudo -p $(openssl passwd -1 $NEWPWD) $NEWUSER
    usermod -a -G docker $NEWUSER
    usermod -a -G microk8s $NEWUSER
    printInfo "Warning: allowing SSH passwordAuthentication into the sshd_config"
    sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/g' /etc/ssh/sshd_config
    service sshd restart
  fi
}

installBankjobs() {
  printInfoSection "Pulling Bankjobs and running them"
  docker run -d --name bankjob shinojosa/bankjob:perform2021

}

installReverseProxy() {
  printInfoSection "Configuring reverse proxy"
  mkdir /home/$USER/nginx
  #
  echo 'upstream angular {
    server   172.17.0.1:9080;
}

upstream admin {
    server   172.17.0.1:8094;
}
upstream classic {
    server   172.17.0.1:8079;
}
upstream rest {
    server   172.17.0.1:8091;
}
upstream 3rdparty {
    server   172.17.0.1:8092;
}

server {
    listen		0.0.0.0:80;
    # By default we show EasyTravel Angular
    server_name	localhost;
    
    location / {
      proxy_pass	http://angular/;
      proxy_pass_request_headers  on;
      proxy_set_header   Host $host;
    }
}

server {
        listen 80;
        listen [::]:80;
        server_name classic.*;

        location / {
          proxy_pass	http://classic/;
          proxy_pass_request_headers  on;
          proxy_set_header   Host $host;
        }
}

server {
        listen 80;
        listen [::]:80;
        server_name admin.*;
        location / {
          proxy_pass	http://admin/;
          proxy_pass_request_headers  on;
          proxy_set_header   Host $host;
        }
}

server {
        listen 80;
        listen [::]:80;
        server_name rest.*;
        location / {
          proxy_pass	http://rest/;
          proxy_pass_request_headers  on;
          proxy_set_header   Host $host;
        }
}

server {
        listen 80;
        listen [::]:80;
        # By default we show EasyTravel Angular
        server_name amp.*;
        location / {
          proxy_pass	http://classic/amp/;
          proxy_pass_request_headers  on;
          proxy_set_header   Host $host;
        }
}

server {
        listen 80;
        listen [::]:80;
        server_name cdn.*;
        server_name social.*;
        server_name 3rdparty.*;
        location / {
          proxy_pass	http://3rdparty/;
          proxy_pass_request_headers  on;
          proxy_set_header   Host $host;
        }
}' >/home/$USER/nginx/easytravel-proxy.conf
  docker run -p 80:80 -v /home/$USER/nginx:/etc/nginx/conf.d/:ro -d --name reverseproxy nginx:1.18
}

removeEasyTravel() {
  printInfoSection "Remove EasyTravel"
  rm -rf easytravel-2.0.0-x64
}

setupMagicDomainPublicIp() {
  printInfoSection "Setting up the Domain"
  if [ -n "${DOMAIN}" ]; then
    printInfo "The following domain is defined: $DOMAIN"
    export DOMAIN
  else
    printInfo "No DOMAIN is defined, converting the public IP in a magic nip.io domain"
    PUBLIC_IP=$(curl -s ifconfig.me)
    PUBLIC_IP_AS_DOM=$(echo $PUBLIC_IP | sed 's~\.~-~g')
    export DOMAIN="${PUBLIC_IP_AS_DOM}.nip.io"
    printInfo "Magic Domain: $DOMAIN"
  fi
}

installEasyTravel() {
  printInfoSection "Download, install and configure EasyTravel"
  cd /home/$USER
  wget -nv -O dynatrace-easytravel-linux-x86_64.jar https://etinstallers.demoability.dynatracelabs.com/latest/dynatrace-easytravel-linux-x86_64.jar
  java -jar dynatrace-easytravel-linux-x86_64.jar -y
  rm dynatrace-easytravel-linux-x86_64.jar
  chmod 755 -R easytravel-2.0.0-x64
  chown $USER:$USER -R easytravel-2.0.0-x64
  printInfo "Configuring EasyTravel Memory Settings, Angular Shop and Weblauncher."
  # Config File
  ETCONFIG=/home/$USER/easytravel-2.0.0-x64/resources/easyTravelConfig.properties
  printInfo "This is the configuration file: $ETCONFIG"
  
  setupMagicDomainPublicIp
  printInfo "This is the DOMAIN: $DOMAIN"

  # Configuring EasyTravel Memory Settings, Angular Shop and Weblauncher.
  #sed -i 's,<configurationId>=.*,<configurationId>=value,g' $ETCONFIG
  sed -i 's,apmServerDefault=.*,apmServerDefault=APM,g' $ETCONFIG
  sed -i 's,config.frontendJavaopts=.*,config.frontendJavaopts=-Xmx320m,g' $ETCONFIG
  sed -i 's,config.backendJavaopts=.*,config.backendJavaopts=-Xmx320m,g' $ETCONFIG
  sed -i 's,config.autostart=.*,config.autostart=Standard with REST Service and Angular2 frontend,g' $ETCONFIG
  sed -i 's,config.autostartGroup=.*,config.autostartGroup=UEM,g' $ETCONFIG
  sed -i 's,config.baseLoadB2BRatio=.*,config.baseLoadB2BRatio=0,g' $ETCONFIG
  sed -i 's,config.baseLoadCustomerRatio=.*,config.baseLoadCustomerRatio=0.1,g' $ETCONFIG
  sed -i 's,config.baseLoadMobileNativeRatio=.*,config.baseLoadMobileNativeRatio=0,g' $ETCONFIG
  sed -i 's,config.baseLoadMobileBrowserRatio=.*,config.baseLoadMobileBrowserRatio=0,g' $ETCONFIG
  sed -i 's,config.baseLoadHotDealServiceRatio=.*,config.baseLoadHotDealServiceRatio=1,g' $ETCONFIG
  sed -i 's,config.baseLoadIotDevicesRatio=.*,config.baseLoadIotDevicesRatio=0,g' $ETCONFIG
  sed -i 's,config.baseLoadHeadlessAngularRatio=.*,config.baseLoadHeadlessAngularRatio=0.1,g' $ETCONFIG
  sed -i 's,config.baseLoadHeadlessMobileAngularRatio=.*,config.baseLoadHeadlessMobileAngularRatio=0.1,g' $ETCONFIG
  sed -i 's,config.maximumChromeDrivers=.*,config.maximumChromeDrivers=1,g' $ETCONFIG
  sed -i 's,config.maximumChromeDriversMobile=.*,config.maximumChromeDriversMobile=1,g' $ETCONFIG
  sed -i 's,config.reUseChromeDriverFrequency=.*,config.reUseChromeDriverFrequency=1,g' $ETCONFIG
  
  # Setting up 3rd party Domain
  sed -i 's,config.thirdpartyUrl=.*,config.thirdpartyUrl=http://3rdparty.'"$DOMAIN"',g' $ETCONFIG
  sed -i 's,config.thirdpartyCdnUrl=.*,config.thirdpartyCdnUrl=http://cdn.'"$DOMAIN"',g' $ETCONFIG
  sed -i 's,config.thirdpartySocialMediaUrl=.*,config.thirdpartySocialMediaUrl=http://social.'"$DOMAIN"',g' $ETCONFIG
  
  startAll
  date
  echo "installation done"
}

printInstalltime() {
  DURATION=$SECONDS
  printInfoSection "Installation complete :)"
  printInfo "It took $(($DURATION / 60)) minutes and $(($DURATION % 60)) seconds"
}

startAll() {
  printInfoSection "Start EasyTravel and docker Containers"
  docker start reverseproxy bankjob
  sed -i "s/JAVA_BIN=..\\/jre\\/bin\\/java/JAVA_BIN=\\/usr\\/bin\\/java/g" /home/$USER/easytravel-2.0.0-x64/weblauncher/weblauncher.sh
  su -c "sh /home/$USER/easytravel-2.0.0-x64/weblauncher/weblauncher.sh > /tmp/weblauncher.log 2>&1 &" $USER
  [[ -f /tmp/weblauncher.log ]] && echo "***EasyTravel launched**" || echo "***Problem launching EasyTravel **"
}

doInstallation() {
  pipeLog
  SECONDS=0
  echo ""
  printInfoSection "Init Installation at $(date) by user $(whoami)"
  printInfo "Setting up and configuring EasyTravel"
  echo ""
  validateSudo
  setBashas

  # Installation Modules
  dynatracePrintValidateCredentials
  utilsInstall
  installDynatrace
  installBankjobs
  installReverseProxy
  installEasyTravel
  createWorkshopUser
  printInstalltime
}

killEasyTravel() {
  printInfoSection "Kill all EasyTravel Processes"
  killall java
  ps -ef | grep -i easytravel | awk '{print "sudo kill -9 "$2}' | sh
  printInfo "done killing all EasyTravel Processes"
}

upgradeEasyTravel() {
  printInfoSection "Upgrade EasyTravel"
  removeEasyTravel
  installEasyTravel
}

printUsage() {
  printInfoSection "usage: $programname [-ukswhi] "
  printInfo "  -u      upgrade EasyTravel"
  printInfo "  -k      kill all processes EasyTravel"
  printInfo "  -s      start EasyTravel and Docker Containers"
  printInfo "  -w      create workshop user"
  printInfo "  -h      print this help"
  printInfo "  -i      install EasyTravel and OneAgent in interactive mode (no pipelog)"
  printInfo "          no parameters install EasyTravel and OneAgent"
}

while getopts ":ukswhi" opt; do
  case $opt in
  u)
    upgradeEasyTravel
    exit 0
    ;;
  k)
    killEasyTravel
    exit 0
    ;;
  s)
    startAll
    exit 0
    ;;
  i)
    pipe_log=false
    doInstallation
    exit 0
    ;;
  w)
    create_workshop_user=true
    createWorkshopUser
    exit 0
    ;;
  h)
    printUsage
    exit 0
    ;;
  \?)
    echo "Invalid option: -$OPTARG" >&2
    printUsage
    echo "exiting..."
    exit 1
    ;;
  esac
done

# =================================================
#  ----- Call the Installation Function -----      #
# ==================================================
printUsage
doInstallation
