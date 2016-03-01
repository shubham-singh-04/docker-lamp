LAMP container
=================

Overview
-------

There are two branches:

 * master - centos6
 * centos7 



Quick installation
------------------

1. `docker build --rm --no-cache=true -t lamp .`
2. The docker build sometimes fail due to network errors etc. Repeat
`docker build --rm -t lamp .` until the build succeeds.


3. Copy `env.list.template` to `env.list` and update. Do: `set -a; . env.list`

4. Start a container:

    docker run -t -i -p 8080:80 --restart="on-failure:10" \
    --link beservices:beservices -h lamp1 --name lamp1 lamp \
    /bin/bash -c "supervisord; export > /env; bash"

When using docker swarm:

    docker run -ti --restart="on-failure:10" --env-file=env.list \
    --net=net0 -h lamp1 --name lamp1 lamp \
    /bin/bash -c "supervisord; export > /env; bash"


5. Then start things up with: `supervisord`

6. Check the log files: `docker logs lamp`

Login to MySQL using phpMyAdmin at:
`http://localhost:PORT/phpMyAdmin-4.0.8-all-languages`


Install apps
------------

Repos for apps should be cloned into `/apps`. It is handy to configure
a machine account for git, see the
[github guide](https://developer.github.com/guides/managing-deploy-keys/).
Run `ssh -T git@github.com` from the container to validate that SSH has been
configured correctly.


MySQL backups
-------------

This should only be performed on one of the lamp containers.

1. Check the backup script: `/backup.sh`
2. Setup s3 credentials: `aws s3 configure`. Set default region to: `eu-west-1`  (old Setup S3 credentials: `s3cmd --configure`)
3. Check the environment variables used
4. Run the script manually
5. Setup cron: `crontab -l`. Edit with: `crontab -e`


Image backups
-------------

The vtiger docker image takes some time to build. It is sometimes good to save
a backup of the image.

	>docker save vtiger > vtiger-dockcer.tar
	>gzip vtiger-dockcer.tar
	>docker load vtiger-docker.tar


MySQL performance tuning
------------------------

The Percona Toolkit is installed in the container. These tools works with the
local MySQL process. They cannot be used for Amazon RDS.

The RDS Command Line tools are also installed. Run `aws configure` and enter
your credentials. Use the region `eu-west-1`. Make sure that this user has the
necessary IAM Policy. Then run `aws rds rdescribe-db-instances` to verify that
things work.
See the
[documentation](http://docs.aws.amazon.com/AmazonRDS/latest/CommandLineReference/Welcome.html)
for more details. A parameter needs to be changed in RDS in order to generate the
[slow query logs](http://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/USER_LogAccess.Concepts.MySQL.html).
Changing parameters should be done with care. Make sure to test all settings in
a non-production database first.

The script `/src-mysql/db-report.sh` will download the slow query log and print
a report using the percona tools.

Turn on slow query logs in local db:

    set global slow_query_log = 'ON';
    set global long_query_time = 5;
    set global log_queries_not_using_indexes = 1;

    show variables like 'slow%';
    show variables like 'long%';
    show variables like 'log%';

Test that it works:  `SELECT SLEEP(15);`. This should show up in the slow log.

Run the part of the application that is slow. Then do `flush logs;` and check
`/var/lib/mysqld/vtiger-slow.log`. This will analyze the log and print a nice
report: `pt-query-digest /var/lib/mysqld/vtiger-slow.log`

RDS will save the output to a table. This can be turned on in a local db like
this:

    set global log_output = 'TABLE';
    SHOW CREATE TABLE mysql.slow_log;

Turn logging off:

    set global slow_query_log = 'OFF';
