#!/bin/bash


##########
# Colors #
##########

RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[33m"
ENDCOLOR="\e[0m"


#####################
# Dir and file prep #
#####################

unlink /home/temp/siteclony
dir_date=$(date +'%m-%d-%Y_%X' | tr -d ' ')
DIR="/home/temp/siteclony_$dir_date"
mkdir $DIR
ln -s $DIR /home/temp/siteclony

OPTIONS_FILE="$DIR/domainlist.txt"
INFO_FILE="$DIR/info.txt"
ERROR_LOG="$DIR/error.log"
LOG="$DIR/siteclony.log"


#############
# Variables #
#############

# source
source_server=$(hostname)
source_domain=""
source_account=""
source_docroot=""
source_config=""
source_DB_name=""
source_DB_user=""
source_DB_pass=""

# target
target_server=$(hostname)
target_domain=""
target_account=""
target_docroot=""
target_config=""
target_DB_name=""
target_DB_user=""
target_DB_pass=""

#############
# Functions #
#############

# Pre clone info

get_deets() {

  source_docroot=$(awk -F "==|:" '{print $1, $6}' /etc/userdatadomains | egrep "^$source_domain " | cut -d " " -f 2)
  target_docroot=$(awk -F "==|:" '{print $1, $6}' /etc/userdatadomains | egrep "^$target_domain " | cut -d " " -f 2)
  
  if [ -z "$source_docroot" ]
  then
        echo -e "${RED}[ERROR] Unable to find the source document root in /etc/userdatadomains!${ENDCOLOR}\n"
        fail=1
  fi
  
  if [ $((fail)) -eq 1 ]
  then
  	echo -e "Exiting...\n"
          exit 0
  fi
  
  source_config="$source_docroot/wp-config.php"
  target_config="$target_docroot/wp-config.php"
  
  if [ ! -f "$source_config" ]
  then
        echo -e "${RED}[ERROR] Source docroot is not a WordPress installation${ENDCOLOR}\n"
        fail=1
  fi
  
  if [ $((fail)) -eq 1 ]
  then
  	echo -e "Exiting...\n"
          exit 0
  fi
  
  source_DB_name=$(grep DB_NAME $source_config | awk -F "'" '{print $4}')
  source_DB_user=$(grep DB_USER $source_config | awk -F "'" '{print $4}')
  source_DB_pass=$(grep DB_PASS $source_config | awk -F "'" '{print $4}')
   
  target_DB_name=$(grep DB_NAME $target_config 2>/dev/null | awk -F "'" '{print $4}')
  target_DB_user=$(grep DB_USER $target_config 2>/dev/null | awk -F "'" '{print $4}')
  target_DB_pass=$(grep DB_PASS $target_config 2>/dev/null | awk -F "'" '{print $4}')
  
  
  echo -e "${RED}SOURCE${ENDCOLOR}\n\nServer: $source_server\nDomain: $source_domain\nAccount: $source_account\nDocroot: $source_docroot\n\nDB name: $source_DB_name\nDB user: $source_DB_user\nDB pass: $source_DB_pass\n\n\n"

  echo -e "${GREEN}TARGET${ENDCOLOR}\n\nServer: $target_server\nDomain: $target_domain\nAccount: $target_account\nDocroot: $target_docroot\n\nDB name: $target_DB_name\nDB user: $target_DB_user\nDB pass: $target_DB_pass\n\n"

}


####################
# Domain Selection #
####################

max_domains=$(whmapi1 get_domain_info | grep " domain:" | wc -l)
n=1

# Prepare the list of options with all domains
for domain in $(whmapi1 get_domain_info | grep " domain:" | awk -F ": " '{print $2}') 
do
	echo "$n $domain OFF" >> $OPTIONS_FILE
	n=$(($n+1))
done

sed -i "1,/OFF/{s|OFF|ON|}" $OPTIONS_FILE


# Select the source domain
dialog --backtitle "Select the source domain" --radiolist "Select the source domain:" 30 40 $max_domains --file $OPTIONS_FILE 2> $DIR/out.tmp

source_domain=$(grep -wf $DIR/out.tmp $DIR/domainlist.txt | awk '{print $2}')
source_account=$(egrep "^$source_domain:" /etc/userdatadomains | awk -F " |==" '{print $2}')


# Remove the selected domain from the list 
sed -i "/^$(cat $DIR/out.tmp) /d" $OPTIONS_FILE


# Select the target domain
# Add the option to add a new domain and set it as default
sed -i "1 i\0 \"Add New Domain\" ON" $OPTIONS_FILE

dialog --backtitle "Select the target domain" --radiolist "Select the target domain:" 30 40 $(($max_domains-1)) --file $OPTIONS_FILE 2> $DIR/out.tmp


# Check if the "Add New Domain" option was selected
id=$(cat $DIR/out.tmp)

if [ $id -eq 0 ]
then

  # Ask for the new domain name
  dialog --backtitle "Choose a name for the new domain" --inputbox "Choose a name for the new domain " 8 60 2> $DIR/out.tmp
  
  target_domain=$(cat $DIR/out.tmp)
  
  #Check if the domain name is valid
  pattern="^([a-z0-9])(([a-z0-9-]{1,61})?[a-z0-9]{1})?(\.[a-z0-9](([a-z0-9-]{1,61})?[a-z0-9]{1})?)?(\.[a-zA-Z]{2,4})+$"
  
  if [[ $target_domain =~ $pattern ]]
  then
  
    # The domain name IS valid, continuing
    echo "$target_domain is a valid domain name!" >> $LOG
    
    # Check if the domain already exists on the server
    match=$(whmapi1 get_domain_info | grep " domain:" | awk -F ": " '{print $2}' | egrep "^$target_domain$")
  
    if [ -z $match ]
    then
    
      # The domain DOESN'T exist on the server, continuing
      echo "The domain doesn't yet exist on the server!" >> $LOG
      
      # User selection
      OPTIONS_FILE="$DIR/accountlist.txt"
      account_num=$(whmapi1 listaccts | grep user: | wc -l)
  
      n=1

      # Prepare the list of options with all accounts
      for account in $(whmapi1 listaccts | grep user: | awk -F ": " '{print $2}') 
      do
	      echo "$n $account OFF" >> $OPTIONS_FILE
    	  n=$(($n+1))
      done
  
      # Add the option to create a new account and set it as default
      sed -i "1 i\0 \"Create New Account\" ON" $OPTIONS_FILE

      dialog --backtitle "Select the target account" --radiolist "Select the target account:" 30 40 $account_num --file $OPTIONS_FILE 2> $DIR/out.tmp

  
      # Check if the "Create New Account" option was selected
      id=$(cat $DIR/out.tmp)
  
      if [ $id -eq 0 ]
      then
        
        # Creating the new account
        
        # Asking for the new account info
        random_pass=$(< /dev/urandom tr -dc _A-Z-a-z-0-9 | head -c${1:-24})
        suggested_username=$(awk -F. '{print $1}' <<< $target_domain)
        
        dialog --backtitle "Provide the information for the new account" --title "Create a new account" --form "New account information" 15 50 3 "Username:" 1 3 "$suggested_username" 1 15 25 25 "Password:" 3 3 "$random_pass" 3 15 25 25 2> $DIR/out.tmp
  
        selected_username=$(head -1 $DIR/out.tmp)
        selected_password=$(tail -1 $DIR/out.tmp)
  
        # Check if an account with the same username already exists
        match=$(whmapi1 listaccts | grep user: | awk -F ": " '{print $2}' | egrep "^$selected_username")
        
        if [ -z $match ]
        then
        
          # The username doesn't exist
          echo "The user $selected_username doesn't exist" >> $LOG
          
          # Checking if it's valid (not one of the reserved usernames)
          match=$(awk -F: '{print $1}' /etc/aliases | tr -d "#" | egrep "^$selected_username$")
          
          if [ -z $match ]
          then
          
            # It's not a reserved username, continuing
            echo "The username $selected_username is not a reserved alias!" >> $LOG
            target_username=$selected_username
            
            # Check if the password meets the requirements
            pw_strength=$(whmapi1 get_password_strength password="$selected_password" | grep strength: | awk -F ": " '{print $2}')
        
            MIN_PW_STRENGTH=$(whmapi1 getminimumpasswordstrengths | grep createacct | awk -F ": " '{print $2}')
        
            if [ $pw_strength -ge $MIN_PW_STRENGTH ]
            then
          
              # Both the password and username are valid, creating the account
              echo "The selected password is valid" >> $LOG
            
              ### Creating the account with the selected username and password
              whmapi1 createacct username="$target_username" domain="$target_domain" password="$selected_password" 2>> $ERROR_LOG 1>> $LOG
          
            else
          
              # The password is too weak, exiting
              clear
              echo "The selected password is too weak" | tee -a $ERROR_LOG
              exit 0
            
            fi
              
          else
          
            # It is a reserved username, exiting
            clear
            echo "The username $selected_username is a reserved alias!" | tee -a $ERROR_LOG
            exit 0
            
          fi
          
        else
        
          # The username is invalid, exiting
          clear
          echo "The user $selected_username already exists!" | tee -a $ERROR_LOG
          exit 0
          
        fi
        
      else
  
        # Creating the subdomain / addon domain
        
        # Prepping variables
        target_account=$(grep -wf $DIR/out.tmp $DIR/accountlist.txt | awk '{print $2}')
        
        main_domain=$(uapi --user=$target_account Variables get_user_information | grep domain: | awk -F ": " '{print $2}')
        
        vhost_domain="$target_domain.$main_domain"
        
        echo -e "\nTarget domain: $target_domain\nTarget account: $target_account\nTarget main domain: $main_domain\nTarget vhost domain: $vhost_domain\n\n" >> $LOG
        
        ### Creating the subdomain
        uapi --user="$target_account" SubDomain addsubdomain domain="$target_domain" rootdomain="$main_domain" 2>> $ERROR_LOG 1>> $LOG
        
        ### Creating the addon domain (if possible)
        whmapi1 create_parked_domain_for_user domain="$target_domain" username="$target_account" web_vhost_domain="$target_domain.$main_domain" 2>> $ERROR_LOG 1>> $LOG
  
      fi
      
    else 
      
      # The domain DOES exist on the server, EXITING
      clear
      echo "The domain already exists on the server!" | tee -a $ERROR_LOG
      exit 0
      
    fi
    
  else
  
    # The domain name is NOT valid, exiting
    clear
    echo "$target_domain is NOT a valid domain name!" | tee -a $ERROR_LOG
    exit 0
    
  fi
  
else

  target_domain=$(grep -wf $DIR/out.tmp $DIR/domainlist.txt | awk '{print $2}')
  target_account=$(egrep "^$target_domain:" /etc/userdatadomains | awk -F " |==" '{print $2}')
  
fi

# Remove the selected domain from the list 
sed -i "/^$(cat $DIR/out.tmp) /d" $OPTIONS_FILE

clear

get_deets