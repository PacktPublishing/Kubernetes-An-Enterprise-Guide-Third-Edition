package istio.authz

import input.attributes.request.http as http_request
import input.parsed_path

default allow = false


# helper function to check that an array contains a value
contains_element(arr, elem) = true {
    arr[_] = elem
} else = false { true }

# checks that the authorization header is properly formatted and returns the parsed payload
verify_headers() = payload {
    # verify that there is an authorization header
    startswith(http_request.headers["authorization"], "Bearer ")

    # parse the JWT into its header, payload, and signature
    # we aren't going to validate the JWT, Istio did that in
    # the RequestAuthentication
    [header, payload, signature] := io.jwt.decode(trim_prefix(http_request.headers["authorization"], "Bearer "))

} else = false {true}

# Test case if the groups claim is a list for both k8s-cluster-admins and not group2
allow {

    # verify headers and retrieve the jwt payload
    payload := verify_headers()    

    # make sure there are groups
    payload.groups

    # make sure the user is an admin
    contains_element(payload.groups,"cn=k8s-cluster-admins,ou=Groups,DC=domain,DC=com")

    # make sure the user is not in group2
    not contains_element(payload.groups,"cn=group2,ou=Groups,DC=domain,DC=com")
}

# Test case if groups is not a list, only checking for 
allow {
    # verify headers and retrieve the jwt payload
    payload := verify_headers()    

    # make sure there are groups
    payload.groups

    # make sure the user is an admin
    payload.groups == "cn=k8s-cluster-admins,ou=Groups,DC=domain,DC=com"
}

