#!/bin/bash
# Valid Target & Right number of commandline args?

usage="pass"

if [[ $# -ne 1 ]]; then
  echo "Please enter a branch name."
  echo
  exit
fi

host_type=`hostname | awk -F'.' '{print $2}'`
current_branch=`git rev-parse --abbrev-ref HEAD`
build_target="lijit-flowplayer-flash"
build_env="QA"
servers="NONE"
restart_cmd="NONE"
rcmd_option=""
today_is=`date`
package_type="deb"
servers="ad1q.pod1q.lijit.com,ad2q.pod1q.lijit.com,ad1q.pod2q.lijit.com,ad2q.pod2q.lijit.com"
#servers="ad1q.pod1q.lijit.com,ad1q.pod2q.lijit.com"
#servers="ad1q.pod2q.lijit.com,ad2q.pod2q.lijit.com"

if [ "$host_type" == "15c" ]; then

   build_env="PROD"
   restart_cmd="NONE"
   servers="NONE"

fi

if [ $current_branch = $1 ] ; then

   read -s -p "Please enter your password: " pass
   #updating source code and send git diffs
   echo $pass | sudo -S rm -v git.diff
   echo $pass | sudo -S touch git.previous
   echo $pass | sudo -S chmod 777 git.previous
   echo $pass | sudo -S touch git.diff
   echo $pass | sudo -S chmod 777 git.diff
   echo $pass | sudo -S git pull origin $current_branch
   echo $pass | sudo -S git pull origin $1
   echo $pass | sudo -S git push origin $current_branch

   gitsha=`cat git.previous`

   echo $pass | sudo -S -s git diff $gitsha git.diff
   echo $pass | sudo -S touch  git.previous
   echo $pass | sudo -S chmod 777 git.previous
   echo $pass | sudo -S -s git log -1 --pretty=format:%h > git.previous

   gitcurrent=`git log -1 --pretty=format:%h `

else
   echo "Your current branch is $current_branch."
   echo
   echo "You will need to checkout the $1 branch to run this command:"
   echo
   echo "    $0 $1"
   echo
   exit 1
fi

echo
hipchat_message="The following build is underway in $build_env: $build_target [$current_branch]"
hipchat_token="76b0aba2795ee6878a9ee91138dd8e"
hipchat_user="SCM-BUILD"
hipchat_room="609012"
echo $pass | sudo -S curl -d "room_id=$hipchat_room&from=$hipchat_user&message=$hipchat_message&color=yellow&notify=1" https://api.hipchat.com/v1/rooms/message?auth_token=$hipchat_token&format=json

#clean it and build it
echo "Removing previous debian packages."
echo $pass | sudo -S rm -rfv /usr/share/lijit-build/git/deb_packages/*;
echo "Running mvn clean to make sure all old artifacts are removed."
echo $pass | sudo -S mvn clean || exit 
echo $pass | sudo -S mvn clean install --also-make || exit

#grab the packages
if [ "$host_type" == "15c" ]; then
    deb_repo="/mnt/repo1/lijit/binary-amd64/" 
else
    deb_repo="/mnt/repo1q/lijit/binary-amd64/"
fi

if [ ! -d ~/deployment ]; then
   mkdir ~/deployment
else
  rm -rfv ~/deployment/*
 fi

echo "Gathering up freshly built debian packages."
# echo $pass | sudo -S cp -rv target/$build_target*.deb $deb_repo 
echo $pass | sudo -S cp -rv target/$build_target*.deb ../deb_packages 
cp -v /usr/share/lijit-build/git/deb_packages/$build_target*.$package_type ~/deployment
 
echo "Time for deployment:"

if  [[ $servers == "NONE" ]] ; then
   echo "No deployment set for this package"
   echo
else
   echo ------------------------------------------------------------------->>deployment.log
   echo ------- Pre Updated Versions $today_is>>deployment.log
   echo ------------------------------------------------------------------->>deployment.log
   rcmd -p $pass -c "dpkg -l |grep $build_target" -s ,$servers |grep $build_target>>deployment.log
   rcmd -p $pass -c "sudo dpkg -i ~/deployment/$build_target*.deb" -s ,$servers
   echo ------------------------------------------------------------------->>deployment.log
   echo "The $build_target ($gitcurrent) package was deployed to $servers">>deployment.log
   echo ------------------------------------------------------------------->>deployment.log 
fi

if  [[ $restart_cmd == "NONE" ]]; then
   echo "No restart defined for this package."
   echo
else
   rcmd -p $pass $rcmd_option -c "$restart_cmd" -s ,$servers;
fi

#HipChat Notification.

hipchat_token="76b0aba2795ee6878a9ee91138dd8e"
hipchat_user="SCM-BUILD"
hipchat_message="$build_target [$current_branch] -- has been deployed to these $build_env servers: $servers - Click here for the diff --> <a href=https://github.com/sovrn/$build_target/compare/$gitsha...$gitcurrent#files_bucket>$gitcurrent</a>"

if [ "$host_type" == "15c" ]; then
   hipchat_room="144533"
else
   hipchat_room="609012"
fi

echo $pass | sudo -S curl -d "room_id=$hipchat_room&from=$hipchat_user&message=$hipchat_message&color=green&notify=1" https://api.hipchat.com/v1/rooms/message?auth_token=$hipchat_token&format=json
echo
echo "All Done." 
sleep 3
echo
