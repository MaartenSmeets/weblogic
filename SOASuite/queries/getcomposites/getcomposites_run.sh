#! /bin/sh

wait_until()
{
startTime=$1
startSec=`date -d "today ${startTime}"`
echo "Now = `date`"
echo "Wait until ${startSec}"
startSec=`date -d "today ${startTime}" +%s`
nowSec=`date +%s`
waitSec=$(( ${startSec}-${nowSec} ))
[ ${waitSec} -gt 0 ] && echo "Wait ${waitSec} seconds" && sleep ${waitSec}
}

echo "`date` - Start shell script"
wait_until 12:30:00

echo "`date` - Start sqlplus script"
sqlplus /nolog <<e_sql
connect soainfra_username/soainfra_password
@getcomposites_create
@getcomposites_run
@getcomposites_drop
disconnect
exit
e_sql

echo "`date` - End sqlplus script"
exit 0
