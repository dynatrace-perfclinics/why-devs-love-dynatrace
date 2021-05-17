#!/bin/bash
# Simple script for setting the Dynatrace credentials as environment variables

## Set TENANT and API TOKEN
# ---- Define Dynatrace Environment ----
# Sample: https://{your-domain}/e/{your-environment-id} for managed or https://{your-environment-id}.live.dynatrace.com for SaaS
DT_TENANT_URL=
# https://www.dynatrace.com/support/help/shortlink/token#create-an-api-token-
# Token in format dt0c01.STXXXX....
DT_API_TOKEN=

# DT_USER (Your login username in the environment, Click on the top right on the people icon and see your id, it can be your email or a username)
DT_USER=

# Magic IP for easytravel. Example if public ip == 1.2.3.4 then Magic IP => 1-2-3-4.nip.io 
DT_EASYTRAVEL_MIP=

# Magic IP for KIAB (Keptn in a Box). Example if public ip == 1.2.3.4 then Magic IP => 1-2-3-4.nip.io 
DT_KIAB_MIP=

echo "usage 'source set_dt_variables.sh'"

# FUNCTIONS DECLARATIONS
timestamp() {
  date +"[%Y-%m-%d %H:%M:%S]"
}

printInfo() {
    echo "[INFO] $(timestamp) |>->-> $1 <-<-<|"
}

printError() {
    echo "[ERROR] $(timestamp) |>->-> $1 <-<-<|"
}

printInfoSection() {
    echo "[INFO] $(timestamp) |$thickline"
    echo "[INFO] $(timestamp) |$halfline $1 $halfline"
    echo "[INFO] $(timestamp) |$thinline"
}

dynatracePrintValidateCredentials() {
    printInfoSection "Printing Dynatrace Credentials"
    if [ -n "${DT_TENANT_URL}"  ] &&  [ -n "${DT_API_TOKEN}"  ] &&  [ -n "${DT_USER}"  ] ; then
        printInfo "-------------------------------"
        printInfo "Dynatrace Tenant: $DT_TENANT_URL"
        printInfo "Dynatrace API Token: $DT_API_TOKEN"
        printInfo "Dynatrace User: $DT_USER"
    else
        printError "Dynatrace Variables not set, check your variables"
        printError "Dynatrace Tenant: $DT_TENANT_URL"
        printError "Dynatrace API Token: $DT_API_TOKEN"
        printError "Dynatrace User: $DT_USER"
    fi
}

exportVariables() {
    export DT_TENANT_URL
    export DT_API_TOKEN
    export DT_USER
    export DT_EASYTRAVEL_MIP
    export DT_KIAB_MIP
}

setMonacoNewCli(){
    printInfo "Setting monaco new CLI 'NEW_CLI=1'"
    export NEW_CLI=1
}

dynatracePrintValidateCredentials
exportVariables
setMonacoNewCli