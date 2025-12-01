#!/bin/bash

helm upgrade --install \
  cert-manager oci://quay.io/jetstack/charts/cert-manager \
  --version v1.19.1 \
  --namespace cert-manager \
  --create-namespace \
  --set crds.enabled=true

helm repo add k8ssandra https://helm.k8ssandra.io/stable
helm upgrade --install k8ssandra-operator k8ssandra/k8ssandra-operator -n k8ssandra-operator --create-namespace --set image.tag=v1.29.0

