#!/bin/bash
# Get IP lists from SPF Records for domains or list of domains
# Can be used with postfix to create a cidr Postscreen whitelist
#
# Author: Uwe Sommer sommer@netcon-consulting.com
# Stand:  25.05.2018
#
# get all ipv4 ips from SPF record including mx and domain IPs
# usage: "getspf domain" or "getspf file" (list of domains)
file="$1"
if [ "$#" -le "0" ]; then
	echo "domainlist as file or domain argument required"
	echo "Syntax: check-spf.sh domainlist Postfix-cidr-path(optional)"
	exit
elif [ ! -f "$1" ]; then
	echo "$1" > /tmp/domain
	file=/tmp/domain
fi
###################################################################################################
## dns functions
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
###################################################################################################
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
###################################################################################################
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
## remove invalid cidr ranges from cidr file
cleanup() {
for i in $(postmap -s cidr:"$cidrfile" 2>&1 >/dev/null |grep warning |awk '{print $7}' |tr -d ":"|sort -r); do
 sed -i "$i d" "$cidrfile"
# echo "line $i removed from $cidrfile"
done
}
###################################################################################################
## display all results sorted
if [ "$#" == "2" ]; then
cidrfile=$2
all_ips |sort -uV |validate |awk '{ print $1" permit"}' |column -t > "$cidrfile"
cleanup
else
all_ips |sort -uV |validate |awk '{ print $1 }' |column -t
echo "$(all_ips |sort -uV |validate |awk '{ print $1 }' |column -t |wc -l) lines"
fi
