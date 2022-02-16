# web-logs
Backup of access log from knihovna.pedf.cuni.cz

## Jak udělat HTML report:

    lua src/create_combined_log.lua < logs/counter.txt > logs/access_log
    goaccess --log-format='COMBINED' -a -d -f logs/access_log -o report.html
