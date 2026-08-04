cp .bashrc ~/
ln -s ~/.bashrc ~/.profile
/QOpenSys/pkgs/bin/yum install -y git tn5250 service-commander mapepire-server rsync ibmichroot nano tobi

# Create the application library if it does not already exist (CPF2111 = already exists, safe to ignore)
system "CRTLIB LIB(TODOLIB)" 2>/dev/null || true
