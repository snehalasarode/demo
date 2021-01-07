#!/bin/bash 
#==============================================================
#
# Author : Atos Cloud Foundry Team
# Purpose : concourse job to deploy grafana on CFCR cluster
# Date :
#
#======================================================================


#======================================================================
now="$(date)"
echo "current date and time:$now"

export PWD=`pwd`
login_to_credhub(){
  credhub api --server=https://$BOSH_IP:8844 --ca-cert=$PWD/credhub_ca.pem --ca-cert=$PWD/uaa_ca.pem
  credhub login --client-name=credhub-admin --client-secret=$CREDHUB_SECRET
}

login_to_obsutils(){
obsutil cp obs://huawei-credentials/proto-bosh/bosh_ca.pem . -i=$OBS_ACCESS_KEY -k=$OBS_SECRET_ACCESS_KEY -e=https://obs.ap-southeast-1.myhuaweicloud.com
obsutil cp obs://huawei-credentials/proto-bosh/bosh_secret.txt . -i=$OBS_ACCESS_KEY -k=$OBS_SECRET_ACCESS_KEY -e=https://obs.ap-southeast-1.myhuaweicloud.com
obsutil cp obs://huawei-credentials/proto-bosh/uaa_ca.pem . -i=$OBS_ACCESS_KEY -k=$OBS_SECRET_ACCESS_KEY -e=https://obs.ap-southeast-1.myhuaweicloud.com
obsutil cp obs://huawei-credentials/proto-bosh/credhub_ca.pem . -i=$OBS_ACCESS_KEY -k=$OBS_SECRET_ACCESS_KEY -e=https://obs.ap-southeast-1.myhuaweicloud.com
obsutil cp obs://huawei-credentials/proto-bosh/credhub_secret.txt . -i=$OBS_ACCESS_KEY -k=$OBS_SECRET_ACCESS_KEY -e=https://obs.ap-southeast-1.myhuaweicloud.com
obsutil cp obs://huawei-credentials/grafana_secret.txt . -i=$OBS_ACCESS_KEY -k=$OBS_SECRET_ACCESS_KEY -e=https://obs.ap-southeast-1.myhuaweicloud.com
CREDHUB_SECRET=`awk '$1=="credhub_secret:"{print $2}' credhub_secret.txt`
}
obsutil cp obs://huawei-credentials/proto-bosh/bosh_ca.pem . -i=$OBS_ACCESS_KEY -k=$OBS_SECRET_ACCESS_KEY -e=https://obs.ap-southeast-1.myhuaweicloud.com

get_bosh_creds(){
 export BOSH_CLIENT_SECRET=`awk '$1=="bosh_secret:"{print $2}' bosh_secret.txt`
 echo $BOSH_CLIENT_SECRET
 export BOSH_CLIENT=admin
}
login_to_obsutils

echo "Setting Credhub"
login_to_credhub

echo "--------------------setting Kube Config ---------------------"
./acfcr-"$ENV"-changes/eu01/kubo-deployment/bin/set_kubeconfig $DIRECTOR_NAME/cfcr https://api.huawei."$URL_ENV".acf-cr.atos.net:8443
echo "--------------------checking access to cluster ---------------------"
kubectl get pods --namespace=kube-system
echo "--------------------create namespace monitoring ---------------------"
kubectl create namespace monitoring
echo "---------------Upload configs-----------------"
credhub get -n /bosh/huawei-global-proto-uaa/uaa_ssl --key ca > client_ca.crt
credhub get -n /bosh/huawei-global-proto-uaa/uaa_ssl --key certificate > client.crt
credhub get -n /bosh/huawei-global-proto-uaa/uaa_ssl --key private_key > client.key
kubectl create configmap client-cert-configmap --from-file=$PWD/client.crt -n monitoring
kubectl create configmap client-key-configmap --from-file=$PWD/client.key -n monitoring
kubectl create configmap client-ca-configmap --from-file=$PWD/client_ca.crt -n monitoring
echo "---------------------creating secret for grafana-----------------"
kubectl create secret generic grafana-pwd --from-file=password=$PWD/grafana_secret.txt -n monitoring
echo "--------------------creating configmap for adding dashboard ---------------------"
kubectl apply -f acfcr-grafana-deployment/eu01/control-planes/monitoring/grafana/grafana-dashboard-configmap.yaml -n monitoring
echo "--------------------creating volumeclaim ---------------------"
kubectl apply -f acfcr-grafana-deployment/eu01/control-planes/monitoring/grafana/grafana-volumeClaim.yaml -n monitoring
echo "--------------------Creating grafana service---------------------"
kubectl apply -f acfcr-grafana-deployment/eu01/control-planes/monitoring/grafana/grafana-service.yaml -n monitoring
echo "--------------------Deploying grafana ---------------------"
kubectl apply -f acfcr-grafana-deployment/eu01/control-planes/monitoring/grafana/grafana-deployment.yaml -n monitoring
echo "--------------------Creating grafana ingress---------------------"
kubectl apply -f acfcr-grafana-deployment/eu01/"$ENV"/grafana-ingress/grafana-ingress.yaml -n monitoring
echo "----------------------Checking grafana pods---------------------"
kubectl get all --namespace=monitoring

kubectl get all -o wide --namespace=monitoring

