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
domain=$(echo "$url" | awk -F'//' '{print $2}' | awk -F'/' '{print $1}')
echo "Domain: $domain"
echo creating folder $folder
mkdir $folder
echo

#port enumeration - check if any other ports open (quick scan)
echo -=-=-=-=-=-=-=- starting port enumeration -=-=-=-=-=-=-=-
nmap -Pn -p- $url > ports.txt
echo saved to ./$folder/ports.txt
echo
echo =========== port enum done ===========
echo


#check robots.txt
echo -=-=-=-=-=-=-=- checking robots.txt -=-=-=-=-=-=-=-
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
echo ''

#directory enumeration - runs ffuf
echo -=-=-=-=-=-=-=- starting directory enumeration -=-=-=-=-=-=-=-
ffuf -u $url/FUZZ -w ./$folder/robots.txt -o ./$folder/robots_directory.txt #check what is found in robots.txt is accessible
ffuf -u $url/FUZZ -w /usr/share/wordlists/seclists/Discovery/Web-Content/raft-large-directories.txt -o ./$folder/directory.txt #check common directories
echo saved to ./$folder/directory.txt
echo
echo =========== vhost directory done ===========
echo

#vhost enumeration - runs ffuf
echo -=-=-=-=-=-=-=- starting vhost enumeration -=-=-=-=-=-=-=-
ffuf -u $url -H HOST:FUZZ.$domain -w /usr/share/wordlists/seclists/Discovery/DNS/subdomains-top1million-110000.txt -o ./$folder/vhost.txt #check common vhost
echo saved to ./$folder/vhost.txt
echo
echo =========== vhost enum done ===========
echo

#subdomain enumeration - runs ffuf
echo -=-=-=-=-=-=-=- starting subdomain enumeration -=-=-=-=-=-=-=-
ffuf -u http://FUZZ.$domain -w /usr/share/wordlists/seclists/Discovery/DNS/subdomains-top1million-110000.txt -o ./$folder/subdomain.txt #check common subdomains
echo saved to ./$folder/subdomain.txt
echo
echo =========== subdomain enum done ===========
echo






