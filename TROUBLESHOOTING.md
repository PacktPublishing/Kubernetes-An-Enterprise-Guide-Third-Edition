# Troubleshooting

If the labs aren't working, even though you followed all the steps, take a look here to see if its a common issue before opening an issue on GitHub.  If it's still not working, please open an issue so we can help out!

## Invalid Login from OpenUnison

When you login to any of the OpenUnison labs you may find you're getting a screen that says "Invalid Credentials".  First, make sure you're typing in the right password.  If that fails, sometimes the simulated "Active Directory" will fail to start properly.  The easiest way to fix this is to just delete the `Pod` and let ApacheDS restart:

```
kubectl delete pods -l app=apacheds -n activedirectory
```

Once the pod restarts, try again.  If it still doesn't work, look at the logs for OpenUnison in the `openunison` namepace:

```
kubectl logs -f -l app=openunison-orchestra -n openunison 
```

If you don't see any exceptions, while trying to login, please open an issue.

## MySQL Won't Start

Depending on where you're running your Ubuntu VM, you may get the message `Fatal glibc error: CPU does not support x86-64-v2`.  This is because of the processor you have your VM configured with.  If you set it to passthrough and reboot, this error should be eliminated.