#!/bin/bash
dirName="elasticsearch"
device="/dev/sdb"
diskPercentage="100%FREE"
hostname="DTEKDENEME"
declare -a userArray=("dtekusr1" "dtekuser2") #1 kullanıcı
declare -a stringArray=("10.115.207.215 DTEKUYGELKP01 DTEKUYGELKP01.fw.dteknoloji.com.tr" "10.115.207.216 DTEKUYGELKP02 DTEKUYGELKP02.fw.dteknoloji.com.tr" "10.115.207.217 DTEKUYGELKP03 DTEKUYGELKP03.fw.dteknoloji.com.tr" "10.115.207.218 DTEKUYGELKP04 DTEKUYGELKP04.fw.dteknoloji.com.tr" "10.115.207.219 DTEKUYGELKP05 DTEKUYGELKP05.fw.dteknoloji.com.tr" "10.115.207.220 DTEKUYGELKP06 DTEKUYGELKP06.fw.dteknoloji.com.tr")

hosts(){
	for value in "${stringArray[@]}";do
		sed -i -e "2 a $value" /etc/hosts
	done
}

hostname(){
	hostnamectl set-hostname $hostname
	source ~/.bashrc
}
#adduser sorularını otomatize etmek lazım.
#Şifre.
#Key expire. < chage -l >
#Prod sunucu ise belirli bir karmaşık şifre lazım. Plain text olmaması gerekiyor!
users(){
	for user in "${userArray[@]}";do
	useradd $user
	done
}

users_to_sudoers(){
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
	lvcreate -n 01 -l $diskPercentage $dirName
	# XFS dosya sistemi olusturmak icin:
	mkfs.xfs /dev/mapper/$dirName-01
	# Diskin boot sonrasinda sistem tarafindan otomatik olarak eklenmesi icin (Bu satir root kullanici olmadigimiz zaman permission hatasi verir!):
	echo "/dev/mapper/$dirName-01     /$dirName 	xfs	defaults	0	0" >> /etc/fstab
	# fstab uzerindeki butun dosya sistemlerini mount etmek icin:
	mount -a
	# elasticsearch icin log klasoru olusturduk.
}

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



