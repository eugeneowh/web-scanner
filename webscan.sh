#! /bin/bash

#getting flags
while getopts 'u:o:' flag
do
	case ${flag} in
		u) url=${OPTARG} ;; #specify url of target
		o) folder=${OPTARG} ;; #specify folder to save to
		*) echo invalid flag ;;
	esac
done


#initialising
echo target url: $url
echo creating folder $folder
mkdir $folder
echo

#port enumeration - check if any other ports open (quick scan)
echo =========== starting port enumeration ===========
nmap -Pn -p- $url > ports.txt
echo saved to ./$folder/ports.txt
echo
echo =========== port enum done ===========
echo


#check robots.txt
echo =========== checking robots.txt ===========
respond=$(curl -sLw "%{http_code}" $url/robots.txt -o ./$folder/full_robots.txt)
if [[ $respond == 200 ]];
	then
		echo Found
            	grep -i "^sitemap:" ./$folder/full_robots.txt | sed 's/Sitemap:\s*//i' >> ./$folder/robots.txt
	        grep -i "^disallow:" ./$folder/full_robots.txt | sed 's/Disallow:\s*//i' >> ./$folder/robots.txt
	else
		echo no robots.txt found
fi
echo =========== robots.txt enum done ===========

#subdomain enumeration - runs dnsenum
echo =========== starting subdomain enumeration ===========

dnsenum --enum $url -r -f /usr/share/seclists/Discovery/DNS/subdomains-top1million-110000.txt > ./$folder/dnsenum.txt
echo saved to ./$folder/dnsenum.txt
echo
echo =========== subdomain enum done ===========
echo

#vhost enumeration - runs gobuster
echo =========== starting vhost enumeration ===========
gobuster vhost -u $url -w /usr/share/wordlist/seclists/Discovery/DNS/subdomains-top1million-110000.txt --append-domain > ./$folder/vhost.txt
echo saved to ./$folder/vhost.txt
echo
echo =========== vhost enum done ===========
echo

#directory enumeration - runs ffuf
echo =========== starting directory enumeration ===========
ffuf -u $url -w ./$folder/robots.txt > ./$folder/directory.txt #check what is found in robots.txt is accessible
ffuf -u $url -w /usr/share/wordlists/seclists/Discovery/Web-Content/raft-large-directories.txt >> ./$folder/directory.txt #check common directories
echo saved to ./$folder/directory.txt
echo
echo =========== vhost enum done ===========
echo
