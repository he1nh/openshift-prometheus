# monitoring OpenShift with Prometheus (for OpenShift meetup)

This repo contains the files for the presentation of monitoring OpenShift with Prometheus.
To be given at 2016/01/19 at the OpenShift meetup.

## manual

create a new project/namespace

'''code
oc new-project monitoring
'''

create prometheus pod,deploymentconfig and service based on the dockerhub prometheus image:

'''code
oc run --image=prom/prometheus:v1.4.1 -l app=prometheus prometheus
'''

The prometheus binary in above pod will fail to start because it is assuming root rights.. Allow all pods within the monitoring project
to be started as root. By adding the default user to the anyuid security context constraint. And bring it into effect by redeploying the pod.

'''code
oc login -u system:admin
oc adm policy add-scc-to-user anyuid -z default -n monitoring
'''

'''code
oc deploy prometheus --latest --follow
oc get pods
''' 

Lets acces Prometheus

'''code
oc expose dc prometheus --port=9090
oc expose svc prometheus
'''

