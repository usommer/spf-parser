#!/bin/bash
# spf parser to grab netblocks (ipv4) 
# for domains in a given list (file)
# 
# read "a:" statements
# read "ipv4:" statements
# read "include:" statements and follow up to 4 level
# read "domain" a and mx records
#
# Uwe Sommer
# uwe@usommer.de
# 12/2017

## get mx records and domain a records
## filter for valid ip4 addresses:
## awk -F'.' 'NF==4 && $1 > 0 && $1<256 && $2<256 && $3<256 && $4<256 && !/\.\./'

# main function
getspf()
{
## input domainlist
file="domain-file"
# get domain a records
domain=$(xargs dig +short < "$file" |awk -F'.' 'NF==4 && $1 > 0 && $1<256 && $2<256 && $3<256 && $4<256 && !/\.\./')
echo "$domain"
# get domain mx records
mxips=$(xargs dig mx +short < "$file" | awk '{print $2}'| xargs dig +short |awk -F'.' 'NF==4 && $1 > 0 && $1<256 && $2<256 && $3<256 && $4<256 && !/\.\./')
echo "$mxips"

# spf queries
# remove quotes from output and validate ipv4
results1=$(xargs dig txt +short < "$file" |grep "v=spf" | awk '{for(i=1;i<=NF;i++){if ($i ~ /^ip4:|^include:|^a:/) {print $i}}}')
echo "$results1" |grep -e "^ip4:" | awk -F":" '{print $2}' |sed s/\"//g 
echo "$results1" |grep -e "^a:" |awk -F":" '{print $2}' |xargs dig +short |awk -F'.' 'NF==4 && $1 > 0 && $1<256 && $2<256 && $3<256 && $4<256 && !/\.\./'

# include queries
results2=$(echo "$results1" |grep -e "^include:" |awk -F":" '{print $2}' |xargs dig txt +short |grep "v=spf" | awk '{for(i=1;i<=NF;i++){if ($i ~ /^ip4:|include:|a:/) {print $i}}}' | sed s/\"//g ) 
echo "$results2" |grep -e "^ip4:" | awk -F":" '{print $2}' |sed s/\"//g
echo "$results2" |grep -e "^a:" |awk -F":" '{print $2}' |xargs dig +short |awk -F'.' 'NF==4 && $1 > 0 && $1<256 && $2<256 && $3<256 && $4<256 && !/\.\./'

# level2 include queries
results3=$(echo "$results2" |grep -e "^include:" |awk -F":" '{print $2}' |xargs dig txt +short |grep "v=spf" | awk '{for(i=1;i<=NF;i++){if ($i ~ /^ip4:|include:|a:/) {print $i}}}' | sed s/\"//g) 
echo "$results3" |grep -e "^ip4:" | awk -F":" '{print $2}' |sed s/\"//g
echo "$results3" |grep -e "^a:" |awk -F":" '{print $2}' |xargs dig +short |awk -F'.' 'NF==4 && $1 > 0 && $1<256 && $2<256 && $3<256 && $4<256 && !/\.\./'

# level3 include queries
results4=$(echo "$results3" |grep -e "^include:" |awk -F":" '{print $2}' |xargs dig txt +short |grep "v=spf" | awk '{for(i=1;i<=NF;i++){if ($i ~ /^ip4:|include:|a:/) {print $i}}}' | sed s/\"//g)
echo "$results4" |grep -e "^ip4:" | awk -F":" '{print $2}' |sed s/\"//g
echo "$results4" |grep -e "^a:" |awk -F":" '{print $2}' |xargs dig +short |awk -F'.' 'NF==4 && $1 > 0 && $1<256 && $2<256 && $3<256 && $4<256 && !/\.\./'

# level4 include queries
results5=$(echo "$results4" |grep -e "^include:" |awk -F":" '{print $2}' |xargs dig txt +short |grep "v=spf" | awk '{for(i=1;i<=NF;i++){if ($i ~ /^ip4:|include:|a:/) {print $i}}}' | sed s/\"//g)
echo "$results5" |grep -e "^ip4:" | awk -F":" '{print $2}' |sed s/\"//g
echo "$results5" |grep -e "^a:" |awk -F":" '{print $2}' |xargs dig +short |awk -F'.' 'NF==4 && $1 > 0 && $1<256 && $2<256 && $3<256 && $4<256 && !/\.\./'
}


# remove duplicate entries and write postfix mapsfile
getspf |sort |uniq | awk '{print $1"  permit"}' > postscreen-whitelists-cidr
cat postscreen-whitelists-cidr
