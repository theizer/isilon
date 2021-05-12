#Launch DemoCenter lab HOL-0543

#################License PS1
isi license add --evaluation=SMARTCONNECT_ADVANCED

###hit q and yes to accept eula

#################Join to AD

isi auth ads create demo.local administrator --password=Password123!
isi auth ads list

##################Create new Access Zone

###In WebUI - create AZ1 and add demo.local auth provider


##################Setup SmartConnect

###CLI or WebUI

isi network subnets modify groupnet0.subnet0 --sc-service-addr=192.168.1.100 --sc-service-name=ssip-isilon.demo.local
isi network pools create --id=groupnet0:subnet0:pool1 --ranges=192.168.1.60-192.168.1.80  --access-zone=az1  --alloc-method=dynamic  --ifaces=1-3:ext-1 --sc-subnet=subnet0  --sc-dns-zone=mp.demo.local    --description=mp_pool

##################Setup DNS

###GO to windows DNS
-go to the demo.local zone
-Add A record ssip-isilon  192.168.1.100
-Add NS record mp    --> ssip-isilon.demo.local
-Test SCzone:
nslookup mp.demo.local 192.168.1.2


-open PowerShell prompt from Start Menu
Add-DnsServerZoneDelegation -Name "demo.local" -ChildZoneName "mp" -NameServer "ssip-isilon.demo.local" -IPAddress 192.168.1.100

###Test SCzone:
-go to linux host and test
nslookup mp.demo.local 192.168.1.2

#################  on isilon make base mp directory

mkdir -p /ifs/az1/mp
chmod 777 /ifs/az1/mp
touch /ifs/az1/mp/this_is_isilon.txt
chmod 777 /ifs/az1/mp/this_is_isilon.txt
cd /ifs/az1/mp
ls -al 

#################  highlight Isilon permission model and the use of -le and -len

ls -le this_is_isilon.txt
ls -len this_is_isilon.txt

################# create SMB share

isi smb shares create --zone=az1 --path=/ifs/az1/mp --name=mp --description=mp_test_share
isi smb share view mp --zone=az1
isi smb shares permission modify mp --zone=az1 --permission-type=allow --permission=full --wellknown=Everyone
isi smb shares permission modify mp --zone=az1 --wellknown=Everyone --run-as-root

isi smb shares permission list mp --zone=az1

#################  connect to smb share

Windows explorer via \\mp.demo.local\mp

Create a file named smb.txt and edit it

Look at the permissions in win explorer
Compare to this_is_isilon.txt permissions

Compare the permissions of smb.txt from the isilon cli


##################  create nfs export

isi nfs exports create --path=/ifs/az1/mp/ --map-root=root  --zone=az1 --description=mp_test_export
isi nfs exports list --zone=az1

isi nfs exports view --id=1 --zone=az1

################## mount nfs export from linux host hdfs1

mkdir /mnt/isilon-mp
mount -t nfs mp.demo.local:/ifs/az1/mp /mnt/isilon-mp
mountstats
cd /mnt/isilon-mp
ls -al

###create a file nfs.txt,  edit it, look at the permissions
ls -al
vi nfs.txt
ls -al
cat nfs.txt

###################   review mp file access to the files created and edited via different protocols

from Win Explorer:
-open smb.txt  add some text similar to smb-edit, save and exit
-open nfs.txt  add some text similar to smb-edit, save and exit

from nfs host:
-vi nfs.txt  add some text similar to nfs-edit, save and exit
-vi smb.txt  add some text similar to nfs-edit, save and exit

then review all your updates from Win Explorer & nfs and Isilon CLI



Some things we can talk about here are:
-run as root on the smb share
-acl on smb file, posix on nfs file
-it all works here b/c of root user



###################  Bonus!

#####  create new linux user

# adduser jwick
#passwd jwick
#usermod -aG wheel jwick

### duplicate hdfs0 session in royal TS and change username to jwick
Connect to new session as jwick
# cd /mnt/isilon-mp
# ls -al
# touch posix.txt
# ls -al
 notice user and group difference for posix.txt
# ls -aln

Notice jwick UID GID is 1001

###compare permissions form windows explorer

Notice fake SID ending in 1001

### look at permissions from isilon

### back on linux host…. 

Chmod 775 posix.txt

Compare permissions with windows explorer -- notice the Everyone group now has read/execute

In windows explorer - edit the permissions of posix.txt to give Everyone modify rights and Domain Admins full control

Compare permissions on the linux host
Is that posix real?
 
Compare the permissions on the isilon for posix.txt
What changed?
 

###back on linux host

# chmod 774 posix.txt
# ls -l posix.txt
Did it change the mode bits? 
What about the acl?

Compare permissions is win explorer.
Compare on isilon
It merged the change with the ACL…Everyone now has Read Only

What if I change the ACL policy to deny?
##change ACL policy to deny

### back on linux host
# chmod 777 posix.txt

Change ACL policy to ignore

### back on linux host
# chmod 777 posix.txt
# ls -l posix.txt
Did it actually work?? (nope)

###on the isilon cli
#chmod -b 774 posix.txt
#ls -le posix.txt
File is now back to posix authoritative

###back on linux host
# chmod 777 posix.txt
# ls -l posix.txt
Did it actually work?? (looks like it)

Compare on the isilon and in windows explorer

############ enable RFC2307 and add UID GID to jwick account
 # isi auth mapping token "DEMO\jwick"

Notice his UID/GID are fake but his SID is real
Now enable RFC 2307

Isilon WebUI - enable RFC2307
 AD users and computers…
View --> Advanced features
User john wick --> properties --> attribute editor --> uidNumber ==>1001  APPLY OK

###on isilon cli

# isi auth mapping token "DEMO\jwick"
Notice his UID has now changed to match his linux UID

##now let's look at our posix.txt permissions

#ls -le posix.txt
Notice "DEMO\jwick" is now the owner! … the file is still posix authoritative!
