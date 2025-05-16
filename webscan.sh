#! /bin/bash

#getting flags
while getopts 'u:o:t:' flag
do
	case ${flag} in
		u) url=${OPTARG} ;; #specify url of target
		o) folder=${OPTARG} ;; #specify folder to save to
		t) ip_addr=${OPTARG} ;;
		*) echo invalid flag ;;
	esac
done


#initialising
robots=0
echo target url: $url
domain=$(echo "$url" | awk -F'//' '{print $2}' | awk -F'/' '{print $1}')
echo "Domain: $domain"
echo creating folder $folder
mkdir $folder
echo

#==========================start of function declaration==========================
#port enumeration - check if any other ports open (quick scan)
port_scan() {
	#TODO - auto full scan specific port: get found ports, and scan them with -sC and -sV
	echo -=-=-=-=-=-=-=- starting port enumeration -=-=-=-=-=-=-=-
	if [ $1 == fast ]; then
		nmap -Pn -T5 $ip_addr -o ports.txt #scan only top 1000
		echo saved to ./$folder/ports.txt
	elif [ $1 == fast_all ]; then
		nmap -Pn -T5 -p- $ip_addr -o ports.txt #scan all ports but do not run script
		echo saved to ./$folder/ports.txt
	elif [ $1 == full ]; then
		nmap -sC -sV -p- -T5 $ip_addr -o ports_full.txt #scan all ports and run all checks (will take very long)
		echo saved to ./$folder/ports_full.txt
	elif [ $1 == udp ]; then
		nmap -sC -sV -sU -p- -T5 $ip_addr -o ports_udp.txt #scan all udp and run all checks (will take very long)
		echo saved to ./$folder/ports_udp.txt
	fi
	echo =========== port enum done ===========
	echo

}

#check robots.txt
robots() {
	echo -=-=-=-=-=-=-=- checking robots.txt -=-=-=-=-=-=-=-
	respond=$(curl -sLw "%{http_code}" $url/robots.txt -o ./$folder/full_robots.txt)
	if [[ $respond == 200 ]];
		then
			echo Found
		    	grep -i "^sitemap:" ./$folder/full_robots.txt | sed 's/Sitemap:\s*//i' >> ./$folder/robots.txt
			grep -i "^disallow:" ./$folder/full_robots.txt | sed 's/Disallow:\s*//i' >> ./$folder/robots.txt
			echo =========== robots.txt enum done ===========
			echo
			return 1
		else
			echo no robots.txt found
			return 0
	fi
	}

#directory enumeration - runs ffuf
directory() {
	echo -=-=-=-=-=-=-=- starting directory enumeration -=-=-=-=-=-=-=-
	if [ $robots -eq 1 ]; then #only if there were robots.txt file found
		ffuf -u $url/FUZZ -w ./$folder/robots.txt -o ./$folder/robots_directory.txt #check what is found in robots.txt is accessible
	fi
	ffuf -u $url/FUZZ -w /usr/share/wordlists/seclists/Discovery/Web-Content/raft-large-directories.txt -o ./$folder/directory.txt #check common directories
	echo saved to ./$folder/directory.txt
	echo =========== directory directory done ===========
	echo
}

#vhost enumeration - runs ffuf
vhost() {
	echo -=-=-=-=-=-=-=- starting vhost enumeration -=-=-=-=-=-=-=-
	ffuf -u $url -H HOST:FUZZ.$domain -w /usr/share/wordlists/seclists/Discovery/DNS/subdomains-top1million-110000.txt -t 20 -timeout 2 -maxtime 2  #check filter char first
	read -e -p "Enter filter by [(s)size , (w)ords , (l)ines]: " filter
	read -e -p "Enter number]: " number
	case $filter in
		s)
			filter=fs
			;;
		w)
			filter=fw
			;;
		l)
			filter=fl
			;;
		*)
			echo "wrong answer. skipping"
			return
	esac
	echo $filter $number
	ffuf -u $url -H HOST:FUZZ.$domain -$filter $number -w /usr/share/wordlists/seclists/Discovery/DNS/subdomains-top1million-110000.txt -t 100 -timeout 2 -o ./$folder/vhost.txt #check common vhost
	echo saved to ./$folder/vhost.txt
	echo =========== vhost enum done ===========
	echo
}


#subdomain enumeration - runs ffuf
subdomain() {
	echo -=-=-=-=-=-=-=- starting subdomain enumeration -=-=-=-=-=-=-=-
	ffuf -u http://FUZZ.$domain -w /usr/share/wordlists/seclists/Discovery/DNS/subdomains-top1million-110000.txt -t 20 -timeout 2 -maxtime 5 #check filter char first
	read -e -p "Enter filter by [(s)size , (w)ords , (l)ines]: " filter
	read -e -p "Enter number]: " number
	case $filter in
		s)
			filter=fs
			;;
		w)
			filter=fw
			;;
		l)
			filter=fl
			;;
		*)
			echo "wrong answer. skipping"
			return
	esac
	ffuf -u http://FUZZ.$domain -w /usr/share/wordlists/seclists/Discovery/DNS/subdomains-top1million-110000.txt -t 100 -timeout 2 -o ./$folder/subdomain.txt #check common subdomains
	echo saved to ./$folder/subdomain.txt
	echo =========== subdomain enum done ===========
	echo
}

#==========================end of function declaration==========================

#main
read -e -p "Do you want to run port scan (top 1000 TCP only)? [Y/n]: " -n 1 -r
if [[ $REPLY =~ ^[Yy]$ ]] || [[ -z $REPLY ]]; then
	if [[ -z $ip_addr ]] then
		read -e -p "Enter IP address to scan: " ip_addr
	fi
	port_scan fast

: <<'background nmap'
	#### TODO - future works: to run full nmap scan in background without affecting other commands
	#run all scan in bg (if selected)
	read -e -p "Do you want to run full port scan (all TCP ports)? [Y/n]: " tcp; tcp=${tcp:-Y}; [[ ${tcp^^} == "Y" ]]
	read -e -p "What about UDP ports)? [Y/n]: " udp; udp=${udp:-Y}; [[ ${udp^^} == "Y" ]]
		case $tcp-$udp in
			Y-Y)
				echo "running full tcp then udp scan in background"
				(port_scan full && port_scan udp) &
				;;
			Y-N)
				echo "running full tcp scan in background"
				port_scan full &
				;;
			N-Y)
				echo "running full udp scan in background"
				port_scan udp &
				;;
			*)
				echo "skipping..."
		esac
background nmap

else
	echo "Skipping port scan..."
fi



read -e -p "Do you want to run directory discovery? [Y/n]: " -n 1 -r
if [[ $REPLY =~ ^[Yy]$ ]] || [[ -z $REPLY ]]; then
	directory
else
	echo "Skipping directory discovery..."
fi

read -e -p "Do you want to run vhost discovery? [Y/n]: " -n 1 -r
if [[ $REPLY =~ ^[Yy]$ ]] || [[ -z $REPLY ]]; then
	vhost
else
	echo "Skipping vhost discovery..."
fi

read -e -p "Do you want to run subdomain discovery (may not yield result as not added into /etc/hosts)? [Y/n]: " -n 1 -r
if [[ $REPLY =~ ^[Yy]$ ]] || [[ -z $REPLY ]]; then
	subdomain
else
	echo "Skipping subdomain discovery..."
fi


