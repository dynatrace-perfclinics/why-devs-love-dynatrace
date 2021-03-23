#!/bin/bash
## Commands for Ubuntu Server 20.04 LTS (HVM), SSD Volume Type - ami-06d51e91cea0dac8d
## These script will install the following components:
# - OneAgent
# - Docker
# - BankJobs shinojosa/bankjob:v0.2 from DockerHub
# - Chromium for the Load generation of the EasyTravel Angular Shop
# - EasyTravel, Legacy 8080,8079 / Angular 9080 and 80 / WebLauncher 8094 / EasyTravel REST 8091 1697

## Set TENANT and API TOKEN
# ---- Define Dynatrace Environment ----
# Sample: https://{your-domain}/e/{your-environment-id} for managed or https://{your-environment-id}.live.dynatrace.com for SaaS
TENANT=
PAASTOKEN=
APITOKEN=

# ==================================================
#      ----- Variables Definitions -----           #
# ==================================================
LOGFILE='/tmp/install-easytravel.log'
touch $LOGFILE
chmod 775 $LOGFILE
pipe_log=true

USER="ubuntu"

# ---- Workshop User  ----
# The flag 'create_workshop_user'=true is per default set to false. If it's set to to it'll clone the home directory from USER and allow SSH login with the given text password )
create_workshop_user=false
NEWUSER="dynatrace"
NEWPWD="secr3t"

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
  if [ -n "${TENANT}" ]; then
    printInfo "Shuffle the variables for name convention with Dynatrace"
    PROTOCOL="https://"
    DT_TENANT=${TENANT#"$PROTOCOL"}
    printInfo "Cleaned tenant=$DT_TENANT"
    DT_API_TOKEN=$APITOKEN
    DT_PAAS_TOKEN=$PAASTOKEN
    printInfo "-------------------------------"
    printInfo "Dynatrace Tenant: $DT_TENANT"
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
  if [ -n "${TENANT}" ]; then
    printInfoSection "Installation of OneAgent"
    wget -nv -O oneagent.sh "$TENANT/api/v1/deployment/installer/agent/unix/default/latest?Api-Token=$PAASTOKEN&arch=x86&flavor=default"
    sh oneagent.sh APP_LOG_CONTENT_ACCESS=1 INFRA_ONLY=0
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
  echo "upstream angular {
    server   172.17.0.1:9080;
}
upstream admin {
    server   172.17.0.1:8094;
}
upstream classic {
    server   172.17.0.1:8079;
}

server {
    listen		0.0.0.0:80;
    server_name	localhost;

    location / {
      proxy_pass	http://angular/;
      proxy_pass_request_headers  on;
    }
    location /classic/ {
      proxy_pass	http://classic/;
      proxy_pass_request_headers  on;
    }
    location /amp/ {
      proxy_pass	http://classic/amp/;
      proxy_pass_request_headers  on;
    }
      location /admin/ {
      proxy_pass	http://admin/;
      proxy_pass_request_headers  on;
    }
}" >/home/$USER/nginx/easytravel-proxy.conf
  docker run -p 80:80 -v /home/$USER/nginx:/etc/nginx/conf.d/:ro -d --name reverseproxy nginx:1.15
}

installEasyTravel() {
  printInfoSection "Download, install and configure EasyTravel"
  cd /home/$USER
  wget -nv -O dynatrace-easytravel-linux-x86_64.jar http://dexya6d9gs5s.cloudfront.net/latest/dynatrace-easytravel-linux-x86_64.jar
  java -jar dynatrace-easytravel-linux-x86_64.jar -y
  chmod 755 -R easytravel-2.0.0-x64
  chown $USER:$USER -R easytravel-2.0.0-x64
  printInfo "Configuring EasyTravel Memory Settings, Angular Shop and Weblauncher."
  # Configuring EasyTravel Memory Settings, Angular Shop and Weblauncher.
  sed -i 's/apmServerDefault=Classic/apmServerDefault=APM/g' /home/$USER/easytravel-2.0.0-x64/resources/easyTravelConfig.properties
  sed -i 's/config.frontendJavaopts=-Xmx160m/config.frontendJavaopts=-Xmx320m/g' /home/$USER/easytravel-2.0.0-x64/resources/easyTravelConfig.properties
  sed -i 's/config.backendJavaopts=-Xmx64m/config.backendJavaopts=-Xmx320m/g' /home/$USER/easytravel-2.0.0-x64/resources/easyTravelConfig.properties
  sed -i 's/config.autostart=/config.autostart=Standard with REST Service and Angular2 frontend/g' /home/$USER/easytravel-2.0.0-x64/resources/easyTravelConfig.properties
  sed -i 's/config.autostartGroup=/config.autostartGroup=UEM/g' /home/$USER/easytravel-2.0.0-x64/resources/easyTravelConfig.properties
  sed -i 's/config.baseLoadB2BRatio=0.1/config.baseLoadB2BRatio=0/g' /home/$USER/easytravel-2.0.0-x64/resources/easyTravelConfig.properties
  sed -i 's/config.baseLoadCustomerRatio=0.25/config.baseLoadCustomerRatio=0.1/g' /home/$USER/easytravel-2.0.0-x64/resources/easyTravelConfig.properties
  sed -i 's/config.baseLoadMobileNativeRatio=0.1/config.baseLoadMobileNativeRatio=0/g' /home/$USER/easytravel-2.0.0-x64/resources/easyTravelConfig.properties
  sed -i 's/config.baseLoadMobileBrowserRatio=0.25/config.baseLoadMobileBrowserRatio=0/g' /home/$USER/easytravel-2.0.0-x64/resources/easyTravelConfig.properties
  sed -i 's/config.baseLoadHotDealServiceRatio=0.25/config.baseLoadHotDealServiceRatio=1/g' /home/$USER/easytravel-2.0.0-x64/resources/easyTravelConfig.properties
  sed -i 's/config.baseLoadIotDevicesRatio=0.1/config.baseLoadIotDevicesRatio=0/g' /home/$USER/easytravel-2.0.0-x64/resources/easyTravelConfig.properties
  sed -i 's/config.baseLoadHeadlessAngularRatio=0.0/config.baseLoadHeadlessAngularRatio=0.25/g' /home/$USER/easytravel-2.0.0-x64/resources/easyTravelConfig.properties
  sed -i 's/config.baseLoadHeadlessMobileAngularRatio=0.0/config.baseLoadHeadlessMobileAngularRatio=0.1/g' /home/$USER/easytravel-2.0.0-x64/resources/easyTravelConfig.properties
  sed -i 's/config.maximumChromeDrivers=10/config.maximumChromeDrivers=1/g' /home/$USER/easytravel-2.0.0-x64/resources/easyTravelConfig.properties
  sed -i 's/config.maximumChromeDriversMobile=10/config.maximumChromeDriversMobile=1/g' /home/$USER/easytravel-2.0.0-x64/resources/easyTravelConfig.properties
  sed -i 's/config.reUseChromeDriverFrequency=4/config.reUseChromeDriverFrequency=1/g' /home/$USER/easytravel-2.0.0-x64/resources/easyTravelConfig.properties
  #sed -i 's/config.angularFrontendPortRangeStart=9080/config.angularFrontendPortRangeStart=80/g' /easytravel-2.0.0-x64/resources/easyTravelConfig.properties

  # Fix finding the Java package
  sed -i "s/JAVA_BIN=..\\/jre\\/bin\\/java/JAVA_BIN=\\/usr\\/bin\\/java/g" /home/$USER/easytravel-2.0.0-x64/weblauncher/weblauncher.sh

  su -c "sh /home/$USER/easytravel-2.0.0-x64/weblauncher/weblauncher.sh > /tmp/weblauncher.log 2>&1 &" $USER

  [[ -f /tmp/weblauncher.log ]] && echo "***EasyTravel launched**" || echo "***Problem launching EasyTravel **"
  date
  echo "installation done"

}

printInstalltime() {
  DURATION=$SECONDS
  printInfoSection "Installation complete :)"
  printInfo "It took $(($DURATION / 60)) minutes and $(($DURATION % 60)) seconds"
}

restartAll() {
  killall java
  docker start reverseproxy bankjob
  USER=ubuntu
  su -c "sh /home/$USER/easytravel-2.0.0-x64/weblauncher/weblauncher.sh > /tmp/weblauncher.log 2>&1 &" $USER

}

doInstallation() {
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

# ==================================================
#  ----- Call the Installation Function -----      #
# ==================================================
doInstallation
