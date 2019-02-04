#!/bin/bash
#########################################################################################


#  ad88888ba  88         88        88 88888888ba  88b           d88         88            
# d8"     "8b 88         88        88 88      "8b 888b         d888         88            
# Y8,         88         88        88 88      ,8P 88`8b       d8'88         88            
# `Y8aaaaa,   88         88        88 88aaaaaa8P' 88 `8b     d8' 88         88 8b,dPPYba, 
#   `"""""8b, 88         88        88 88""""88'   88  `8b   d8'  88         88 88P'    "8a
#         `8b 88         88        88 88    `8b   88   `8b d8'   88         88 88       d8
# Y8a     a8P 88         Y8a.    .a8P 88     `8b  88    `888'    88 88,   ,d88 88b,   ,a8"
#  "Y88888P"  88888888888 `"Y8888Y"'  88      `8b 88     `8'     88  "Y8888P"  88`YbbdP"' 
#                                                                              88         
#
#                                                                              88    
# version: 0.3 / date: 20190205 

# HOW TO RUN THE PROGRAM
# 1) log in as root in the MASTER node 
# 2)copy this file and slurm-17.11.7.tar.bz2 into 
#   cp slurm-17.11.7.tar.bz2 ~/
#   cp AutomaticMungeSlurmInstallation.sh ~/
# 3) launch this script
# cd ~/
#   chmod -R 777 AutomaticMungeSlurmInstallation*
# ./AutomaticMungeSlurmInstallation.sh

# 4) the commands used in this script suppose that the IP address are as follows: 

# HOST NAME           IP ADDRESS 
# alsenyPC1           193.168.70.206
# workstation1        193.168.70.208
# workstation2        193.168.70.209

# 5) in case you want to launch the script with different IPs numbers: 
# suppose you have 3 computes nodes with IP 193.168.246.121, 193.168.246.122, 193.168.246.123
# then you need to: 
# 	- replace all "193.168.70" with "193.168.246"
#	- replace all "208..209" with "121..123"

# in case of error and need of debugging this script
# launch 
# ./AutomaticMungeSlurmInstallation.sh 2>&1 | tee log.AutomaticSlurmInstallation 
# and in log.AutomaticSlurmInstallation 
# search "Slurm RMPS build completed"
# start debugging from there, usually the previous part has no issues.

# NOTE: 
# 1) we suppose to launch all the following commands as root in the MASTER node of the cluster 
# 2) we suppose that ssh scp command can be executed between master and compute nodes WITHOUT password
# 3) you can skip the commands in the "# OPTIONAL" "# OPTIONAL END" sections, by setting to 0 the following variable :
#OptionalPackages=1 # install the optional packages 
OptionalPackages=0 # do not install the optional packages 


###################################################################################

# entering MASTER NODE home directory 
cd ~/

# remove previous slurm and munge installations if present. 
# cleaning in MASTER node : 
rm -rf rpmbuild/ slurm_rpms/
rm -rf /var/spool/mail/munge
systemctl stop munge
systemctl stop slurmd
systemctl stop slurmctld
yum remove mariadb-server mariadb-devel -y
yum remove slurm munge munge-libs munge-devel -y

# double check kill munge and slurm processes
pkill -f munge
pkill -f slurm
userdel -r slurm
userdel -r munge
# deleting residual slurm and munge lines in the /etc/group file:
sed -i '/slurm/d' /etc/group
sed -i '/munge/d' /etc/group

echo "Removing Previous Slurm and Munge Installations"
# cleaning in COMPUTE nodes : 
for i in {208..209}; do
  ssh root@193.168.70.$i yum remove mariadb-server mariadb-devel -y
  ssh root@193.168.70.$i yum remove slurm munge munge-libs munge-devel -y
  ssh root@193.168.70.$i systemctl stop munge
  ssh root@193.168.70.$i systemctl stop slurmd
  ssh root@193.168.70.$i systemctl stop slurmctld  
  ssh root@193.168.70.$i pkill -f munge
  ssh root@193.168.70.$i pkill -f slurm
  ssh root@193.168.70.$i rm -rf /var/spool/mail/munge
  ssh root@193.168.70.$i userdel -r slurm
  ssh root@193.168.70.$i userdel -r munge
  ssh root@193.168.70.$i sed -i '/slurm/d' /etc/group
  ssh root@193.168.70.$i sed -i '/munge/d' /etc/group
done

echo "Disabling Firewall"
# disable FIREWALL in every node
systemctl stop firewalld
systemctl disable firewalld
for i in {208..209}; do
  ssh root@193.168.70.$i systemctl stop firewalld
  ssh root@193.168.70.$i systemctl disable firewalld
done


echo "Disabling SELINUX"
# disable SELINUX on ALL nodes 
# we use >> sed to search for "SELINUX=" line and replace it with SELINUX=disabled
sed -i 's/SELINUX=.*/SELINUX=disabled/g' /etc/selinux/config
for i in {208..209}; do
  ssh root@193.168.70.$i sed -i 's/SELINUX=.*/SELINUX=disabled/g' /etc/selinux/config
done


# OPTIONAL SECTION from French cluster SCTL file. 
if [ $OptionalPackages = 1 ]
then

  # UPDATE SYSTEM 
  # master 
  yum -y update
  # compute nodes
  for i in {208..209}; do 
    ssh root@193.168.70.$i yum -y update
    echo "Yum update completed on node $i"
  done

  # Install EPEL packages on Master node 
  # copying this packages list from the french cluster installation: 
  yum -y install libconfuse clustershell imlib2 openbox-libs pyxdg openbox obconf nedit
  yum -y install ganglia ganglia-gmond rrdtool ganglia-gmetad collectl 
  yum -y install nagios-common nagios nagios-plugins nagios-plugins-all nrpe nagios-plugins-nrpe qstat
  yum -y install fio fping nethogs iftop filebench nfsometer
  yum -y install swig tigervnc tigervnc-server numactl-devel
  # additional packages optional from french cluster profiling script: 
  yum -y install pax oddjob sgpio device-mapper-persistent-data samba-winbind certmonger pam_krb5 krb5-workstation perl-DBD-SQLite rsh rsh-server libXmu xorg-x11-xauth xorg-x11-fonts-misc libxkbfile xorg-x11-xkb-utils xkeyboard-config libXdmcp tigervnc-server tigervnc xorg-x11-twm libXpm libXaw xterm libXp openmotif xorg-x11-fonts-ISO8859-1-75dpi mpfr cpp ppl cloog-ppl gcc kernel-devel samba unix2dos unique zlib-devel xfsprogs xorg-x11-apps screen lm_sensors-libs net-snmp-libs OpenIPMI-libs OpenIPMI ipmitool patchutils compat-glibc-headers-2.5 libgcc.i686 nss-softokn-freebl.i686 glibc.i686compat-db42 compat-db compat-libcap1 compat-glibc-2.5 compat-expat1 compat-libgfortran-41compat-openldap compat-libf2c-34 compat-libstdc++-33 compat-readline5 compat-libtermcap compat-libstdc++-296 libstdc++.i686 apr perl-Error perl-Git git apr-util xcb-util pakchois neon subversion startup-notification ncurses-devel swig numactl-devel xorg-x11-proto-devel libXxf86misc libdmx libXxf86dga xorg-x11-utils m17n-db m17n-db-datafiles m17n-lib emacs-common libIDL ORBit2 xinetd libcroco sgml-common GConf2 libgsf librsvg2 libotf emacs binutils-devel bison readline-devel tcl tk rpm-build gnome-keyring libbonobo libart_lgpl freetype-devel fontconfig-devel libglade2 libgnomecanvas gnome-icon-theme redhat-menus avahi-glib gnome-vfs2 poppler-glib pygobject2 pygtk2 gnome-python2 gnome-python2-gnomevfs dmz-cursor-themes glib2-devel libpng-devel exempi gtk2-engines gnome-themes system-icon-theme system-gnome-theme libgnome libbonoboui libgnomeui gnome-python2-gnome gnome-desktop glib-networking libsoup libexif mtools rarian rarian-compat smp_utils pixman-devel libcdio lrzsz libspectre evince-libs libXau-devel libxcb-devel libX11-devel libXrender-devel cairo-devel libXft-devel libXext-devel lockdev libatasmart udisks gnome-disk-utility-libs gvfs nautilus-extensions nautilus evince minicom pango-devel redhat-rpm-config tftp rcs telnet tftp-server dhcp lua-devel postgresql-libs php-common postgresql php-cli libtool-ltdl unixODBC apr-util-ldap httpd-tools httpd php postgresql-odbc postgresql-docs postgresql-serverphp-gd PyGreSQL python-psycopg2 lm_sensors nmap mysql libsepol-devel libselinux-devel keyutils-libs-devel libcom_err-devel krb5-devel openssl-devel libstdc++-devel perl-DBD-MySQL php-pdo php-pgsql mysql-server gcc-c++ mysql-devel gcc-gfortran nscd man-pages-fr libXinerama-devel python-simplejson plpa-libs liberation-fonts-common liberation-sans-fonts libvpx mozilla-filesystem redhat-bookmarks firefox byacc doxygen dos2unix flex libgcj deltarpm gettext-libs gettext-devel python-deltarpm gd python-reportlab pciutils-devel urlview environment-modules gdk-pixbuf2-devel python-imaging finger tokyocabinet systemtap-devel systemtap-client systemtap mutt perl-DBD-Pg atk-devel perl-YAML-Syck pam-devel cscope net-snmp-utils ctags libXfixes-devel libXi-devel libXcursor-devel libXcomposite-devel autoconf automake libxml2-devel graphviz libXrandr-devel gtk2-devel graphviz-tcl hwloc-devel diffstat indent libesmtp libsysfs libtool createrepo libmcpp mcpp xorg-x11-server-utils ConsoleKit-x11 xorg-x11-xinit vte gnome-terminal dejavu-lgc-sans-mono-fonts dejavu-sans-mono-fonts ftp python-markupsafe python-beaker python-mako libxklavier libgnomekbd libwacom-data libwacom sound-theme-freedesktop libcanberra libcanberra-gtk2 xorg-x11-server-common control-center-filesystem libXres libwnck notification-daemon libnotify system-setup-keyboard xorg-x11-server-Xorg xorg-x11-drv-wacom pulseaudio-libs-glib2 gnome-settings-daemon dbus-x11

  # installing optional packages in the COMPUTE NODES 
  for i in {208..209}; do
    ssh root@193.168.70.$i yum groupinstall -y client-mgmt-tools compat-libraries debugging basic-desktop desktop-debugging desktop-platform directory-client ftp-server fonts general-desktop graphical-admin-tools input-methods internet-applications internet-browser java-platform legacy-unix legacy-x nfs-file-server network-file-system-client office-suite print-client remote-desktop-clients server-platform server-policy web-server x11 kde-desktop
    ssh root@193.168.70.$i yum install -y xorg-x11-twm xorg-x11-apps mtools pax oddjob sgpio genisoimage wodim abrt-gui compat-gcc-44 compat-gcc-44-g77 compat-gcc-34-c++ certmonger pam_krb5 krb5-workstation gnome-pilot rsh rsh-server tcp_wrappers libXmu certmonger perl-CGI audit mesa-libGLU-devel kexec-tools bridge-utils device-mapper-multipath vnc-server xorg-x11-server-Xnest xorg-x11-server-Xvfb libsane-hpaio imake rsh-server tftp postfix tcl-devel libsysfs OpenIPMI ipmitool tix binutils-devel libXt-devel ncurses-devel qt-devel zlib-devel gnuplot perl-Time-HiRes perl-DBI kernel-devel gcc glibc-devel libtool bison flex zlib-devel libstdc++-devel gcc-c++ tcl-devel tk rpm-build gcc-gfortran openldap-clients valgrind-devel nscd nss-pam-ldapd lapack lapack-devel hwloc xorg-x11-apps xterm libstdc++.i686 compat-gcc-34-g77.x86_64 dstat screen OpenIPMI OpenIPMI-tools cmake scons boost numpy postgresql-libs python-devel python-matplotlib scipy libXp libXp-devel libXpm libXpm-devel dapl-devel PyOpenGL fluxbox libhugetlbfs libhugetlbfs-utils dejavu-lgc-sans-fonts dejavu-lgc-sans-mono-fonts dejavu-lgc-serif-fonts htop freeglut-devel freeglut-devel.i686 mesa-libGLU.i686 libXv.i686 libXrender.i686 fontconfig.i686 glib2.i686 libSM.i686 libpng.i686 perl-DBD-Pg yp-tools ypbind
    ssh root@193.168.70.$i yum install -y nagios-plugins-all nrpe collectl libcgroup mcelog dos2unix.x86_64 tofrodos.x86_64
    echo "optional Packages installation completed on node $i"
  done
fi


# OPTIONAL END 

# SCRATCH DIRECTORIES CREATION 
# Master node : creating scratch directory as done in the french cluster 
mkdir -p /shared_config
mkdir -p /scratch-mstr
# Compute nodes : setting local scratch directory as in the french cluster
for i in {208..209}; do 
  # setup local scratch
  ssh root@193.168.70.$i mkdir /scratch
  ssh root@193.168.70.$i chmod 777 /scratch
  ssh root@193.168.70.$i chmod +t /scratch
done


# BEFORE STARTING SLURM INSTALLATION PLEASE CHECK THAT IP, /etc/hostname/ and /etc/hosts ARE SET CORRECTLY 
# command to check the ip:     ip route get 8.8.8.8 | awk '{print $NF; exit}'
# the /etc/hosts in the minicluster test was of the form 
#    127.0.0.1 localhost.localdomain localhost4 localhost4.localdomain4
#    ::1 localhost localhost.localdomain localhost6 localhost6.localdomain6
#    193.168.70.209 toklap120

# MUNGE AND SLURM USER CREATION on ALL NODES 

# using tee command to create the tmp.sh script to create munge and slurm user in each of the compute nodes
tee tmp.sh << EOF
export MUNGEUSER=1127
groupadd -g $MUNGEUSER munge
useradd -m -c "MUNGE Uid 'N' Gid Emporium" -d /var/lib/munge -u $MUNGEUSER -g munge -s /sbin/nologin munge

export SLURMUSER=1128
groupadd -g $SLURMUSER slurm
useradd -m -c "SLURM workload manager" -d /var/lib/slurm -u $SLURMUSER -g slurm -s /bin/bash slurm
EOF

# first launch the script in the MASTER NODE :  
bash tmp.sh
# checking slurm and munge user creation 
# check
grep '1127' /etc/passwd
grep '1128' /etc/passwd

# creating slurm and munge user in each of the COMPUTE NODES: 
for i in {208..209}; do
  scp ~/tmp.sh root@193.168.70.$i:~/
  ssh root@193.168.70.$i bash ~/tmp.sh
  # checking 
  ssh root@193.168.70.$i grep '1127' /etc/passwd
  ssh root@193.168.70.$i grep '1128' /etc/passwd
done


######### MUNGE INSTALLATION ON ALL NODES 

yum install epel-release -y
yum install munge munge-libs munge-devel -y
yum install rng-tools -y

echo "Munge installation on Master node completed"

# ON MASTER NODE ONLY 
rngd -r /dev/urandom  # takashi's trick to avoid waiting too much
rm -rf /etc/munge/munge.key # removing old key
/usr/sbin/create-munge-key -r  # if question : overwrite key? yes
dd if=/dev/urandom bs=1 count=1024 > /etc/munge/munge.key
chown munge: /etc/munge/munge.key
chmod 400 /etc/munge/munge.key

echo "Munge key creation completed"

# propagate the created key to all other COMPUTE nodes: 
for i in {208..209}; do
  ssh root@193.168.70.$i yum install epel-release -y
  ssh root@193.168.70.$i yum install munge munge-libs munge-devel -y
  ssh root@193.168.70.$i rm -rf /etc/munge/munge.key # removing old key
  scp /etc/munge/munge.key root@193.168.70.$i:/etc/munge
  echo "Munge installation and munge key transfer on node $i completed"
done

# Start Munge services
tee ~/tmp.sh << EOF
chown munge: /etc/munge/munge.key
chmod 400 /etc/munge/munge.key
chown -R munge: /etc/munge/ /var/log/munge/
chmod 0700 /etc/munge/ /var/log/munge/
systemctl enable munge
systemctl start munge
munge -n   # Displays information about the MUNGE key
munge -n | unmunge  
remunge
EOF
# on MASTER NODE 
bash tmp.sh
echo "Master node munge service activated"
# on COMPUTE NODES 
for i in {208..209}; do
  scp ~/tmp.sh root@193.168.70.$i:~/
  ssh root@193.168.70.$i bash ~/tmp.sh
  echo "Compute node $i: munge service activated"
done


echo "Checking if SLURM prerequisites packages are present"
yum install rpm-build gcc openssl openssl-devel libssh2-devel pam-devel numactl numactl-devel hwloc hwloc-devel lua lua-devel readline-devel rrdtool-devel ncurses-devel gtk2-devel man2html libibmad libibumad perl-Switch perl-ExtUtils-MakeMaker -y
echo "Master node: SLURM prerequisites completed"
for i in {208..209}; do
  ssh root@193.168.70.$i yum install rpm-build gcc openssl openssl-devel libssh2-devel pam-devel numactl numactl-devel hwloc hwloc-devel lua lua-devel readline-devel rrdtool-devel ncurses-devel gtk2-devel man2html libibmad libibumad perl-Switch perl-ExtUtils-MakeMaker -y
  echo "Compute node $i: SLURM prerequisites completed"
done

yum install mariadb-server mariadb-devel -y
echo "Master node: mariadb installation completed"
for i in {208..209}; do
  ssh root@193.168.70.$i yum install mariadb-server mariadb-devel -y
  echo "Compute node $i: mariadb installation completed"
done



# On Master node 
echo "Installing some additional dependences"
yum install openssl openssl-devel pam-devel numactl numactl-devel hwloc hwloc-devel lua lua-devel readline-devel rrdtool-devel ncurses-devel man2html libibmad libibumad cpanm* -y
yum install wget gcc gcc-c++ hdf5 hdf5-devel -y
yum install libcurl-devel json-c-devel lz4-devel libibmad-devel libssh2-devel glibc-devel glib2-devel gtk2-devel -y
yum install rpmdevtools -y

# INSTALLING SLURM RPMs
cd ~
rpmbuild -ta slurm-17.11.7.tar.bz2
echo "Slurm RMPS build completed"

echo "sending Slurm RPMS to each of the compute nodes."
mkdir ~/slurm_rpms
mv rpmbuild/RPMS/x86_64/slurm*.rpm ~/slurm_rpms
for i in {208..209}; do
  scp -r ~/slurm_rpms root@193.168.70.$i:~/
done
echo "Slurm RPMS transfer to compute nodes completed."


# the order of installation is important 
# Error: Package: slurm-openlava-17.11.7-1.el7.x86_64
cd ~/slurm_rpms
yum install mailx -y
yum install -y slurm-17.11.7-1.el7*
yum install -y slurm-perlapi-17.11.7-1.el7*
yum install -y slurm-contribs-17.11.7-1.el7*
yum install -y slurm-devel-17.11.7-1.el7*
yum install -y slurm-example-configs-17.11.7-1.el7*
yum install -y slurm-libpmi-17.11.7-1.el7*
yum install -y slurm-openlava-17.11.7-1.el7*
yum install -y slurm-pam_slurm-17.11.7-1.el7*
yum install -y slurm-slurmctld-17.11.7-1.el7*
yum install -y slurm-slurmd-17.11.7-1.el7*  # installing slurmd also on the master since in our minicluster setting the master node can act like debug compute node
yum install -y slurm-slurmdbd-17.11.7-1.el7*
yum install -y slurm-torque-17.11.7-1.el7*
echo "Master node Slurm installation completed."
cd ~

for i in {208..209}; do
# similar as master node but we don't install slurm database and slurm controller daemon    
  ssh root@193.168.70.$i yum install mailx -y
  ssh root@193.168.70.$i yum install -y slurm_rpms/slurm-17.11.7-1.el7*
  ssh root@193.168.70.$i yum install -y slurm_rpms/slurm-perlapi-17.11.7-1.el7*  
  ssh root@193.168.70.$i yum install -y slurm_rpms/slurm-contribs-17.11.7-1.el7*
  ssh root@193.168.70.$i yum install -y slurm_rpms/slurm-devel-17.11.7-1.el7*
  ssh root@193.168.70.$i yum install -y slurm_rpms/slurm-example-configs-17.11.7-1.el7*
  ssh root@193.168.70.$i yum install -y slurm_rpms/slurm-libpmi-17.11.7-1.el7*
  ssh root@193.168.70.$i yum install -y slurm_rpms/slurm-openlava-17.11.7-1.el7*
  ssh root@193.168.70.$i yum install -y slurm_rpms/slurm-pam_slurm-17.11.7-1.el7*
  ssh root@193.168.70.$i yum install -y slurm_rpms/slurm-slurmd-17.11.7-1.el7*  
  ssh root@193.168.70.$i yum install -y slurm_rpms/slurm-torque-17.11.7-1.el7*
  echo "Compute node $i: Slurm installation completed."
done

# creating /etc/slurm/slurm.conf file 
#!/bin/bash
tee slurm.conf << EOF
# slurm.conf file generated by configurator easy.html. 
# Put this file on all nodes of your cluster. 
# See the slurm.conf man page for more information. 
# 
ControlMachine=alsenyPC1 
ControlAddr=193.168.70.206
#
# additional suggestions from https://wiki.fysik.dtu.dk/niflheim/Slurm_configuration#reboot-option
RebootProgram="/usr/sbin/reboot"
UnkillableStepTimeout=120
# end additional suggestions
# 
MailProg=/bin/mail 
MpiDefault=none 
#MpiParams=ports=#-# 
ProctrackType=proctrack/cgroup 
ReturnToService=1 
SlurmctldPidFile=/var/run/slurmctld.pid 
SlurmctldPort=8017 
SlurmdPidFile=/var/run/slurmd.pid 
SlurmdPort=8018 
SlurmdSpoolDir=/var/spool/slurm 
SlurmUser=slurm 
#SlurmdUser=root 
StateSaveLocation=/var/spool/slurm 
SwitchType=switch/none 
TaskPlugin=task/affinity 
#
# 
# TIMERS 
#KillWait=30 
#MinJobAge=300 
#SlurmctldTimeout=120 
#SlurmdTimeout=300 
# 
# 
# SCHEDULING 
FastSchedule=1 
SchedulerType=sched/backfill 
SelectType=select/cons_res 
SelectTypeParameters=CR_Core 
# 
# 
# LOGGING AND ACCOUNTING 
AccountingStorageType=accounting_storage/none 
ClusterName=cluster 
#JobAcctGatherFrequency=30 
JobAcctGatherType=jobacct_gather/none 
#SlurmctldDebug=3 
SlurmctldDebug=5
SlurmctldLogFile=/var/log/slurm/slurmctld.log 
#SlurmdDebug=3 
SlurmdLogFile=/var/log/slurm/slurmd.log 
# 
# 
# COMPUTE NODES
NodeName=workstation1 NodeAddr=193.168.70.208 CPUs=16 Sockets=1 CoresPerSocket=8 ThreadsPerCore=2 State=UNKNOWN
NodeName=workstation2 NodeAddr=193.168.70.209 CPUs=16 Sockets=1 CoresPerSocket=8 ThreadsPerCore=2 State=UNKNOWN
NodeName=alsenyPC1 NodeAddr=193.168.70.206 CPUs=8  Sockets=1 CoresPerSocket=4 ThreadsPerCore=2 State=UNKNOWN
PartitionName=production Nodes=workstation1,workstation2 Default=YES MaxTime=INFINITE State=UP
PartitionName=debug Nodes=alsenyPC1 Default=YES MaxTime=INFINITE State=UP
EOF
yes | cp -rf  slurm.conf /etc/slurm/
echo "Master node : slurm.conf file created"

# sending the slurm.conf file to each of the compute nodes 
for i in {208..209}; do
  scp /etc/slurm/slurm.conf root@193.168.70.$i:/etc/slurm
  echo "Compute node $i: slurm.conf file transferred"
done


# Creating the cgroup.conf file 

tee cgroup.conf << EOF
CgroupAutomount=yes
CgroupReleaseAgentDir="/etc/slurm/cgroup"

ConstrainCores=no
ConstrainRAMSpace=yes
TaskAffinity=no
ConstrainSwapSpace=yes
AllowedSwapSpace=0
EOF
yes | cp -rf  cgroup.conf /etc/slurm/
echo "Master node : cgroup.conf file created"

# sending the cgroup.conf file to each of the compute nodes 
for i in {208..209}; do
  scp /etc/slurm/cgroup.conf root@193.168.70.$i:/etc/slurm
  echo "Compute node $i: cgroup.conf file transferred"
done

# PERMISSIONS 
# on master node 
mkdir /var/spool/slurmctld/
chown slurm: /var/spool/slurmctld/
chmod 755 /var/spool/slurmctld/

mkdir /var/run/slurm
chown slurm: /var/run/slurm
chmod 755 /var/run/slurm

mkdir /var/log/slurm/
chown slurm: /var/log/slurm/
chmod 755 /var/log/slurm/

mkdir /var/spool/slurm
chown slurm: /var/spool/slurm
chmod 755 /var/spool/slurm

for i in {208..209}; do
  ssh root@193.168.70.$i mkdir /var/run/slurm
  ssh root@193.168.70.$i chown slurm: /var/run/slurm
  ssh root@193.168.70.$i chmod 755 /var/run/slurm
  ssh root@193.168.70.$i mkdir /var/log/slurm/
  ssh root@193.168.70.$i chown slurm: /var/log/slurm/
  ssh root@193.168.70.$i chmod 755 /var/log/slurm/
  ssh root@193.168.70.$i mkdir /var/spool/slurm
  ssh root@193.168.70.$i chown slurm: /var/spool/slurm
  ssh root@193.168.70.$i chmod 755 /var/spool/slurm
done

echo "Slurm Directories permission are now OK"

# on master node 
# note : since in slurm.conf we put "SlurmdPidFile=/var/run/slurmd.pid" 
sed -i -e 's/PIDFile=.*/PIDFile=\/var\/run\/slurmctld.pid/g' /usr/lib/systemd/system/slurmctld.service
# since we are giving the master node also the capability to be use as compute node:
sed -i -e 's/PIDFile=.*/PIDFile=\/var\/run\/slurm\/slurmd.pid/g' /usr/lib/systemd/system/slurmd.service

# on compute nodes : 
for i in {208..209}; do
  replacement="/var/run/slurm/slurmd.pid" 
  ssh root@193.168.70.$i sed -i -e 's@PIDFile=.*@PIDFile=replacement=@g' /usr/lib/systemd/system/slurmd.service
done

# on MASTER node : 
echo "Master node : starting Slurm Controller"
systemctl enable slurmctld
systemctl start slurmctld
systemctl status slurmctld.service
systemctl daemon-reload  

# on COMPUTE node : 
for i in {208..209}; do
  ssh root@193.168.70.$i systemctl enable slurmd.service
  ssh root@193.168.70.$i systemctl start slurmd.service
  ssh root@193.168.70.$i systemctl status slurmd.service
  echo "Compute node $i: Starting Slurm daemon"
done

echo "Starting Slurm daemon on master"
systemctl enable slurmd.service
systemctl start slurmd.service
systemctl status slurmd.service  

# TESTING 

echo "Testing CLUSTER status with sinfo command"
sinfo


