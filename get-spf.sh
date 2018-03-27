#!/bin/bash
# get all ipv4 IPs from SPF record including mx and domain IPs 
# usage: "getspf domain" or "getspf file" (list of domains)
# Author: Uwe Sommer
# 01/2018
reset=$(tput sgr0)
red=$(tput setaf 1)
e_error() { printf "${red}✖ %s${reset}\n" "$@"
}
file="$1"
if [ "$#" -le "0" ]; then
	e_error "Domainlist or domain argument required"
	exit 1
elif [ ! -f "$1" ]; then
	echo "$1" > /tmp/domain
	file=/tmp/domain 
fi
getrecords () { # get include:,a:,ip4: and redirect= from SPF Record
    sed 's/\"\ \"//g' |sed 's/\"//g' |awk '{for(i=1;i<=NF;i++){if ($i ~ /redirect=|^ip4:|include:|a:/) {print $i}}}' 
}
getip4() {
    grep -e "^ip4:" | awk -F":" '{print $2}' |sed s/\"//g 
}
getinclude() {
    grep -e "^include:" |awk -F ':' '{print $2}' |query_dns_spf 
}
getredirect() {
    grep -e "^redirect=" |awk -F '=' '{print $2}' |query_dns_spf 
}
get_a() {
    grep -e "^a:" |awk -F":" '{print $2}'
}
validate() { #list only ipv4 addresses, eliminate cnames
    awk -F'.' 'NF==4 && $1>0 && $1<224 && $2>=0 && $2<256 && $3>=0 && $3<256 && $4>=0'
}
query_dns_spf(){
    if [[ $OSTYPE == darwin* ]]; then
    xargs dig txt +short |grep "v=spf" 
    else
    xargs -r dig txt +short |grep "v=spf"
    fi
}
query_dns(){
    if [[ $OSTYPE == darwin* ]]; then
    xargs dig +short +nodnssec 
    else
    xargs -r dig +short +nodnssec
    fi
}
## main spf query part
results1(){ # spf queries
    xargs dig txt +short +nodnssec < "$file" |grep "v=spf" |getrecords
}
results_r2(){ # redirect queries
    results1 |getredirect| getrecords
} 
results2(){ # include queries
    results1 |getinclude |getrecords
}
results3(){ # level2 include queries
    results2 |getinclude |getrecords
    results_r2 |getinclude |getrecords
}
results4(){ # level3 include queries
    results3 |getinclude |getrecords
}
results5(){ # level4 include queries
    results4 |getinclude |getrecords
}
all_ips(){
    query_dns < "$file" # get Domain IP
    xargs dig mx +short +nodnssec < "$file" | awk '{print $2}'| query_dns # get MX IPs
    results_r2 |getip4 # get redirect ips
    results_r2 |get_a |query_dns #get redirect a records
    for a in $(seq 1 5); do
    results"$a" |getip4 
    results"$a" |get_a |query_dns
    done
}
## display all results sorted
all_ips |sort -uV |validate
