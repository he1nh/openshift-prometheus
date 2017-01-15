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

## Starting Prometheus  *by hand*

create the Prometheus *pod,deploymentconfig* and *service* based on the dockerhub prometheus image:

```code
oc run prometheus --image=prom/prometheus:v1.4.1 --port=9090 --expose -l app=prometheus
```

> The Prometheus server running in above pod will fail to start because it is assuming it is running under the root account.

Allow the server to be started up under any account (including root).
By adding the default project user to the anyuid security context constraint (scc).

```code
oc login -u system:admin
oc adm policy add-scc-to-user anyuid -z default -n monitoring
```

Redeploy Prometheus

```code
oc deploy prometheus --latest --follow
oc get pods
``` 

Expose the created service, so we can access it from outside the cluster

```code
oc expose svc prometheus
oc get routes
```

## Prometheus

Navigate to above URL.
And browse trough the different targets in the *status* pulldown menu.

![Prometheus Screenshot](/images/prometheus-screenshot-1.png)

## Cluster monitoring

To monitor the cluster with OpenShift we will be using the kubernetes serivce discovery feature in Prometheus.
Using the prometheus configuration from the Prometheus documentation.

creat a configmap holding the prometheus configuartion file

```code
oc ceate configmap prometheus-config --from-file config/prometheus-kubernetes.yml
```

Add the configmap to the *deploymentconfig* or replace the current *deploymentconfig* with one wich has the *configmap* already included:

```code
oc replace -f objects/dc.prometheus.yml
```

Though the new pod will be running, not everything is as it should be. Have a look at the Prometheus server logging.

```code
oc logs $(oc get pods -o name -l app=prometheus)
```

The kubernetes service discovery tries to query the API server but does not have the rights within OpenShift.

```code
oc login -u system:admin
oc project monitoring
oc adm policy add-cluster-role-to-user cluster-reader system:serviceaccount:$(oc project -q):default
```

```code
oc logs -f $(oc get pods -o name -l app=prometheus)
```

Navigate to the prometheus url and view the status of the *targets*.

## Adding router metrics

For routing OpenShift makes use of an *HAProxy* instance(s).
Which runs in a pod under the *default* namespace.

```code
oc login -u system:admin -n default
oc get pods
oc get services
```

This instance is configured to provide performance metrics on port *1936* via the *stats* option, protected by a username:password combination.

```code
oc exec [router pod] grep auth /var/lib/haproxy/conf/haproxy.config
```

Besides html the *stats* page can also deliver the metrics in *csv* format by using `/;csv`

### haproxy-exporter

Since Prometheus needs the metric presented differently we will be using an *exporter*. Which will convert the *csv* data and present it in the Prometheus format in a */metrics* target.

```code
oc create -f objects/dc.haproxy-exporter.yml
```

Grab the HAProxy user:password from within the router pod

```code
oc exec -n default $(oc get pods -l deploymentconfig=router -o name -n default|cut -d/ -f2) grep auth /var/lib/haproxy/conf/haproxy.config
```
q
