#!/bin/bash

oc create -f serviceaccounts.yml

# in images from Docker Hub both prometheus and grafana expect to run as root user
oc adm policy add-scc-to-user anyuid -z prometheus
oc adm policy add-scc-to-user anyuid -z grafana

# add cluster-reader role to prometheus in default namespace. For prometheus service discovery (SD) to work
oc adm policy add-cluster-role-to-user cluster-reader system:serviceaccount:default:prometheus
