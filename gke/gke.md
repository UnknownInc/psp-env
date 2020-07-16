
# GKE installation

```sh
gcloud beta container --project "ind-si-infra-managment-184960" clusters create "psbcluster1" --zone "us-central1-c" --no-enable-basic-auth --cluster-version "1.16.10-gke.8" --machine-type "n1-standard-2" --image-type "COS" --disk-type "pd-standard" --disk-size "100" --local-ssd-count "1" --metadata disable-legacy-endpoints=true --scopes "https://www.googleapis.com/auth/cloud-platform" --num-nodes "3" --enable-stackdriver-kubernetes --enable-ip-alias --network "projects/ind-si-infra-managment-184960/global/networks/default" --subnetwork "projects/ind-si-infra-managment-184960/regions/us-central1/subnetworks/default" --default-max-pods-per-node "110" --no-enable-master-authorized-networks --addons HorizontalPodAutoscaling,HttpLoadBalancing --enable-autoupgrade --enable-autorepair --max-surge-upgrade 1 --max-unavailable-upgrade 1
```

### connect to cluster
```sh
gcloud container clusters get-credentials psbcluster1 --zone us-central1-c --project ind-si-infra-managment-184960
```

### create namespaces
```sh
kubectl create namespace prod dev
```

## storageclasses
```sh
kubectl get storageclasses
cat <<EOF > faststorage.yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: fast
provisioner: kubernetes.io/gce-pd
parameters:
  type: pd-ssd
  replication-type: none
EOF

kubectl apply -f faststorage.yaml
```

# istio
```sh
istioctl install --set profile=demo
kubectl label namespace default dev prod istio-injection=enabled
```

## istio ingress
https://istio.io/latest/docs/tasks/traffic-management/ingress/ingress-control/
```sh
export INGRESS_HOST=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
export INGRESS_PORT=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.spec.ports[?(@.name=="http2")].port}')
export SECURE_INGRESS_PORT=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.spec.ports[?(@.name=="https")].port}')
export TCP_INGRESS_PORT=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.spec.ports[?(@.name=="tcp")].port}')

```

# K8s dashboard
```sh
kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.0.3/aio/deploy/recommended.yaml

kubectl proxy

open http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/

# create admin user
# kubectl apply -f adminuser.yaml

#get token
# kubectl -n kubernetes-dashboard describe secret $(kubectl -n kubernetes-dashboard get secret | grep admin-user | awk '{print $1}')
```


# helm
```sh
helm repo add stable https://kubernetes-charts.storage.googleapis.com/
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo add timescale https://charts.timescale.com

helm repo update
```

## RBAC Considerations
**Note:** If your GKE cluster has RBAC enabled, you must grant Cloud Build Service Account the cluster-admin role (or make it more specific for your use case)

```sh
export PROJECT_ID="$(gcloud projects describe $(gcloud config get-value core/project -q) --format='get(projectNumber)')"

export SERVICE_ACCOUNT="${PROJECT_ID}@cloudbuild.gserviceaccount.com"
```

## Add IAM policy for cloudbuild cluster administration
```sh
gcloud projects add-iam-policy-binding ${PROJECT_ID} \
  --member=serviceAccount:${SERVICE_ACCOUNT} \
  --role=roles/container.admin
```

## and add a clusterrolebinding
```sh
kubectl create clusterrolebinding cluster-admin-${SERVICE_ACCOUNT} --clusterrole cluster-admin --user ${SERVICE_ACCOUNT}
```

# Timescaledb

```sh
git clone https://github.com/timescale/timescaledb-kubernetes.git
cd timescaledb-kubernetes/timescaledb/charts/timescaledb-single/ 
bash ./generate_kustomization.sh tsdb
kubectl apply -k "./kustomize/tsdb" -n $NS
helm upgrade --install tsdb ./ -f $NS.values.yaml -n $NS
```

TimescaleDB can be accessed via port `5432` on the following DNS name from within your cluster:
`tsdb.<namespace>.svc.cluster.local`

To get your password for superuser run:

**superuser password**
```sh
PGPASSWORD_POSTGRES=$(kubectl get secret --namespace $NS tsdb-credentials -o jsonpath="{.data.PATRONI_SUPERUSER_PASSWORD}" | base64 --decode)
EVENTS_PASSWORD=$PGPASSWORD_POSTGRES
EVENTS_USER=postgres
```

**admin password**
```sh
PGPASSWORD_ADMIN=$(kubectl get secret --namespace $NS tsdb-credentials -o jsonpath="{.data.PATRONI_admin_PASSWORD}" | base64 --decode)
```

To connect to your database, chose one of these options:

1. Run a postgres pod and connect using the psql cli:

**login as superuser**
```sh
kubectl run --generator=run-pod/v1 -i --tty --rm psql --image=postgres \
  --env "PGPASSWORD=$PGPASSWORD_POSTGRES" \
  --command -- psql -U postgres \
  -h tsdb.$NS.svc.cluster.local postgres 
```

**login as admin**

```sh
kubectl run --generator=run-pod/v1 -i --tty --rm psql \
  --image=postgres \
  --env "PGPASSWORD=$PGPASSWORD_ADMIN" \
  --command -- psql -U admin \
    -h tsdb.$NS.svc.cluster.local postgres 
```

2. Directly execute a psql session on the master node

```sh
MASTERPOD="$(kubectl get pod -o name --namespace $NS -l release=tsdb,role=master)"
kubectl exec -i --tty --namespace $NS ${MASTERPOD} -- psql -U postgres

psql> create database psb;
psql> \c psb;
psql> CREATE EXTENSION IF NOT EXISTS timescaledb CASCADE;
psql> GRANT ALL ON DATABASE psb to CURRENT_USER;
```

# Kubedb

```sh
helm repo add appscode https://charts.appscode.com/stable/
helm repo update

helm install kubedb-operator appscode/kubedb \
  --version v0.13.0-rc.0 \
  --namespace kube-system

helm install kubedb-catalog appscode/kubedb-catalog \
  --version v0.13.0-rc.0 \ 
  --namespace kube-system
```

# Mongodb
```sh
kubectl get mongodbversions
kubectl apply -f mgo-$NS.yaml -n $NS
DB_USERNAME="$(kubectl get secrets -n $NS mgo-$NS-auth -o jsonpath='{.data.\username}' | base64 -D)"
DB_PASSWORD="$(kubectl get secrets -n $NS mgo-$NS-auth -o jsonpath='{.data.\password}' | base64 -D)"
DB_PORT=27019
DB_SERVER=mgo-$NS
DB_URI="mongodb://$DB_USERNAME:$DB_PASSWORD@$DB_SERVER:$DB_PORT/pulsedb"
echo $DB_URI 
kubectl port-forward -n $NS $(kubectl get pods -n $NS --selector=kubedb.com/name=mgo-$NS --output=jsonpath="{.items[0].metadata.name}") 27019:27017 &

kubectl exec -it mgo-$NS-0 -n $NS -- mongo admin -u $DB_USERNAME -p $DB_PASSWORD

use pulsedb
db.createUser(
   {
     user: "pdbuser",
     pwd: passwordPrompt(),  // Or  "<cleartext password>"
     roles: [ "readWrite", "dbAdmin" ]
   }
)

mongorestore --uri=mongodb://pdbuser:$DB_PASSWORD@127.0.0.1:27019/pulsedb -d pulsedb ./pulsedb
```

## cleanup
```sh
kubectl patch -n $NS mg/mgo-$NS -p '{"spec":{"terminationPolicy":"WipeOut"}}' --type="merge"
kubectl delete -n $NS mg/mgo-$NS

kubectl patch -n $NS drmn/mgo-$NS -p '{"spec":{"wipeOut":true}}' --type="merge"
kubectl delete -n $NS drmn/mgo-$NS
```