getspf() {
# get all ipv4 ips from SPF record including mx and domain IPs
# usage: "getspf domain" or "getspf file" (list of domains)
#
# uncomment debug switch:
# set -x
## default parameter for IP Lists from domains for creating a postscreen whitelist
file="$1"
if [ "$#" -le "0" ]; then
	echo "Domainlist or domain argument required"
	return 1
fi
## move domain parameter fo file
if [ ! -f "$1" ]; then
	echo "$1" > /tmp/domain
	file=/tmp/domain 
fi
## functions to reuse code
getrecords () {
    awk '{for(i=1;i<=NF;i++){if ($i ~ /^ip4:|include:|a:/) {print $i}}}' | sed 's/\"\ \"//g' |sed s/\"//g
}
getip4() {
    grep -e "^ip4:" | awk -F":" '{print $2}' |sed s/\"//g 
}
getinclude() {
    grep -e "^include:" |awk -F":" '{print $2}' |xargs dig txt +short |grep "v=spf" 
}
get_a() {
    grep -e "^a:" |awk -F":" '{print $2}'
}
validate() {
    awk -F'.' 'NF==4 && $1 > 0 && $1<256 && $2<256 && $3<256 && $4<256 && !/\.\./'
}
## main spf query part
# get domain a records
domain=$(xargs dig +short < "$file" |validate)
echo "$domain"
# get domain mx records
mxips=$(xargs dig mx +short < "$file" | awk '{print $2}'| xargs dig +short |validate)
echo "$mxips"
## spf queries
# remove quotes from output and validate ipv4
results1=$(xargs dig txt +short < "$file" |grep "v=spf" | getrecords) 
echo "$results1" |getip4 |validate
echo "$results1" |get_a |xargs dig +short |validate
# include queries
results2=$(echo "$results1" |getinclude| getrecords) 
echo "$results2" |getip4 |validate
echo "$results2" |get_a |xargs dig +short |validate
# level2 include queries
results3=$(echo "$results2" |getinclude| getrecords) 
echo "$results3" |getip4 |validate
echo "$results3" |get_a |xargs dig +short |validate
# level3 include queries
results4=$(echo "$results3" |getinclude| getrecords)
echo "$results4" |getip4 |validate
echo "$results4" |get_a |xargs dig +short |validate
# level4 include queries
results5=$(echo "$results4" |getinclude| getrecords)
echo "$results5" |getip4 |validate
echo "$results5" |get_a |xargs dig +short |validate
}
getspf "$1"
