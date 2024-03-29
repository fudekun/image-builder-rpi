#!/bin/bash
set -ex

KEYSERVER="hkp://ha.pool.sks-keyservers.net:80"

function clean_print(){
  local fingerprint="${2}"
  local func="${1}"

  nospaces=${fingerprint//[:space:]/} tolowercase=${nospaces,,}
  KEYID_long=${tolowercase:(-16)}
  KEYID_short=${tolowercase:(-8)}
  if [[ "${func}" == "fpr" ]]; then
    echo "${tolowercase}"
  elif [[ "${func}" == "long" ]]; then
    echo "${KEYID_long}"
  elif [[ "${func}" == "short" ]]; then
    echo "${KEYID_short}"
  elif [[ "${func}" == "print" ]]; then
    if [[ "${fingerprint}" != "${nospaces}" ]]; then printf "%-10s %50s\n" fpr: "${fingerprint}"
    fi
    # if [[ "${nospaces}" != "${tolowercase}" ]]; then
    #   printf "%-10s %50s\n" nospaces: $nospaces
    # fi
    if [[ "${tolowercase}" != "${KEYID_long}" ]]; then
      printf "%-10s %50s\n" lower: "${tolowercase}"
    fi
    printf "%-10s %50s\n" long: "${KEYID_long}"
    printf "%-10s %50s\n" short: "${KEYID_short}"
    echo ""
  else
    echo "usage: function {print|fpr|long|short} GPGKEY"
  fi
}


function get_gpg(){
  GPG_KEY="${1}"
  KEY_URL="${2}"

  clean_print print "${GPG_KEY}"
  GPG_KEY=$(clean_print fpr "${GPG_KEY}")

  if [[ "${KEY_URL}" =~ ^https?://* ]]; then
    echo "loading key from url"
    KEY_FILE=temp.gpg.key
    wget -q -O "${KEY_FILE}" "${KEY_URL}"
  elif [[ -z "${KEY_URL}" ]]; then
    echo "no source given try to load from key server"
#    gpg --keyserver "${KEYSERVER}" --recv-keys "${GPG_KEY}"
    apt-key adv --keyserver "${KEYSERVER}" --recv-keys "${GPG_KEY}"
    return $?
  else
    echo "keyfile given"
    KEY_FILE="${KEY_URL}"
  fi

  FINGERPRINT_OF_FILE=$(gpg --with-fingerprint --with-colons "${KEY_FILE}" | grep fpr | rev |cut -d: -f2 | rev)

  if [[ ${#GPG_KEY} -eq 16 ]]; then
    echo "compare long keyid"
    CHECK=$(clean_print long "${FINGERPRINT_OF_FILE}")
  elif [[ ${#GPG_KEY} -eq 8 ]]; then
    echo "compare short keyid"
    CHECK=$(clean_print short "${FINGERPRINT_OF_FILE}")
  else
    echo "compare fingerprint"
    CHECK=$(clean_print fpr "${FINGERPRINT_OF_FILE}")
  fi

  if [[ "${GPG_KEY}" == "${CHECK}" ]]; then
    echo "key OK add to apt"
    apt-key add "${KEY_FILE}"
    rm -f "${KEY_FILE}"
    return 0
  else
    echo "key invalid"
    exit 1
  fi
}

## examples:
# clean_print {print|fpr|long|short} {GPGKEYID|FINGERPRINT}
# get_gpg {GPGKEYID|FINGERPRINT} [URL|FILE]
echo "EDITION=$EDITION"

# device specific settings
HYPRIOT_DEVICE="Raspberry Pi"

# set up /etc/resolv.conf
DEST=$(readlink -m /etc/resolv.conf)
export DEST
mkdir -p "$(dirname "${DEST}")"
echo "nameserver 8.8.8.8" > "${DEST}"
echo "nameserver 8.8.4.4" >> "${DEST}"

# set up Docker CE repository
DOCKERREPO_FPR=9DC858229FC7DD38854AE2D88D81803C0EBFCD88
DOCKERREPO_KEY_URL=https://download.docker.com/linux/debian/gpg
get_gpg "${DOCKERREPO_FPR}" "${DOCKERREPO_KEY_URL}"

echo "deb [arch=armhf] https://download.docker.com/linux/debian stretch $DOCKER_CE_CHANNEL" > /etc/apt/sources.list.d/docker.list


RPI_ORG_FPR=CF8A1AF502A2AA2D763BAE7E82B129927FA3303E RPI_ORG_KEY_URL=http://archive.raspberrypi.org/debian/raspberrypi.gpg.key
get_gpg "${RPI_ORG_FPR}" "${RPI_ORG_KEY_URL}"

#rm -rf /etc/apt/sources.list
echo 'deb http://ftp.jaist.ac.jp/raspbian/ stretch main contrib non-free rpi' >> /etc/apt/sources.list.d/raspberrypi.list
echo 'deb http://mirrors.ustc.edu.cn/archive.raspberrypi.org/debian/ stretch main ui' >> /etc/apt/sources.list.d/raspberrypi.list
#echo 'deb http://archive.raspberrypi.org/debian/ stretch main ui' >> tee /etc/apt/sources.list.d/raspberrypi.list
#echo 'deb http://raspbian.raspberrypi.org/raspbian/ stretch main contrib non-free rpi' >> /etc/apt/sources.list.d/raspberrypi.list

# RDBOX ################################################
# install backport
get_gpg A1BD8E9D78F7FE5C3E65D8AF8B48AD6246925553 https://ftp-master.debian.org/keys/archive-key-7.0.asc
get_gpg 126C0D24BD8A2942CC7DF8AC7638D0442B90D010 https://ftp-master.debian.org/keys/archive-key-8.asc
get_gpg D21169141CECD440F2EB8DDA9D6D8F6BC857C906 https://ftp-master.debian.org/keys/archive-key-8-security.asc
get_gpg E1CF20DDFFE4B89E802658F1E0B11894F66AEC98 https://ftp-master.debian.org/keys/archive-key-9.asc
get_gpg 6ED6F5CB5FA6FB2F460AE88EEDA0D2388AE22BA9 https://ftp-master.debian.org/keys/archive-key-9-security.asc
echo "deb http://ftp.`curl -s ipinfo.io/country | tr "[:upper:]" "[:lower:]"`.debian.org/debian stretch-backports main contrib non-free" | tee /etc/apt/sources.list.d/stretch-backports.list

# our repo
curl -s https://bintray.com/user/downloadSubjectPublicKey?username=rdbox | apt-key add -
echo "deb https://dl.bintray.com/rdbox/deb stretch main
deb https://dl.bintray.com/rdbox/deb stretch rdbox" | tee /etc/apt/sources.list.d/rdbox.list
echo 'Package: *
Pin: release n=stretch
Pin: release c=rdbox
Pin: origin dl.bintray.com
Pin-Priority: 999' | tee /etc/apt/preferences.d/rdbox

# install kubeadmn
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
cat <<EOF >/etc/apt/sources.list.d/kubernetes.list
deb http://apt.kubernetes.io/ kubernetes-xenial main
EOF

# In a normal installation, the stable package is used preferentially.
echo 'APT::Default-Release "stable";' > /etc/apt/apt.conf.d/90rdbox
################################################ RDBOX #

# reload package sources
apt-get update
apt-get upgrade -y

# install WiFi firmware packages (same as in Raspbian)
apt-get install -y \
  --no-install-recommends \
  firmware-atheros \
  firmware-brcm80211 \
  firmware-libertas \
  firmware-misc-nonfree \
  firmware-realtek

# install kernel- and firmware-packages
apt-get install -y \
  --no-install-recommends \
  raspberrypi-bootloader \
  libraspberrypi0 \
  libraspberrypi-bin \
  raspi-config

# install special Docker enabled kernel
if [ -z "${KERNEL_URL}" ]; then
  apt-get install -y \
    --no-install-recommends \
    "raspberrypi-kernel=${KERNEL_BUILD}"
else
  curl -L -o /tmp/kernel.deb "${KERNEL_URL}"
  dpkg -i /tmp/kernel.deb
  rm /tmp/kernel.deb
fi

# enable serial console
printf "# Spawn a getty on Raspberry Pi serial line\nT0:23:respawn:/sbin/getty -L ttyAMA0 115200 vt100\n" >> /etc/inittab

# boot/cmdline.txt
echo "dwc_otg.lpm_enable=0 console=serial0,115200 console=tty1 root=/dev/mmcblk0p2 rootfstype=ext4 cgroup_enable=cpuset cgroup_enable=memory cgroup_memory=1 swapaccount=1 elevator=deadline fsck.repair=yes rootwait quiet init=/usr/lib/raspi-config/init_resize.sh" > /boot/cmdline.txt

# create a default boot/config.txt file (details see http://elinux.org/RPiconfig)
echo "
hdmi_force_hotplug=1
enable_uart=0
" > boot/config.txt

if [ $EDITION = "rdbox" ]; then
echo "# camera settings, see http://elinux.org/RPiconfig#Camera
start_x=1
disable_camera_led=1
gpu_mem=128
" >> boot/config.txt
elif [ $EDITION = "with_tb3" ]; then
echo "# camera settings, see http://elinux.org/RPiconfig#Camera
start_x=1
disable_camera_led=1
gpu_mem=128
" >> boot/config.txt
fi

# /etc/modules
echo "snd_bcm2835
" >> /etc/modules

# create /etc/fstab
echo "
proc /proc proc defaults 0 0
/dev/mmcblk0p1 /boot vfat defaults 0 0
/dev/mmcblk0p2 / ext4 defaults,noatime 0 1
" > /etc/fstab

# as the Pi does not have a hardware clock we need a fake one
apt-get install -y \
  --no-install-recommends \
  fake-hwclock

# install packages for managing wireless interfaces
apt-get install -y \
  --no-install-recommends \
  wpasupplicant \
  wireless-tools \
  crda \
  raspberrypi-net-mods

# add firmware and packages for managing bluetooth devices
apt-get install -y \
  --no-install-recommends \
  pi-bluetooth

# ensure compatibility with Docker install.sh, so `raspbian` will be detected correctly
apt-get install -y \
  --no-install-recommends \
  lsb-release \
  gettext

# install cloud-init
apt-get install -y \
  cloud-init \
  ssh-import-id

# Fix cloud-init package mirrors
sed -i '/disable_root: true/a apt_preserve_sources_list: true' /etc/cloud/cloud.cfg

# Link cloud-init config to VFAT /boot partition
mkdir -p /var/lib/cloud/seed/nocloud-net
ln -s /boot/user-data /var/lib/cloud/seed/nocloud-net/user-data
ln -s /boot/meta-data /var/lib/cloud/seed/nocloud-net/meta-data

# Fix duplicate IP address for eth0, remove file from os-rootfs
rm -f /etc/network/interfaces.d/eth0

# install docker-machine
curl -sSL -o /usr/local/bin/docker-machine "https://github.com/docker/machine/releases/download/v${DOCKER_MACHINE_VERSION}/docker-machine-Linux-armhf"
chmod +x /usr/local/bin/docker-machine

# install bash completion for Docker Machine
curl -sSL "https://raw.githubusercontent.com/docker/machine/v${DOCKER_MACHINE_VERSION}/contrib/completion/bash/docker-machine.bash" -o /etc/bash_completion.d/docker-machine

# install docker-compose
apt-get install -y \
  --no-install-recommends \
  python
curl -sSL https://bootstrap.pypa.io/get-pip.py | python
curl -sSL https://bootstrap.pypa.io/get-pip.py | python3
pip install "docker-compose==${DOCKER_COMPOSE_VERSION}"

# install bash completion for Docker Compose
curl -sSL "https://raw.githubusercontent.com/docker/compose/${DOCKER_COMPOSE_VERSION}/contrib/completion/bash/docker-compose" -o /etc/bash_completion.d/docker-compose

# install docker-ce (w/ install-recommends)
apt-get install -y --force-yes \
  --no-install-recommends \
  "docker-ce=${DOCKER_CE_VERSION}"

# install bash completion for Docker CLI
curl -sSL https://raw.githubusercontent.com/docker/docker-ce/master/components/cli/contrib/completion/bash/docker -o /etc/bash_completion.d/docker

echo "Installing rpi-serial-console script"
wget -q https://raw.githubusercontent.com/lurch/rpi-serial-console/master/rpi-serial-console -O usr/local/bin/rpi-serial-console
chmod +x usr/local/bin/rpi-serial-console



# RDBOX ##################################################
## rdbox
apt-get install -y \
  gdebi
gdebi -n `ls /tmp/deb-files/*.deb | grep rdbox_ | grep -v dbgsym | sort -r | head -1`
systemctl disable rdbox-boot.service
# our repo
apt-get install -y \
   softether-vpnbridge \
   softether-vpncmd 
apt-get install -y \
   hostapd

# Built in WiFi
## enable udev/rules.d
echo sed -i '/^KERNEL!="ath/c KERNEL!="ath*|msh*|ra*|sta*|ctc*|lcs*|hsi*|eth*|wlan*", \\' /etc/udev/rules.d/75-persistent-net-generator.rules

## suppress NIC barrel
echo 'SUBSYSTEM=="net", ACTION=="add", DRIVERS=="?*", ATTR{address}=="b8:27:eb:??:??:??", ATTR{dev_id}=="0x0", ATTR{type}=="1", KERNEL=="eth*", NAME="eth0"
SUBSYSTEM=="net", ACTION=="add", DRIVERS=="?*", ATTR{address}=="b8:27:eb:??:??:??", ATTR{dev_id}=="0x0", ATTR{type}=="1", KERNEL=="wlan*", NAME="wlan10"
' > /etc/udev/rules.d/70-persistent-net.rules

# enable daemon.json
mkdir -p /etc/docker
echo '{}' > /etc/docker/daemon.json

# Multi-hop Wi-Fi
## bridge and batman
apt-get install -y \
  bridge-utils \
  batctl
echo "batman-adv" >> /etc/modules

# install kubeadmn
## apt-get
apt-get install -y \
  apt-transport-https
apt-get install -y \
  kubelet=$KUBEADM_VERSION \
  kubeadm=$KUBEADM_VERSION \
  kubectl=$KUBEADM_VERSION \
  kubernetes-cni=$KUBERNETES_CNI_VERSION

# Security settings
## /etc/ssh/sshd_config
sed -i '/^#Port 22$/c Port 22' /etc/ssh/sshd_config
sed -i '/^#LoginGraceTime 2m$/c LoginGraceTime 10' /etc/ssh/sshd_config
sed -i '/^#PasswordAuthentication yes$/c PasswordAuthentication no' /etc/ssh/sshd_config
sed -i '/^#PermitRootLogin prohibit-password$/c PermitRootLogin no' /etc/ssh/sshd_config
echo "MaxAuthTries 2" >> /etc/ssh/sshd_config

# Locale settings
## For US JP
apt-get install -y \
  task-english \
  task-japanese
sed -i '/^# ja_JP.UTF-8 UTF-8$/c ja_JP.UTF-8 UTF-8' /etc/locale.gen
locale-gen

# Network settings
## /etc/sysctl.conf
echo '
net.ipv4.conf.all.forwarding = 1
net.ipv4.conf.default.forwarding = 1
net.ipv4.ip_forward = 1
net.ipv6.conf.all.forwarding = 1
net.ipv6.conf.default.forwarding = 1
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
' >> /etc/sysctl.conf


# deprecated
# It will run on Docker.
## dnsmasq
apt-get install -y \
  dnsmasq \
  resolvconf
systemctl disable dnsmasq.service
cp /etc/dnsmasq.conf /etc/rdbox/dnsmasq.conf.org
mv /etc/dnsmasq.conf /etc/dnsmasq.conf.org
touch /etc/rdbox/dnsmasq.conf
ln -s /etc/rdbox/dnsmasq.conf /etc/dnsmasq.conf

# enable auto update & upgrade
apt-get install -y \
  unattended-upgrades
echo -e 'APT::Periodic::Update-Package-Lists "1";\nAPT::Periodic::Unattended-Upgrade "1";\n' > /etc/apt/apt.conf.d/20auto-upgrades
echo -e 'Unattended-Upgrade::Origins-Pattern {
  origin=Raspbian,label=Raspbian;
  origin=Debian,label=Debian-Security;
  origin="Raspberry Pi Foundation",label="Raspberry Pi Foundation";
};
Unattended-Upgrade::Remove-Unused-Dependencies "true";
Unattended-Upgrade::Automatic-Reboot "false";
' > /etc/apt/apt.conf.d/50unattended-upgrades

# install NFS
apt-get install -y \
  nfs-kernel-server \
  nfs-common
sudo systemctl disable nfs-kernel-server.service

# install transproxy
apt-get install -y \
  transproxy
echo '# transproxy.conf
# vim: syntax=toml
# version: 0.0.1

## Log level, one of: debug, info, warn, error, fatal, panic
## default:info
## type:string
loglevel-local = "debug"

## Private DNS address for no_proxy targets (IP[:port])
## default:""(empty string)
## type:string
private-dns = ""

## Public DNS address (IP[:port]) Note: Your proxy needs to support CONNECT method to the Public DNS port, and the public DNS needs to support TCP
## default:""(empty string)
## type:string
public-dns = ""

## TCP Proxy dports, as "port1,port2,..."
## default:"22"
## type:string
tcp-proxy-dports = "22"

## TCP Proxy listen address, as "[host]:port"
## default:":3128"
## type:string
tcp-proxy-listen = ":3128"

## HTTP Proxy listen addres, as "[host]:port"
## default:":3129"
## type:string
http-proxy-listen = ":3129"

## HTTPS Proxy listen addres, as "[host]:port"
## default:":3130"
## type:string
https-proxy-listen = ":3130"

## DNS Proxy listen addres, as "[host]:port"
## default:":3130"
## type:string
dns-proxy-listen = ":3131"

## Explicit Proxy listen address for HTTP/HTTPS, as [host]:port Note: This proxy doesnt use authentication info of the http_proxy and https_proxy environment variables
## default:":3132"
## type:string
explicit-proxy-listen = ":3132"

## Explicit Proxy with auth listen address for HTTP/HTTPS, as [host]:port Note: This proxy uses authentication info of the http_proxy and https_proxy environment variables
## default:":3133"
## type:string
explicit-proxy-with-auth-listen = ":3133"

## Boot Explicit Proxies only"
## default:false
## type:bool
explicit-proxy-only = false

## Disable DNS-over-TCP for querying to public DNS
## default:false
## type:bool
dns-over-tcp-disabled = false

## Use DNS-over-HTTPS service as public DNS
## default:false
## type:bool
dns-over-https-enabled = true

## DNS-over-HTTPS endpoint URL
## default:"https://dns.google.com/resolve"
## type:string
dns-over-https-endpoint = "https://dns.google.com/resolve"

## DNS Listen on TCP
## default:true
## type:bool
dns-tcp = true

## DNS Listen on UDP
## default:true
## type:bool
dns-udp = true

## Disable automatic iptables configuration
## default:false
## type:bool
disable-iptables = false

## If true, use the local DNS resolver preferentially. If unknown hostname, transproxy will process it. (local DNS resolver, dnsmasq, systemd-resolved.....)
## default:false
## type:bool
prefer-local-dns-reolver = true

## Set to true to execute a transparent proxy on each computer.
## default:false
## type:bool
execute-standalone = true

## Disable tcps transproxy.
## default:false
## type:bool
disable-tcpproxy = true

## Disable dnss transproxy.
## default:false
## type:bool
disable-dnsproxy = false

## Specify additional parameters.(etc. "-i eth0")
## default:""(empty string)
## type:string
parameter-http-https-iptables = ""
' > /etc/transproxy/transproxy.conf


# For Helm(k8s)
apt-get install -y \
  snapd
ln -s /snap/bin/helm /usr/local/bin/helm

# For Network Debug
apt-get install -y \
  dnsutils \
  traceroute

## For ansible
apt-get install -y \
  libffi-dev \
  python3-crypto \
  build-essential \
  fakeroot \
  zlib1g \
  libssl-dev \
  python3-dev
# For rdbox_cli
apt-get install -y \
  hwinfo
pip3 install -r /opt/rdbox/bin/requirements.txt
mkdir -p -m 777 /etc/ansible
echo '[ssh_connection]
ssh_args = -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null
[defaults]
retry_files_save_path = "/tmp"
' > /etc/ansible/ansible.cfg

# disable dhcpcd
systemctl disable dhcpcd.service

# for TB3 used by Tutorial
echo 'ATTRS{idVendor}=="0483" ATTRS{idProduct}=="5740", ENV{ID_MM_DEVICE_IGNORE}="1", MODE:="0666"' >> /etc/udev/rules.d/99-turtlebot3-cdc.rules
echo 'ATTRS{idVendor}=="0483" ATTRS{idProduct}=="df11", MODE:="0666"' >> /etc/udev/rules.d/99-turtlebot3-cdc.rules
echo 'ATTRS{idVendor}=="fff1" ATTRS{idProduct}=="ff48", ENV{ID_MM_DEVICE_IGNORE}="1", MODE:="0666"' >> /etc/udev/rules.d/99-turtlebot3-cdc.rules
echo 'ATTRS{idVendor}=="10c4" ATTRS{idProduct}=="ea60", ENV{ID_MM_DEVICE_IGNORE}="1", MODE:="0666"' >> /etc/udev/rules.d/99-turtlebot3-cdc.rules

systemctl disable systemd-resolved

cd ~

################################################ RDBOX #






# fix eth0 interface name
ln -s /dev/null /etc/systemd/network/99-default.link

# cleanup APT cache and lists
apt-get clean
rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# set device label and version number
echo "HYPRIOT_DEVICE=\"$HYPRIOT_DEVICE\"" >> /etc/os-release
echo "HYPRIOT_IMAGE_VERSION=\"$HYPRIOT_IMAGE_VERSION\"" >> /etc/os-release
cp /etc/os-release /boot/os-release
