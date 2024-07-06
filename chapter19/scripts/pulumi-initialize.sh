#!/bin/bash

pulumi config set openunison.cp.dns_suffix idp-cp.tremolo.dev
pulumi config set kube.cp.context  kubernetes-admin@kubernetes
pulumi config set harbor:url https://harbor.idp-cp.tremolo.dev
pulumi config set kube.cp.path /Users/marcboorshtein/.kube/idp-cp
pulumi config set harbor:username admin
pulumi config set openunison.dev.dns_suffix idp-dev.tremolo.dev
pulumi config set openunison.prod.dns_suffix idp-prod.tremolo.dev