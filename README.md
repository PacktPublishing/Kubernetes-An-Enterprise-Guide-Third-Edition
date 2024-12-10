# Kubernetes-An-Enterprise-Guide-Third-Edition
Welcome to the repo for the book Kubernetes – An Enterprise Guide, Third Edition - Published by Packt.
Written by Marc Boorshtein and Scott Surovich.  

# Extra's Directory  
We have created a directoryb called Extras.  This contains content that we wanted to add for readers that is outside of the book content.  
It contains add-ons that we find useful for additional testing and are provided as-is without any support.  

Currently, it container one add-on, dnsmasq.  You can used dnsmasq to create your own domain for Ingress and ISTIO Virtual Services rather than using nip.io like the book exercises use.  
If you decide to use dndmasq for a domain, the scripts in the exercises will still create nip.io URL's, so you will need to change the domains after the scripts create them with your dnsmasq domain instead of nip.io  

dnsmasq was added for readers that may want to used the scripts on other Kubernetes clusters like a kubeadm cluster - or if you use your KinD cluster offline, where nip.io domains will not resolve due to not having an Internet connection.  
  
## Troubleshooting and Getting Help

If labs don't work, take a look at [TROUBLESHOOTING.md](TROUBLESHOOTING.md).  If you're still having issues, please open an issue int his repo and we'll be happy to help!
