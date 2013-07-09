me="$( test -L $0 && echo $(readlink $0) || echo $0)"
mydir=$(dirname $me | sed -re "s|^.$|$(pwd)|" -e "s|^./|$(pwd)/|");

sphinx_port=19312
mysql_port=93306

sphinx_conf="$mydir/conf/sphinx.conf"

tmp_base="/tmp/sphinxse-test"
tmp_sphinx="$tmp_base/sphinx"
tmp_mysql="$tmp_base/mysql"

mysql_socket="$tmp_base/mysql/mysqld.sock"

mysql_pidfile="$tmp_mysql/mysql.pid"
sphinx_pidfile="$tmp_sphinx/sphinx.pid"

mysql_script_cmd="mysql -P $mysql_port -h localhost -S $mysql_socket -u root"

kill_server() {
	if [ -f $2 ]; then
		pid="$(cat "$2"  2> /dev/null)"
		if [ -d /proc/$pid ]; then
			echo -n "shutting down $1..."
        
			for t in $(seq 1 5) ; do
				kill -15 $pid
				sleep 1
 	 	 	 	test ! -d /proc/$pid && break
			done
                
			if [  -d /proc/$pid ]; then
				echo -n "killing..."
				kill -9 $pid
				sleep 2
			fi;
        
			echo "done"
		fi;
	fi;
}

shutdown_servers() {
	kill_server "searchd" $sphinx_pidfile	
	kill_server "mysqld" $mysql_pidfile	
	rm -rf $tmp_base
}

server_check() {
	m="1"
	for i in $(seq 1 60); do
		if [ -f $1 ] ;then
			if [ ! -z $1 ]; then
				m="0"
				break;
			fi
		fi
		sleep 0.5
	done;

	echo $m
}

cmd_work() {
	if [ "$1" -ne "0" ]; then
		echo $2 
		exit 1
	fi;
}

trap shutdown_servers 0 1 2 15

# init tmp dirs
mkdir -p $tmp_mysql
cmd_work $? "cannot create dir  $tmp_mysql"

mkdir -p $tmp_sphinx 
cmd_work $? "cannot create dir  $tmp_sphinx"

echo -n "starting mysql..."
#init mysql
mysql_install_db --user=$(whoami) --datadir=$tmp_mysql 2> /dev/null > /dev/null 

mysqld --user=$(whoami) --datadir=$tmp_mysql \
	--innodb-data-home-dir=$tmp_mysql \
	--innodb-log-group-home-dir=$tmp_mysql \
	--pid-file=$mysql_pidfile \
	--slow-query-log=/dev/null \
	--log-error=/dev/null \
	--general-log=/dev/null \
	--socket $mysql_socket \
	--port $mysql_port  2> /dev/null > /dev/null &

m=$(server_check $mysql_pidfile)
cmd_work $m "Error with mysqld"
echo  "up!"

echo -n "populating mysql..."
$mysql_script_cmd < $mydir/data/mysql-data.sql
cmd_work $? "Error with data script"
echo "done"

# Init sphinx
echo -n "starting sphinx..."
indexer --quiet --all -c $sphinx_conf
cmd_work $? "Error with indexer"

searchd -c $sphinx_conf --console -p $sphinx_port  2>&1 > /dev/null &
echo $! > $sphinx_pidfile

m=$(server_check $sphinx_pidfile)
cmd_work $m "Error with searchd"

sleep 3
echo "up!"

#testing
echo "let's test"
$mysql_script_cmd < $mydir/tests/engine.sql
cmd_work $? "Error testing engine"

echo "USE \`sphinxse-test\`;
ALTER TABLE \`sphinxse-test\` CONNECTION=\"sphinx://127.0.0.1:$sphinx_port/sphinx\";
" | $mysql_script_cmd 
cmd_work $? "Error setting sphinxse host:port"

$mysql_script_cmd -vvv < $mydir/tests/query.sql
cmd_work $? "Error testing script"

shutdown_servers
