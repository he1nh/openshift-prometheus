# Monitoring OpenShift with Prometheus

This repo contains the files for the presentation of monitoring OpenShift with Prometheus.
To be given at 2016/01/19 at the OpenShift meetup.

| software        | version                  |
|-----------------|--------------------------|
|Prometheus       | v1.4.1                   |
|OpenShift        | OpenShift Origin v1.3    |


## Deploying Prometheus within OpenShift Origin

```code
oc cluster up
oc new-project monitoring
```

create prometheus *pod,deploymentconfig* and *service* based on the dockerhub prometheus image:

```code
oc run prometheus --image=prom/prometheus:v1.4.1 --port=9090 --expose -l app=prometheus
```

The prometheus server will fail to start because it is assuming it is running under the root account.
To allow all pods within the monitoring project to be run under any user account (including root) perform below command.
Which will add the default user to the anyuid security context constraint.

```code
oc login -u system:admin
oc adm policy add-scc-to-user anyuid -z default -n monitoring
```
```code
oc deploy prometheus --latest --follow
oc get pods
``` 

Lets acces Prometheus

```code
oc expose svc prometheus
oc get routes
```
Navigate to above URL and browse trough the different targets in the *status* pulldown menu.

![Prometheus Screenshot](/images/prometheus-screenshot-1.png)

## Modify the default prometheus config `/etc/prometheus/prometheus.yml`

```code
oc ceate configmap prometheus-config --from-file config/prometheus-kubernetes.yml
```
