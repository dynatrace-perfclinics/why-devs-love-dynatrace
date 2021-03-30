In order to deploy the configurations for the first episode do:

```
 monaco deploy -e environment.yaml --project episode1 -v
```
The environments.yaml file loads the dynatrace credentials into the shell, for doing so edit the file `set_dt_variables.sh` add the required variables and then load them to the sell like this:

```
source set_dt_variables.sh
```
You will need the latest monaco (Monitoring as Code) binary. Download it from here [https://github.com/dynatrace-oss/dynatrace-monitoring-as-code](https://github.com/dynatrace-oss/dynatrace-monitoring-as-code)
