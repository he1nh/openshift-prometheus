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

## The Components

* Prometheus for retrieving, storing and querying the metrics
* haproxy-exporter for converting the OpenShift router metrics into a format Prometheus understands
* optional: Grafana for providing a nicer dashboard to the graphs

This README contains two ways for deploying the above in two ways

1. Everything in one go using (/objects/all-in-one.yml)
2. Deploying the components one by one

## Disclaimer

I am not an OpenShift and/or Prometheus expert and this text has been written for demo purposes.
So most of the information is at best sub optimal and most likely unsafe for production situations.

# 1. Deploying everything in one go

> Warning: we will be deploying into the *default* namespace.
> Do *NOT* do this at ~~home~~ your company..

## the stage

```code
oc cluster up
oc login -u system:admin -n default
```

create the service accounts; one for prometheus and one for grafana:

```code
./create_serviceaccounts.sh
```

Retrieve the password for the *haproxy* statistics page and convert it to a base64 encoded string.

```code
oc export dc route | grep -A1 STATS_PASSWORD
echo -n <password> | base64
```

edit the object file (/objects/all-in-one.yml) filling in above base64 encoded password string.

## deployment 

Deploy the exporter,prometheus and grafana in one go:

```code
oc create -f objects/all-in-one.yml
```

have look at what has been created

```code
oc get dc,svc,routes,secrets,configmaps -l 'app in (exporter,prometheus,grafana)'
```

> Note: for label selection using *sets* see: (https://kubernetes.io/docs/user-guide/labels)

### Checks

Check if the *exporter* can access the *haproxy* stats page:

```code
curl http://<export svc ip>:9101/metrics | grep ^haproxy_up
```

Navigate to the prometheus route URL and have a look at the status of the *targets*.
If everything went according to plan they should all be up.

# 2. Deploying
 
```code
oc cluster up
oc new-project monitoring
```

## Deploying Prometheus

You can create a running prometheus instance based on the docker hub image via `oc run`. This image expects to run under the root user account. Therefor we will create a sepearate serviceaccount for prometheus.

```command
oc create serviceaccount prometheus
```

add the *anyuid* scc to the prometheus user

```command
oc login -u system:admin
oc adm policy add-scc-to-user anyuid -z prometheus -n monitoring
```

deploy prometheus:

```code
oc login -u developer -n monitoring
oc run prometheus --image=prom/prometheus:v1.4.1 --port=9090 --expose -l app=prometheus
```

```code
oc get dc,svc
```

expose the service to be able to access prometheus from outside the cluster.

```code
oc expose svc prometheus
oc get routes
```

### Exploring Prometheus

Navigate to the hostname in the route and browse trough the web interface including the different targets in the *status* pull-down menu.

![prometheus screenshot](/screenshots/prometheus-screenshot-1.png)

As you can see, at the moment Prometheus is only monitoring itself. And although handy for getting yourself familiar with the Prometheus query language and general workings. It won't help you in monitoring your cluster. So when you want to do something more usefull you will need to modify the configuration file (*/etc/prometheus/prometheus.yml*) and add some additional *scrape* targets. Whereby we will be using Prometheus's integrated Kubernetes Service Discovery (SD).

Create a [configmap](https://docs.openshift.com/container-platform/3.3/dev_guide/configmaps.html) including the prometheus config file and attach it as a *volume mount* to the pod by editing the prometheus deployment config

```code
oc create configmap prometheus-config --from-file=prometheus.yml=files/prometheus-kubernetes.yml -n monitoring
```

add below to the deploymentconfig (`oc edit dc prometheus`) just below the line `terminationMessagePath: /dev/termination-log`:

```code
        volumeMounts:
        - mountPath: /etc/prometheus
          name: config
      volumes:
      - configMap:
          items:
          - key: prometheus.yml
            path: prometheus.yml
          name: prometheus-config
        name: config
```

Grant the prometheus pod to query the OpenShift API server:

```code
oc login -u system:admin
oc adm policy add-cluster-role-to-user cluster-reader system:serviceaccount:monitoring:prometheus
```

Browse to the *target* status page within prometheus so see if the service discovery is working

## Router Metrics

For routing, OpenShift makes use of one or more *HAProxy* instance(s) which run under the *default* namespace.

```code
oc login -u system:admin -n default
oc get pods,services
```

Out of the box OpenShift has configured haproxy to provide performance metrics on port *1937*
via the *stats* option in the configuration file.
However, it is protected by a username:password combination.

to retrieve the credentials:

```code
oc exec <router pod> grep auth /var/lib/haproxy/conf/haproxy.config
```

> You can find the username:password combination in multiple ways (*deploymentconfig*, environment variable, etc.).

Navigate to the haproxy stats page by connecting to the router service ip on port 1936

```code
oc get svc -l router=router
```

Using the retrieved username and password to login.
Besides an within HTML page the *stats* can also be returned as csv by ending the url on `;csv`

![haproxy statistics screenshot](/screenshots/haproxy-stats-screenshot.png)

### haproxy-exporter

To convert the *csv* output into a format that prometheus understands and can retrieve.
We will make use of the *haproxy-exporter* which is part of the Prometheus project.
For accessing the metrics the *exporter* will need to know the username and
password with which to retrieve the *csv* file. We will store these credentials in a secret.

Edit the *exporter* object file (/objects/exporter.yml) and paste in the base64 encoded password string (the username is allready defined):

```code
echo -n <password> | base64
vi objects/exporter.yml
```

And create the objects in the *default* namespace:

```code
oc login -u system:admin
oc create -f objects/exporter.yml -n default
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

### Adding the haproxy-exporter as a scrape target

I will leave it up to the reader to add the haproxy-export as a srape target to the prometheus configuration file.

### Grafana

```code
oc login -u developer -n monitoring
```

create *grafana* serviceaccount and add *anyuid* scc to user:

```code
oc create serviceaccount grafana
```

```code
oc login -u system:admin
oc adm policy add-scc-to-user anyuid -z grafana -n monitoring
```

```code
oc create -f objects/grafana.yml
```

Login to the Grafan (`oc get route`)
The default Grafana username/password combination is *admin/admin*
