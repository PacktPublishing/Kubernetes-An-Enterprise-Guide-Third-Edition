#!/bin/bash

kubectl apply -f - <<EOF
apiVersion: v1
data:
  extra.pem: |-
        -----BEGIN CERTIFICATE-----
        MIIDETCCAfmgAwIBAgIUbkbKfQ7oeurnTzrygH/GCKI36E0wDQYJKoZIhvcNAQEL
        BQAwGDEWMBQGA1UEAwwNZW50ZXJwcmlzZS1jYTAeFw0yMjExMDcxNDQ1MjJaFw0z
        MjExMDQxNDQ1MjJaMBgxFjAUBgNVBAMMDWVudGVycHJpc2UtY2EwggEiMA0GCSqG
        SIb3DQEBAQUAA4IBDwAwggEKAoIBAQCnqVwyQo22rG6nUZcSe/GmVfr90Kzgux09
        468pSSQdpDq9RTQUOvfATPBW81wBRfP1/ryEhshruAKa9/5h+5B/x8ncxTXpm8B7
        vD7etv8WuryKPsILuidOD0GQSETo77AXM7FfiROr01j7w6QPwuPvBJSp3ikiC/Dc
        vE66lvIEXN7dSgDddvuvGQNDWOYlGZhf5FHW/5drPHuO9zuyUG+MMi1iP+RBMPRg
        Ie6v8BpOgrsgdtmXLa4VMsPM+0XfD0H8cSf/2H6WS4/7D8AulnPIoKcY+FLJPAm3
        ITR7/l6Q0IQuMSw6BLKafBFnBVcTQSH7yJdAJ5gH4VYDr2jkUZL3AgMBAAGjUzBR
        MB0GA1UdDgQWBBSf9D5FKwHIF7xWqF/48n+r/RTQ3jAfBgNVHSMEGDAWgBSf9D5F
        KwHIF7xWqF/48n+r/RTQ3jAPBgNVHRMBAf8EBTADAQH/MA0GCSqGSIb3DQEBCwUA
        A4IBAQB7Pl29+rRvxp+TxKOtBddKxHaE2UELnbidhU/16QmnuViBAXbuERHAvcJa
        naoZecBUARtiLXOjh91A6Ao5ZDOdDNYNRCgLb6s7CUXR+3KzvVFcITTRtkSNLJ15
        g4hjYrAKDY1H3OswQ/SrhLoFBwgxbICQyxSKit49Dk+exszn1BE716iiIVgYOGZO
        yIayzBYumFss40jkmhlnk5enab8IL4TqpCe/qbvm5wNjKZUZ3jbl3d1UemqYNuYV
        cEcZ4QymABYKy4VE3TRYRbIdet4V6uYHF5YPyEEiY0TUe+XURZVAmiOcrkjnUHOx
        1bjzRqJZL5TwoFCg5eeDzuY4ZTcc
        -----END CERTIFICATE-----
kind: ConfigMap
metadata:
  name: jwks-certs
  namespace: istio-system
EOF

kubectl patch deployment istiod -n istio-system --type json --patch-file=./patch-istiod.json

while [[ $(kubectl get pods -l app=istiod -n istio-system -o 'jsonpath={..status.conditions[?(@.type=="Ready")].status}') != "True" ]]; do echo "waiting for istiod to be running" && sleep 1; done

export hostip=$(hostname  -I | cut -f1 -d' ' | sed 's/[.]/-/g')

sed "s/IPADDR/$hostip/g" < ./service-auth.yaml > /tmp/service-auth.yaml

kubectl create -f /tmp/service-auth.yaml