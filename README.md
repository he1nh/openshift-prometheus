# Monitoring OpenShift with Prometheus

This repo contains files for deploying Prometheus on OpenShift.

| software        | version                  |
|-----------------|--------------------------|
|Prometheus       | v1.4.1                   |
|OpenShift        | OpenShift Origin v1.3    |


## Bringing up the cluster and create a new project

```code
oc cluster up
oc new-project monitoring
```

## Starting a Pod *by hand*

create the Prometheus *pod,deploymentconfig* and *service* based on the dockerhub prometheus image:

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

## Modify the default prometheus config

```code
oc ceate configmap prometheus-config --from-file config/prometheus-kubernetes.yml
```

Add the configmap to the *deploymentconfig* or replace the current *deploymentconfig* with one wich has the *configmap* already included:

```code
oc replace -f infra/dc.prometheus.yml
```

Though the new pod will be running, not everything is as it should be. Have a look at the Prometheus server logging.

```code
oc logs $(oc get pods -o name -l app=prometheus)
```

The kubernetes service discovery tries to query the API server but does not have the rights.

```code
oc login -u system:admin
oc project monitoring
oc adm policy add-cluster-role-to-user cluster-reader system:serviceaccount:$(oc project -q):default
```

```code
oc logs -f $(oc get pods -o name -l app=prometheus)
```

Navigate to the prometheus url and view the status of the *targets*.

## Add an HAProxy metrics exporter

In below steps we will add a pod which will convert the *HAProxy* metrics which are in *csv* format, to a Prometheus scrape target. And add the target to the prometheus config file.

```code
oc create -f infra dc.haproxy-exporter.yml
```

Grab the HAProxy user:password from within the router pod

```code
oc exec -n default $(oc get pods -l deploymentconfig=router -o name -n default|cut -d/ -f2) grep auth /var/lib/haproxy/conf/haproxy.config
```
q
