cd ../ # go to root of the repository
# inject commands, since we're running the shell through a different script
echo 'db.users.find().pretty()' | ./bin/mongo > ./ou-instance/exported_users.json

