cd ../ # go to root of the repository
# inject commands, since we're running the shell through a different script
echo 'db.users.countDocuments()' | ./bin/mongo > ./ou-instance/user_count.txt


