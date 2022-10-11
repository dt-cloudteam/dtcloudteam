#!/bin/bash
#--------------------------------------------------------------------------------

# Üzerine düşünülmesi gerekenler:
# - Karmaşık ve PlainText olmayan bir şifre entegre edebilir miyiz?
# - lvcreate komutunda 01 yerine farklı bir isim vermeyi düşünürsek değeri değişkenle alabiliriz. Aldığımız taktirde LV ismine bağlı komutlarda değişkeni belirtmemiz gerekir.
# - mkfs komutunda oluşturacağımız dosya sistemini değişken olarak alabiliriz.

#--------------------------------------------------------------------------------


dirName="< uygulama_adi >" # Klasör için vereceğimiz isim.
device="/dev/sdb" # Eklenecek diskin ismi
diskPercentage="100%FREE" # Diskte kullanım için ayrılacak % miktarı.
hostname="< host_adi >"
declare -a userArray=("< kullanici_1 >" "< kullanici_2 >") #1 kullanıcı
declare -a hostArray=("111.111.111.111 deneme deneme.az.deneme.com.tr" "111.111.111.111 deneme2 deneme2.az.deneme2.com.tr")

hosts(){
	# Bu fonksiyon hostArray dizisinin her elemanını tek tek hosts dosyasının 2. satırına yazma işlemini yapar. Bir önceki eleman bir alt satıra kayar.
	for value in "${hostArray[@]}";do
		sed -i -e "2 a $value" /etc/hosts
	done
}

hostname(){
	# bu fonksiyon hostname güncelleme işlemini yapar.
	hostnamectl set-hostname $hostname
	source ~/.bashrc
}

users(){
	# Bu fonksiyon userArray dizisindeki her elemanı kullanıcı olarak sisteme ekler. Şifre süresini 365 gün olarak değiştirir.
	for user in "${userArray[@]}";do
	useradd $user
	chage -M 365 $user # Bir şifrenin yaşayabileceği maksimum süre. (Gün cinsinden.)
	done
}

users_to_sudoers(){
	# Bu fonksiyon userArray içerisindeki her elemanı sudoers dosyasının en alt satırına ekler.
	for user in "${userArray[@]}";do
		echo "$user	ALL=(ALL:ALL) NOPASSWD: ALL" >> /etc/sudoers
	done
}

disk_partition(){
	#Physical Volume olusturmak icin:
	pvcreate $device
	#Volume Group olusturmak icin:
	vgcreate $dirName $device
	# "/" klasoru icerisine dosya acmak icin:
	mkdir "/$dirName"
	# Volume Group adini parametre olarak vererek Logical Volume olusturmak icin:
	lvcreate -n 01 -l $diskPercentage $dirName # Buradaki $dirName vgcreate ile oluşturulan VG NAME değerine referanstır. 01 LV NAME değeridir.
	# XFS dosya sistemi olusturmak icin:
	mkfs.xfs /dev/mapper/$dirName-01
	# Diskin boot sonrasinda sistem tarafindan otomatik olarak eklenmesi icin (Bu satir root kullanici olmadigimiz zaman permission hatasi verir!):
	echo "/dev/mapper/$dirName-01     /$dirName 	xfs	defaults	0	0" >> /etc/fstab
	# fstab uzerindeki butun dosya sistemlerini mount etmek icin:
	mount -a
}

#Burada yapılması istenilmeyen işlemlerin başına diyez koyarak ayırabiliriz.
hosts
hostname
users
users_to_sudoers
disk_partition
apt update -y
apt upgrade -y
reboot now
#--------------------------------------------------------------------------------------------------------
# Scriptin birkaç sefer boot işleminden sonra çalışması için düzenlenmesi gereken alan.
#if [ ! -f /var/run/resume_reboot ];then
#	echo "Ilk calisma"
#	hosts
#	hostname
#	script="bash /home/salih/elasticsearch.sh"
#	echo "$script" >> ~/.bashrc
#	touch /var/run/resume_reboot
#	echo "Yeniden baslatiliyor"
#	reboot now
#else
#	echo "Reboot sonrasi calisma devam ediyor."
#	sed -i '/bash /home/salih/elasticsearch.sh/d' ~/.bashrc
#	rm -f var/run/resume_reboot
#	users
#	users_to_sudoers
#	disk_partition
#	apt update -y
#	apt upgrade -y
#	reboot now
#fi
#--------------------------------------------------------------------------------------------------------


