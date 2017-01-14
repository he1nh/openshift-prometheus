# Monitoring OpenShift with Prometheus

This repo contains the files for the presentation of monitoring OpenShift with Prometheus.
To be given at 2016/01/19 at the OpenShift meetup.

Versions used:

| software        | version                  |
|-----------------|--------------------------|
|Prometheus       | v1.4.1                   |
|OpenShift        | OpenShift Origin v1.3    |


# Deploying Prometheus within OpenShift Origin

```code
oc cluster up
oc new-project monitoring
```

create prometheus *pod,deploymentconfig* and *service* based on the dockerhub prometheus image:

```code
oc run prometheus --image=prom/prometheus:v1.4.1 --port=9090 --expose -l app=prometheus
```

The prometheus binary in above pod will fail to start because it is assuming root rights.. Allow all pods within the monitoring project
to be started as root. By adding the default user to the anyuid security context constraint. And bring it into effect by redeploying the pod.

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

Browse the URL in above route definition.

