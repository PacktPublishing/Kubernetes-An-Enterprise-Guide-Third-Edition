# Errata

This doc describes any issues found in the book.

## Chapter 17, Page 544

The exercise at the bottom of the page to check if you can inject user info into an istio request from inside of a `Pod` that is not in the service mesh:

```
$ kubectl run -i --tty curl --image=alpine --rm=true – sh
/ # apk update add curl
/ # curl -H "User-Info $(echo -n '{"sub":"marc","groups":["group1","group2"]}'
| base64 -w 0)" http://run-service.istio-hello-world.svc/who-am-i
```

This code doesn't run properly.  use this instead:

```sh
kubectl run -i --tty curl --image=alpine --rm=true -- sh -c '
  apk update &&
  apk add --no-cache curl &&
  curl -H "User-Info: $(echo -n "{\"sub\":\"marc\",\"groups\":[\"group1\",\"group2\"]}" | base64 -w 0)" \
       http://run-service.istio-hello-world.svc/who-am-i
'
```

The next exercise, where you attempt to inject user info from outside of the cluster:

```
export USERINFO=$(echo -n '{"sub":"marc","groups":["group1","group2"]}' |
base64 -w 0)
curl -H "Authorization: Bearer $(curl --insecure -u 'mmosley:start123'
https://k8sou.192-168-2-119.nip.io/k8s-api-token/token/user 2>/dev/null| jq -r
'.token.id_token')" -H "User-Info: $USERINFO" http://service.192-168-2-119.nip.
io/who-am-i
```

Has an incorrect URL, it should be `k8sou.apps.192-168-2-119.nip.io`:

```sh
export USERINFO=$(echo -n '{"sub":"marc","groups":["group1","group2"]}' | base64 -w 0)
curl -H "Authorization: Bearer $(curl --insecure -u 'mmosley:start123' https://k8sou.apps.192-168-2-53.nip.io/k8s-api-token/token/user 2>/dev/null| jq -r '.token.id_token')" -H "User-Info: $USERINFO" http://service.192-168-2-53.nip.io/who-am-i
```

## Chapter 19, Page 599

The Vault unsealing script needs to be run from your pulumi directory.  instead of `../vault/unseal.sh` it should be `/path/to/Kubernetes-An-Enterprise-Guide-Third-Edition/chapter19/vault/unseal.sh`.

When showing the secrets:

`pulumi config --show-secrets`

## Chapter 19, Page 600

Just as with vault, run the `harbor-get-root-password.sh` script directly from your pulumi stack directory.  Instead of `../scripts/harbor-get-root-password.sh` to `/path/to/Kubernetes-An-Enterprise-Guide-Third-Edition/chapter19/scripts/harbor-get-root-password.sh`