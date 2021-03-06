#!/bin/sh

if [ x = x$1 -o x = x$2  -o x = x$3 ]; then
    echo "Usage: ./createStarterdb.sh <namespace> <storage>"
    echo "    <namspace> : The OpenShift namespace the service is deployed in"
    echo "    <app>      : The name of the app"
    echo "    <storage>  : Either 'aws' or 'gluster' (specifc param w/o quotes)"
  exit 1
fi
NAMESPACE=$1
APP=$2
STORAGE=$3

# Create mongodb service, deployment etc.
oc new-app \
    --name=${APP}db \
	-n $NAMESPACE \
    -e MONGODB_USER=user \
    -e MONGODB_PASSWORD=password \
    -e MONGODB_DATABASE=${APP}db \
    -e MONGODB_ADMIN_PASSWORD=admin_password \
    centos/mongodb-26-centos7
if [ $? -ne 0 ]; then
    echo "ERROR creating app in ./createAppdb.sh"
    exit 1
fi

# Create volume claim
echo "Create volume claim"
sed 's/APP/'$APP'/g' < appdb_claim_$STORAGE.yaml > ${APP}db_claim_$STORAGE.yaml
oc create -f ${APP}db_claim_$STORAGE.yaml
if [ $? -ne 0 ]; then
    echo "WARNING creating volume in ./createAppdb.sh failed"
fi
rm ${APP}db_claim_$STORAGE.yaml

# Attach volume claim
echo "Attach volume claim"
oc volume dc/${APP}db --add --overwrite \
  --name=${APP}db-volume-1 --type=persistentVolumeClaim \
  --claim-name=${APP}db-claim --mount-path=//var/lib/mongodb
if [ $? -ne 0 ]; then
    echo "ERROR adding volume in ./createAppdb.sh"
    exit 1
fi

# Adjust limits and deployment strategy
echo "Adjust limits and deployment strategy"
./patchDeploy.sh ${APP}db 256Mi
if [ $? -ne 0 ]; then
    echo "ERROR patching limits in ./createAppdb.sh"
    exit 1
fi

# Create probes
echo "Create probes"
./patchProbes.sh ${APP}db 27017
if [ $? -ne 0 ]; then
    echo "ERROR creating probes in ./createAppdb.sh"
    exit 1
fi

exit 0
