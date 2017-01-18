#!/bin/bash

oc create serviceaccount prometheus
oc create serviceaccount grafana

# in images from Docker Hub both prometheus and grafana expect to run as root user
echo "adding security context constrain 'anyuid' to user prometheus"
oc adm policy add-scc-to-user anyuid -z prometheus
echo "adding security context constrain 'anyuid' to user grafana"
oc adm policy add-scc-to-user anyuid -z grafana

# add cluster-reader role to prometheus in default namespace. For prometheus service discovery (SD) to work
echo "adding cluster-role 'cluster-reader' to user prometheus in namespace 'default'"
oc adm policy add-cluster-role-to-user cluster-reader system:serviceaccount:default:prometheus
