#!/bin/bash
# Check logged-in users in Overleaf (not just those editing projects)

logfile="monitor-users-log.txt"

echo "=== Overleaf Logged-In Users ==="

# Count total logged-in users (users with active sessions)
logged_in_users=$(docker exec redis redis-cli EVAL "return #redis.call('keys', 'UserSessions:*')" 0)
echo "Total Logged-In Users: $logged_in_users"
echo "$(date '+%Y-%m-%d %H:%M:%S') | Total Logged-In Users: $logged_in_users" >> "$logfile"

# Count users actively editing projects
active_editors=$(docker exec redis redis-cli EVAL "local keys = redis.call('keys', 'clients_in_project:*'); local total = 0; for i=1,#keys do total = total + redis.call('scard', keys[i]) end; return total" 0)
echo "Users Actively Editing: $active_editors"
echo "$(date '+%Y-%m-%d %H:%M:%S') | Users Actively Editing: $active_editors" >> "$logfile"

# Count active projects with editors
active_projects=$(docker exec redis redis-cli EVAL "return #redis.call('keys', 'clients_in_project:*')" 0)
echo "Projects Being Edited: $active_projects"
echo "$(date '+%Y-%m-%d %H:%M:%S') | Projects Being Edited: $active_projects" >> "$logfile"

echo "=== Done Monitoring Users ==="
