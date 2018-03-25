#!/bin/bash
# get all ipv4 IPs from SPF record including mx and domain IPs 
# usage: "getspf domain" or "getspf file" (list of domains)
# Author: Uwe Sommer
# 01/2018
# set -x
file="$1" 
reset=$(tput sgr0)
red=$(tput setaf 1)
e_error() { 
printf "${red}✖ %s${reset}\n" "$@"
}
if [ "$#" -le "0" ]; then
	e_error "Domainlist or domain argument required"
	exit 1 
	elif [ ! -f "$1" ]; then
	echo "$1" > /tmp/domain
	file=/tmp/domain 
fi 
getrecords () {
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
query_dns_spf(){
    if [[ $OSTYPE == darwin* ]]; then
    xargs dig txt +short +nodnssec |grep "v=spf" 
	else
    xargs -r dig txt +short +nodnssec |grep "v=spf"
fi
}
query_dns(){
    if [[ $OSTYPE == darwin* ]]; then
    xargs dig +short +nodnssec
    else
    xargs -r dig +short +nodnssec
fi
}
validate() { #list only ipv4 addresses
    awk -F'.' 'NF==4 && $1>0 && $1<256 && $2>=0 && $2<256 && $3>=0 && $3<256 && $4>=0'
}
## main spf query part
# get domain a records
ip1(){
    query_dns < "$file"
}
# get domain mx records
ip2(){
    xargs dig mx +short +nodnssec < "$file" | awk '{print $2}' |query_dns
}
## spf queries
results1(){
    xargs dig txt +short +nodnssec < "$file" |grep "v=spf" |getrecords
}
ip3(){
    results1 |getip4
}
ip4(){
    results1 |get_a |query_dns
}
# redirect queries
results_r2(){
    results1 |getredirect |getrecords
} 
ip5(){
    results_r2 |getip4
}
ip6(){
    results_r2 |get_a |query_dns
}
# include queries
results2(){
    results1 |getinclude |getrecords
}
ip7(){
    results2 |getip4
}
ip8(){
    results2 |get_a |query_dns
}
# level2 include queries
results3(){
    results2 |getinclude |getrecords
    results_r2 |getinclude |getrecords
}
ip9(){
    results3 |getip4
}
ip10(){
    results3 |get_a |query_dns
}
# level3 include queries
results4(){
    results3 |getinclude |getrecords
}
ip11(){
    results4 |getip4
}
ip12(){
    results4 |get_a |query_dns
}
# level4 include queries
results5(){
    results4 |getinclude |getrecords
}
ip13(){
    results5 |getip4
}
ip14(){
    results5 |get_a |query_dns
}
## display all results sorted
get_allips(){ 
for a in $(seq 1 14); do
        "ip$a" 
done
}
get_allips |sort -uV |validate
