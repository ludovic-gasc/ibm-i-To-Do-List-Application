# PS1: Shell prompt format
PS1="\e[1;34m[\u@\h \W]\$ \e[m"
export PS1
# PATH: All PASE binaries are in /QOpenSys/pkgs/bin
PATH=/QOpenSys/pkgs/bin:$PATH
export PATH
# LANG: some tools (for example: tmux) need UTF-8 charset
LANG=EN_US.UTF-8
export LANG