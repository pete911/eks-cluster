MIME-Version: 1.0
Content-Type: multipart/mixed; boundary="==MYBOUNDARY=="

--==MYBOUNDARY==
Content-Type: text/x-shellscript; charset="us-ascii"

#!/bin/bash -ex
/etc/eks/bootstrap.sh '${cluster_name}' --b64-cluster-ca '${cluster_ca_base64}' --apiserver-endpoint '${endpoint}'

--==MYBOUNDARY==--\
