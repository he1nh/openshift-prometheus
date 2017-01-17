# Monitoring OpenShift with Prometheus

This project contains a description and accompanying files for deploying Prometheus
on OpenShift for monitoring the cluster.

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

# The Components

* Prometheus for retrieving, storing and querying the metrics
* an haproxy-exporter for converting the OpenShift router metrics into a format Prometheus understands
* Grafana for providing a nicer dashboard to the graphs

Before deploying everything in one go, we will have a brief look at Prometheus and the exporter

## Prometheus

You can create a running Prometheus instance based on the docker hub image via `oc run`. But before you do that give the default user account in the project rights to start up the pod as the *root* user. By adding the *anyuid* security context constraint (scc) to the user.

> Note: later on, we will create a seperate service account for Prometheus.
```code
oc login -u system:admin
oc adm policy add-scc-to-user anyuid -z default -n monitoring
oc login -u developer -n monitoring
oc run prometheus --image=prom/prometheus:v1.4.1 --port=9090 --expose -l app=prometheus
```

The last commond will create a Prometheus:
* deploymentconfig
* and service
and start up a prometheus pod based on the *deploymentconfig*

```code
oc get dc,svc
```

To access Prometheus from outside the cluster, you need to expose the service which was created by `oc run`

```code
oc expose svc prometheus
oc get routes
```

### exploring Prometheus

Navigate to above URL.
And browse trough the different targets in the *status* pull-down menu.

![prometheus screenshot](/screenshots/prometheus-screenshot-1.png)

As you can see, at the moment Prometheus is only monitoring itself. And although handy for getting yourself familiar with the Prometheus query language and general workings. It won't help you in monitoring your cluster. So when you want to do something more usefull you will need to modify the configuration file (*/etc/prometheus/prometheus.yml*) and add some additional *scrape* targets.

In this project we will be using a [configmap](https://docs.openshift.com/container-platform/3.3/dev_guide/configmaps.html) to attach our custom configuration.

### 

## Router Metrics

For routing, OpenShift makes use of one or more  *HAProxy* instance(s).
Who run under the *default* namespace.

```code
oc login -u system:admin -n default
oc get pods,services
```

Out of the box OpenShift has configured haproxy to provide performance metrics on port *1936*
via the *stats* option in the configuration file.
However, it is protected by a username:password combination.

to retrieve the credentials:

```code
oc exec <router pod> grep auth /var/lib/haproxy/conf/haproxy.config
```

> You can find the username:password combination in multiple ways (*deploymentconfig*, environment variable, etc.).

Navigate to the haproxy stats page and use above username and password to login.

![haproxy statistics screenshot](/screenshots/haproxy-stats-screenshot.png)

Besides within an HTML the *stats* page can also deliver the metrics in *csv* format

![haproxy statistics screenshot](/screenshots/haproxy-stats-screenshot.png/;csv)

### haproxy-exporter

To convert the *csv* format into a format that Prometheus understands and can retrieve.
We will make use of the *haproxy-exporter* which is part of the Prometheus project.
For accessing the metrics the *exporter* will need to no the username and
password with which to retrieve the *csv* file. We will store these credentials in a secret.

Edit the *exporter* object file and paste in the base64 encoded password string (the username is allready defined).
And create the objects.

```code
echo -n <password> | base64
vi objects/exporter.yml
oc create -f objects/exporter.yml
```

After the *exporter* pod has been deployed, you can test if it works by having a look at the converted/exported metrics.

```code
curl http://<exporter svc ip>:9101/metrics
```

Pay special attention to the *haproxy_up* metric, this should be one. If it is not, it probably means that
there is a problem with accessing the *stats*

```code
curl http://<exporter svc ip>:9101/metrics | grep haproxy_up
```

# Cluster monitoring

To monitor the OpenShift cluster with Prometheus we will be using the kubernetes service discovery feature in Prometheus.
As defined in the example prometheus-kubernetes configuration coming with the Prometheus source code.

> For this demo we will be deploying within the *default* namespace.
> Do not do this at ~~home~~ your company..

## deployment

In this part we are going to deploy

* a haproxy-exporter for exporting the OpenShift router metrics
* prometheus for scraping the exporter, API server, node(s) and promettheus itself
* grafana for providing a nicer dashboard

```code
oc cluster up
oc login -u system:admin -n default
```

Create the needed *serviceaccounts* with the provided shell script
```code
./create_serviceaccounts.sh
```

Deploy the exporter,prometheus and grafana in one go using the *all-in-one* *deploymentconfig*

```code
oc create -f objects/all-in-one.yml
```
Have  look at what has been created

```code
oc get dc,svc,routes,secrets,configmaps -l 'app in (exporter,prometheus,grafana)'
```

> Note: for more info concerning the usage of the label selection using *sets* see: (https://kubernetes.io/docs/user-guide/labels)

Navigate to the prometheus route URL and have a look at the status of the *targets*.
If everything went according to plan they should all be up.
However there is one issue: The *exporter* can't yet authenticate with the router because it does not have the correct password yet.

> OpenShift default configures haproxy to provide performance metrics on port *1936* via the *stats* option in the configuration file.
> However, it is protected by a username:password combination.
> You can find the username:password combination in multiple ways (*deploymentconfig*, environment variable, haproxy config file, etc.).

```code
oc export dc router | grep -A1 STATS_PASS
```

or

```code
oc exec <router pod> grep auth /var/lib/haproxy/conf/haproxy.config
```

Convert the password to a base64 encoded one. And add it to the secret *haproxy-secret*:

```code
echo -n <value> | base64
oc edit secret haproxy-secret
```

Delete the *exporter* pod to have OpenShift create a new one with correct content

```code
oc delete pod -l app=exporter
oc get pods -l app=exporter -w
```

To see if the exporter can now access the haproxy stats, have a look at the exported metrics

```code
curl http://<export svc ip>:9101/metrics | grep ^haproxy_up
```

## Where to go from here

* Prometheus Querying
** https://prometheus.io/docs/querying/examples/


# Bonus

## Grafana

```code
oc create -f objects/multi/grafana.yml
oc adm policy add-scc-to-user anyuid -z grafana
```
