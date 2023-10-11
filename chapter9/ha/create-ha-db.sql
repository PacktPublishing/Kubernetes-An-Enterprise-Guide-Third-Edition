CREATE DATABASE vcluster_tenant1;


CREATE USER 'vcluster_tenant1'@'%' 
   REQUIRE SUBJECT '/O=k8s-enterprise-guide/CN=vcluster_tenant1'
   AND ISSUER '/CN=enterprise-ca';

GRANT ALL PRIVILEGES ON vcluster_tenant1.* to 'vcluster_tenant1'@'%'; 
