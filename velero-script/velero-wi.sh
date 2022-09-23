#!/bin/bash

# Bucket oluşturma işlemi. Halihazırda bucket varsa ismi girildiğinde bucket'ın var olduğuna dair uyarı döndürür.
BUCKET=$1
gsutil mb gs://$BUCKET/

# ProjectID değerinin ortam değişkenine aktarıldı.
PROJECT_ID=$(gcloud config get-value project)

# Google Cloud Service Account hesabı oluşturulması.
GSA_NAME=$2
gcloud iam service-accounts create $GSA_NAME --display-name "Velero service account"

# Hesap oluşturulmuş mu kontrol edelim.
if [[ -z $(gcloud iam service-accounts list | grep "Velero service account") ]]; then
    echo "Service Account oluşturulmamış işlem sonlandırılıyor..."
else
    # Servis Account mail adresi ortam değişkenine aktarıldı.
    SERVICE_ACCOUNT_EMAIL=$(gcloud iam service-accounts list --filter="displayName:Velero service account" --format 'value(email)')
    # Permissionların role atanması için listesinin oluşturulması.
    ROLE_PERMISSIONS=(
    compute.disks.get
    compute.disks.create
    compute.disks.createSnapshot
    compute.snapshots.get
    compute.snapshots.create
    compute.snapshots.useReadOnly
    compute.snapshots.delete
    compute.zones.get
    storage.objects.create
    storage.objects.delete
    storage.objects.get
    storage.objects.list
    )
    if [[ -z $(gcloud iam roles list --project $PROJECT_ID | grep velero.server) ]]; then
        echo "Rol oluşturuluyor..."
        gcloud iam roles create velero.server --project $PROJECT_ID --title "Velero Server" --permissions "$(IFS=","; echo "${ROLE_PERMISSIONS[*]}")"
    else
        echo "Önceden oluşturulmuş rol var, işleme devam ediliyor..."
    fi
    # Policy binding işlemi.
    gcloud projects add-iam-policy-binding $PROJECT_ID --member serviceAccount:$SERVICE_ACCOUNT_EMAIL --role projects/$PROJECT_ID/roles/velero.server
    # Bucket üzerine yetkilendirme için.
    gsutil iam ch serviceAccount:$SERVICE_ACCOUNT_EMAIL:objectAdmin gs://${BUCKET}
    # Velero için namespace oluşturulması.
    NAMESPACE=velero
    kubectl create namespace $NAMESPACE
    # Kubernetes Service Account oluşturulması.
    KSA_NAME=$3
    kubectl create serviceaccount $KSA_NAME --namespace $NAMESPACE
    # Kubernetes Service Account'unun Google Service Account üyesi yapılması.
    gcloud iam service-accounts add-iam-policy-binding --role roles/iam.workloadIdentityUser --member "serviceAccount:${PROJECT_ID}.svc.id.goog[$NAMESPACE/$KSA_NAME]" ${GSA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com
    kubectl annotate serviceaccount $KSA_NAME --namespace $NAMESPACE iam.gke.io/gcp-service-account=${GSA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com
    # Velero binary dosyalarının indirilmesi.
    if [[ -z $(ls | grep velero-v1.9.1-linux-amd64.tar.gz) ]]; then
    pwd_=$(pwd)
    extension=velero-installation
    mkdir $extension
    cd $extension
    wget https://github.com/vmware-tanzu/velero/releases/download/v1.9.1/velero-v1.9.1-linux-amd64.tar.gz
    tar -xf velero-v1.9.1-linux-amd64.tar.gz
    cd velero-v1.9.1-linux-amd64
    sudo cp velero /usr/local/bin
    rm -r "$pwd_/$extension"
    fi
    # Velero kurulumu.
    velero install --provider gcp --plugins velero/velero-plugin-for-gcp:v1.5.0 --bucket $BUCKET --no-secret --sa-annotations iam.gke.io/gcp-service-account=[$GSA_NAME]@[$PROJECT_ID].iam.gserviceaccount.com --backup-location-config serviceAccount=[$GSA_NAME]@[$PROJECT_ID].iam.gserviceaccount.com

fi

    
