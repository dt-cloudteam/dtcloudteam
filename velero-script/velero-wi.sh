#!/bin/bash
# -------------------------------------------- Uyarılar --------------------------------------------------------------------------------
# Parametre olarak ilk Bucket ismi, ikinci olarak location ismi alıyor.
# Service Account isimleri değiştirildiği taktirde velero deployment yaml içerisinde serviceAccount alanlarının değiştirilmesi gerekiyor.
#----------------------------------------------------------------------------------------------------------------------------------------
# Doğru projede olduğumuzun kontrolü.
read -r -p "Doğru projede olduğundan emin misin? [y/N] " response
    if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
        # ProjectID değerimizi ortam değişkenine aktarılması.
        PROJECT_ID=$(gcloud config get-value project)
        BUCKET=$1
        # Girilen bucketin önceden oluşturulup oluşturulmadığına bakılması.
        if [[ -z $(gcloud storage buckets list | grep -x "name: $BUCKET") ]]; then
            echo "Bucket oluşturuluyor..."
            BUCKET_NAME=$BUCKET
            if [[ -z $(gsutil mb -l $2 gs://$BUCKET_NAME/  | grep ServiceException) ]]; then
                echo "Bucket oluşturuldu."
            else
                echo "Aynı isimde bucket var. Bucket ismi global olarak benzersiz olmalı."
                echo "Kurulum sonlandırılıyor..."
                exit
            fi
        else
            # İsimlendirilen Bucket'ın hesabımızdaki storage üzerinde bulunması durumunda.
            read -r -p "Bu isimde bir bucket var backup-location olarak kullanılsın mı? [y/N] " response
            if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
                BUCKET_NAME=$BUCKET
            else
                echo "Kullanılacak bir bucket olmadığından yükleme iptal ediliyor..."
                exit
            fi
        fi
        # Google Cloud Service Account hesabı oluşturulması.
        GSA_NAME=velero
        gcloud iam service-accounts create $GSA_NAME --display-name "Velero service account"

        # Hesap oluşumu kontrolü.
        if [[ -z $(gcloud iam service-accounts list | grep "Velero service account") ]]; then
            echo "Service Account oluşturulmamış işlem sonlandırılıyor..."
            exit
        else
            # Servis Account mail adresinin ortam değişkenine aktarılması.
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
            gsutil iam ch serviceAccount:$SERVICE_ACCOUNT_EMAIL:objectAdmin gs://$BUCKET
            # Velero için namespace oluşturulması.
            NAMESPACE=velero
            kubectl create namespace $NAMESPACE
            # Kubernetes Service Account oluşturulması.
            KSA_NAME=velero
            kubectl create serviceaccount $KSA_NAME --namespace $NAMESPACE
            # Kubernetes Service Account'unun Google Service Account üyesi yapılması.
            gcloud iam service-accounts add-iam-policy-binding $GSA_NAME@$PROJECT_ID.iam.gserviceaccount.com --role roles/iam.workloadIdentityUser --member "serviceAccount:$PROJECT_ID.svc.id.goog[$NAMESPACE/$KSA_NAME]" 
            kubectl annotate serviceaccount $KSA_NAME --namespace $NAMESPACE iam.gke.io/gcp-service-account=$GSA_NAME@$PROJECT_ID.iam.gserviceaccount.com
            # Velero binary dosyalarının indirilmesi.
            if [[ -z $(which velero) ]]; then
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
            velero install --provider gcp --plugins velero/velero-plugin-for-gcp:v1.5.0 --bucket $BUCKET --no-secret --sa-annotations iam.gke.io/gcp-service-account=$GSA_NAME@$PROJECT_ID.iam.gserviceaccount.com --backup-location-config serviceAccount=[$GSA_NAME]@[$PROJECT_ID].iam.gserviceaccount.com

        fi


    else
        echo "Kurulumdan çıkılıyor..."
        exit
    fi
#-----------------------------------------------------------------------------------------------------------------------------------
