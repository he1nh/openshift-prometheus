# Monitoring OpenShift with Prometheus

This project contains files for deploying Prometheus on OpenShift used during a demo.

| software        | version                  |
|-----------------|--------------------------|
|Prometheus       | v1.4.1                   |
|OpenShift        | OpenShift Origin v1.3    |

> For accessing services, this text assumes you are typing on a computer running a single node cluster.
> So located within the SDN.
> When not, you will need to expose (`oc expose svc <service name>`) certain services before you can access them.

## Disclaimer

I am not an OpenShift and/or Prometheus expert and this text has been written for demo purposes.
So most of the information is at best sub optimal and most likely unsafe for production situations.

## Bringing up the cluster

```code
oc cluster up
oc new-project monitoring
```

## deploying Prometheus  *by hand*

create the Prometheus *pod*, *deploymentconfig* and *service* based on the docker hub Prometheus image:

```code
oc run prometheus --image=prom/prometheus:v1.4.1 --port=9090 --expose -l app=prometheus
```

> Note: The Prometheus server running in above pod will fail to start because it is assuming it is running under the root account.
> you can view the logs via `oc logs -f <prometheus pod>`

To allow the server to be started up under any account (including root).
Add the default project user to the anyuid security context constraint (scc).

```code
oc login -u system:admin
oc adm policy add-scc-to-user anyuid -z default -n monitoring
```

For the changes to take effect you need to redeploy Prometheus

```code
oc deploy prometheus --latest --follow
oc get pods
``` 

We are going to access Prometheus with our browser so expose the created service:

```code
oc expose svc prometheus
oc get routes
```

## exploring Prometheus

Navigate to above URL.
And browse trough the different targets in the *status* pull-down menu.

![prometheus screenshot](/screenshots/prometheus-screenshot-1.png)

## Cluster monitoring

To monitor the cluster with OpenShift we will be using the kubernetes service discovery feature in Prometheus.
As defined in the example prometheus-kubernetes configuration coming with the Prometheus source code.

> For this demo we will be deploying within the *default* namespace.
> Do not do this at ~~home~~ your company..

```code
oc login -u system:admin -n default
```

create a serviceaccount for prometheus:
```code
oc create serviceaccount prometheus
```

grant it rights to run a pod under any (including root) id
```code
oc adm policy add-scc-to-user anyuid -z prometheus
```

and give the service account rights to read from the OpenShift API server
```code
oc adm policy add-cluster-role-to-user cluster-reader system:serviceaccount:default:prometheus
```

create a *configmap* which holds the Prometheus configuration file

```code
oc create configmap prometheus-config --from-file=prometheus.yml=config/prometheus-all.yml
```

Deploy Prometheus using the *deploymentconfig*

```code
oc create -f objects/dc/prometheus.yml
```

Navigate to the prometheus URL and view the status of the *targets*.

## Adding router metrics

For routing, OpenShift makes use of an *HAProxy* instance(s).
Which runs in a pod under the *default* namespace.

```code
oc login -u system:admin -n default
oc get pods
oc get services
```

OpenShift default configure haproxy to provide performance metrics on port *1936* via the *stats* option in the configuration file.
However, it is protected by a username:password combination.

> You can find the username:password combination in multiple ways (*deploymentconfig*, environment variable, etc.).
> Below we will be looking at the *haproxy* configuration file inside the pod.

retrieve the credentials:

```code
oc exec <router pod> grep auth /var/lib/haproxy/conf/haproxy.config
```

We will be needing above values later on, so store them in a local environment variable

```code
USER=<username>
PASS=<password>
```

Using above credentials, navigate to the haproxy stats page:

![haproxy statistics screenshot](/screenshots/haproxy-stats-screenshot.png)

Besides HTML the *stats* page can also deliver the metrics in *csv* format by using `/;csv`

### haproxy-exporter

Since Prometheus needs the metric presented differently we will be using an *exporter*. Which will convert the *csv* data and present it in the Prometheus format in a */metrics* target.

The username and password for accessing the *HAProxy* stats page are stored as *base64* encoded strings in the [object definition file](/objects/multi/exporter.yml).
You will need to add the encoded password to the *Secret* section (top of the file) before continuing

```code
echo -n $USER | base64
echo -n $PASS | base64
```

After modifying the object definition file, you can create the *exporter* objects:

```code
oc create -f objects/multi/exporter.yml
```

> Note: you can troubleshoot the export via `curl http://<exporter svc ip>:9101/metrics | grep haproxy_up`

## Where to go from here

* Prometheus Querying
** https://prometheus.io/docs/querying/examples/


# Bonus

## Grafana

```code
oc create -f objects/multi/grafana.yml
oc adm policy add-scc-to-user anyuid -z grafana
```
