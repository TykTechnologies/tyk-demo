#!/bin/bash

cd /data
mkdir gitea-dump
unzip gitea-dump.zip -d gitea-dump
cd gitea-dump
mv custom/conf/app.ini /data/gitea/conf/app.ini
unzip gitea-repo.zip
mv repositories/* /data/git/repositories/
chown -R git:git /data/gitea/conf/app.ini /data/git/repositories/
sqlite3 -echo /data/gitea/gitea.db < gitea-db.sql