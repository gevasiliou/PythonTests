#https://github.com/aanarchyy/bully

#Requirements: 
apt-get install "linux-headers-$(uname -r)"
apt-get install build-essential libpcap-dev aircrack-ng pixiewps

#Download : 
#git clone https://github.com/aanarchyy/bully
wget https://github.com/aanarchyy/bully/archive/master.zip && unzip master.zip

#Build:
cd bully-master/ && cd src/
make
sudo make install
