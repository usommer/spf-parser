# spf-parser
SPF-Parsing Script to get ipv4 addresslists

This script will generate a usable maps file for Postfix Postscreen to avoid Retry loop delays if using any kind of greylisting.

Some larger provider tend to use new IP addresses for every delivery attempt which confuses greylisting and postscreen.

So its a good idea to execept them from greylisting.


This script can be run as a daily cronjob as there seems to be much fluctuation in SPF records of larger ISPs.
