/**
 * Copyright 2015 ARRIS Enterprises, Inc. All rights reserved.
 * This program is confidential and proprietary to ARRIS Enterprises, Inc. (ARRIS),
 * and may not be copied, reproduced, modified, disclosed to others, published or used,
 * in whole or in part, without the express prior written permission of ARRIS.
 */

/**
 * This module handles database database management
 */

/**
 * Import modules
 */
var appLogger = require('../utils/app_logger');
var postgresql = require('pg');
var Client = require('ssh2');
var exec = require('exec-sync');
var async = require('async');

/**
 * Constants
 */

/**
 * Globals
 */
var platformRef;
var appIdRef;
var databaseNameRef;
var userNameRef;
var passwordRef;
var oldPasswordRef;
var child;

/**
 * Module class definition 
 */
module.exports = function(platform, appId) 
{
  appLogger.info("DatabaseManager.enter");

  platformRef = platform;
  appIdRef = appId;

  /**
   * Function to grab passwords from openssl
   */
  function getPassword(type)
  { 
    var opensslCmd = '/usr/bin/openssl rsautl -inkey /opt/webservice/keys/key.txt -decrypt < /opt/webservice/keys/output.bin';
    var child = exec(opensslCmd).split(' ');
    if (type == 'ssh') {
      return child[1];
    } else {
      return child[3];
    }
  }

  /**
   * Create database 
   */
  this.createDatabase = function(databaseName, userName, password, cb)
  {
    appLogger.info("DatabaseManager.createDatabase.enter");

    databaseNameRef = databaseName;
    userNameRef = userName;
    passwordRef = password;
    create_database_command = '/var/www/html/create_db.sh ' + databaseName + ' ' + userName;
    var sshpw = getPassword('ssh');
    var postgrespw = getPassword('postgres');
    var connString = "postgres://postgres:" + postgrespw + "@dbaascluster:9999/postgres";
    var otherpgpoolhost;
    var stdoutMessage = '';
    var stderrMessage = '';
    var userlistMessage = '';
    var rcode=0;
    var message='Success';
    var classification;
    var collation;
    var encoding;
    var alreadyExists=0;
    var pgClient = new postgresql.Client(connString);
    var pgClient2 = new postgresql.Client(connString);
    var pgClient3 = new postgresql.Client(connString);
    var conn = new Client();
    var conn2 = new Client();
    var conn3 = new Client();
    async.series([
      function(callback) {
        conn.on('ready', function() {
          conn.exec('/var/www/html/get_standby_pgpool_ip.sh', function(err, stream) {
            if (err) {
              otherpgpoolhost='NONE';
            }
            stream.on('close', function(code, signal) {
              appLogger.info('Stream :: close :: code: ' + code + ', signal: ' + signal);
              conn.end();
              callback();
            }).on('data', function(data) {
              otherpgpoolhost=data;
            }).stderr.on('data', function(data) {
              otherpgpoolhost='NONE';
            });
          });
        }).connect({
          host: 'dbaascluster',
          port: 49155,
          username: 'root',
          password: sshpw
        });
      },
      function(callback) {
        pgClient.connect(function(err) {
          if (err) {
            appLogger.info('DatabaseManager.createDatabase, error connecting to postgresql at dbaascluster' + ', err=' + err);
            appLogger.info('DatabaseManager.createDatabase.exit');
            return cb(new Error('Error connecting to postgresql at dbaascluster' + ', err=' + err),1,'Error connecting to postgresql at dbaascluster' + ', err=' + err);
          }
          pgClient.query("SELECT r.usename from pg_shadow r where r.usename=$1 and r.passwd='md5'||MD5($2||$3) and pg_catalog.shobj_description(usesysid,'pg_authid')=$4", [userName,password,userName,appId] ,function(err, result) {
            if (err) {
              appLogger.info('DatabaseManager.createDatabase, error running query on dbaascluster' + ', err=' + err);
              appLogger.info('DatabaseManager.createDatabase.exit');
              return cb(new Error('Error running query on dbaascluster' + ', err=' + err),1,'Error running query on dbaascluster' + ', err=' + err);
            }
            if (typeof result.rows[0] != "undefined") {
              appLogger.info('Found user ' + userName + ' with appId ' + appId + ' and verified password, so continuing with create database.');
              callback();
            } else
            {
              appLogger.info('Did not find user ' + userName + ' with appId ' + appId + ' or password was invalid, so will not attempt to create database.');
              return cb(new Error('Incorrect password or did not find user ' + userName + ' with appId ' + appId),2,'Incorrect password or did not find user ' + userName + ' with appId = ' + appId);
            }
            pgClient.end();
          });
        });
      },
      function(callback) {
        pgClient2.connect(function(err) {
          if (err) {
            appLogger.info('DatabaseManager.createDatabase, error connecting to postgresql at dbaascluster' + ', err=' + err);
            appLogger.info('DatabaseManager.createDatabase.exit');
            return cb(new Error('Error connecting to postgresql at dbaascluster' + ', err=' + err),1,'Error connecting to postgresql at dbaascluster' + ', err=' + err);
          }
          pgClient2.query("SELECT u.usename from pg_database d, pg_user u where d.datname=$1 and d.datdba = u.usesysid", [databaseName] ,function(err, result) {
            if (err) {
              appLogger.info('DatabaseManager.createDatabase, error running query on dbaascluster' + ', err=' + err);
              appLogger.info('DatabaseManager.createDatabase.exit');
              return cb(new Error('Error running query on dbaascluster' + ', err=' + err),1,'Error running query on dbaascluster' + ', err=' + err);
            }
            if (typeof result.rows[0] != "undefined") {
              appLogger.info('The database ' + databaseName + ' already exists.');
              if (result.rows[0].usename.toString() == userName) {
                appLogger.info('The database ' + databaseName + ' already exists with ' + userName + 'as the owner.');
                alreadyExists=1;
                callback();
              } else {
                return cb(new Error('The database ' + databaseName + ' already exists with a different owner.'),3,'The database ' + databaseName + ' already exists with a different owner.');
              }
            } else
            {
              appLogger.info('Did not find database ' + databaseName + ' in dbaascluster.  Continuing.');
              callback();
            }
            pgClient2.end();
          });
        });
      },
      function(callback) {
        if (alreadyExists==1) {
          conn2.on('ready', function() {
            conn2.exec('/var/www/html/get_user_list_for_db.sh '+databaseName, function(err, stream) {
              if (err) {
                appLogger.info('DatabaseManager.createDatabase, SSH error connecting to postgresql at dbaascluster' + ', err=' + err);
                appLogger.info('DatabaseManager.createDatabase.exit');
                return cb(new Error('Error found: ' + err),1,'Error found: ' + err);
              }
              stream.on('close', function(code, signal) {
                 appLogger.info('Stream :: close :: code: ' + code + ', signal: ' + signal);
                conn2.end();
                callback();
              }).on('data', function(data) {
                appLogger.info("STDOUT: " + data);
                userlistMessage=data;
              }).stderr.on('data', function(data) {
                appLogger.info("STDERR: " + data);
                stderrMessage=data;
              });
            });
          }).connect({
            host: 'dbaascluster',
            port: 49155,
            username: 'root',
            password: sshpw
          });
        } else {
          conn2.on('ready', function() {
            conn2.exec(create_database_command, function(err, stream) {
              if (err) {
                appLogger.info('DatabaseManager.createDatabase, SSH error connecting to postgresql at dbaascluster' + ', err=' + err);
                appLogger.info('DatabaseManager.createDatabase.exit');
                return cb(new Error('Error found: ' + err),1,'Error found: ' + err);
              }
              stream.on('close', function(code, signal) {
                appLogger.info('Stream :: close :: code: ' + code + ', signal: ' + signal);
                conn2.end();
                callback();
              }).on('data', function(data) {
                appLogger.info("STDOUT: " + data);
                userlistMessage=data;
              }).stderr.on('data', function(data) {
                appLogger.info("STDERR: " + data);
                stderrMessage=data;
                if (data.toString() == "AlreadyExists") {
                  alreadyExists=1;
                }
              });
            });
          }).connect({
            host: 'dbaascluster',
            port: 49155,
            username: 'root',
            password: sshpw
          });
        }
      },
      function(callback) {
        pgClient3.connect(function(err) {
          if (err) {
            appLogger.info('DatabaseManager.createDatabase, error connecting to postgresql at dbaascluster' + ', err=' + err);
            appLogger.info('DatabaseManager.createDatabase.exit');
            return cb(new Error('Error connecting to postgresql at dbaascluster' + ', err=' + err),1,'Error connecting to postgresql at dbaascluster' + ', err=' + err);
          }
          pgClient3.query("SELECT datcollate as classification,datctype as collation,pg_encoding_to_char(encoding) as encoding from pg_database where datname=$1",[databaseName] ,function(err, result) {
            if (err) {
              appLogger.info('DatabaseManager.createDatabase, error running query on dbaascluster' + ', err=' + err);
              appLogger.info('DatabaseManager.createDatabase.exit');
              return cb(new Error('Error running query on dbaascluster' + ', err=' + err),1,'Error running query on dbaascluster' + ', err=' + err);
            }
            if (typeof result.rows[0] != "undefined") {
              appLogger.info('Database ' + databaseName + ' was actually created.');
              classification=result.rows[0].classification;
              collation=result.rows[0].collation;
              encoding=result.rows[0].encoding;
              callback();
            } else
            {
              appLogger.info('Did not find database ' + databaseName + '. Exiting.');
              return cb(new Error('Did not find database ' + databaseName + '.'),1,'Did not find database ' + databaseName);
            }
            pgClient3.end();
          });
        });
      },
      function(callback) {
        if (otherpgpoolhost == 'NONE') { callback();} else {
          var pgp=otherpgpoolhost.toString();
          conn3.on('ready', function() {
            conn3.exec(create_database_command, function(err, stream) {
              if (err) {
                appLogger.info('DatabaseManager.createDatabase, SSH error connecting to postgresql at dbaascluster' + ', err=' + err);
                appLogger.info('DatabaseManager.createDatabase.exit');
                return cb(new Error('Error found: ' + err),1,'Error found: ' + err);
              }
              stream.on('close', function(code, signal) {
                appLogger.info('Stream :: close :: code: ' + code + ', signal: ' + signal);
                conn3.end();
                callback();
              }).on('data', function(data) {
                appLogger.info("STDOUT: " + data);
                /*stdoutMessage=data;*/
              }).stderr.on('data', function(data) {
                appLogger.info("STDERR: " + data);
                var match = data.toString().match(/AlreadyExists/);
                if (match !== null) {
                  stderrMessage='';
                } else {
                  stderrMessage=data;
                }
              });
            });
          }).connect({
            host: pgp,
            port: 49155,
            username: 'root',
            password: sshpw
          });
        }
      },
      function(callback) {
        rcode=0;
        if (stderrMessage != '' && alreadyExists ==1) {
          rcode=1;
          stderrMessage='';
        }
        if (stderrMessage != '') {
          rcode=2;
          message=stderrMessage;
        } else {
          appLogger.info('Generating JSON');
          userList=[];
          userlist=userlistMessage.toString().split(' ');
          appLogger.info('userlist = ' + userlist);
          for (var i=0; i< userlist.length; i++) {
            userList.push(userlist[i]);
          }
          finalJson = {'$schema': '/schemas/Database/v1.0',
            'Database': {
              'classification': classification,
              'collation': collation,
              'encoding': encoding,
              'instance': {
                 'host': 'dbaascluster',
                 'port': '9999'
              },
              'name': databaseName,
              'platform': 'postgresql',
              'users': userList
            }
          };
          message=JSON.stringify(finalJson);
          appLogger.info(JSON.stringify(finalJson));
          if (alreadyExists ==1) {rcode=1;}
        }
        callback();
        return cb(null, rcode, message);
      }    
    ], function(err) {
       if (err) {
         appLogger.info('DatabaseManager.createDatabase, error: ' + ', err=' + err);
         appLogger.info('DatabaseManager.createDatabase.exit');
         return cb(new Error('Error creating database ' + databaseName + ', owner ' + userName));
       }
       appLogger.info('DatabaseManager.createDatabase.exit');
       return cb(null, rcode, message);
    });
  }

  /**
   * Alter database owner
   */
  this.alterDatabaseOwner = function(databaseName, oldOwnerName, oldOwnerPassword, newOwnerName, cb)
  {
    appLogger.info("DatabaseManager.alterDatabaseOwner.enter");

    databaseNameRef = databaseName;
    oldOwnerNameRef= oldOwnerName;
    oldOwnerPasswordRef = oldOwnerPassword;
    newOwnerNameRef= newOwnerName;
    alter_database_owner_command = '/var/www/html/alter_db_owner.sh ' + databaseName + ' ' + newOwnerName;
    associate_database_command = '/var/www/html/associate_db.sh ' + databaseName + ' ' + newOwnerName;
    var sshpw = getPassword('ssh');
    var postgrespw = getPassword('postgres');
    var connString = "postgres://postgres:" + postgrespw + "@dbaascluster:9999/postgres";
    var otherpgpoolhost;
    var stdoutMessage = '';
    var stderrMessage = '';
    var userlistMessage = '';
    var rcode=0;
    var message='Success';
    var classification;
    var collation;
    var encoding;
    var alreadyExists=0;
    var pgClient = new postgresql.Client(connString);
    var pgClient2 = new postgresql.Client(connString);
    var pgClient3 = new postgresql.Client(connString);
    var conn = new Client();
    var conn2 = new Client();
    var conn3 = new Client();
    async.series([
      function(callback) {
        conn.on('ready', function() {
          conn.exec('/var/www/html/get_standby_pgpool_ip.sh', function(err, stream) {
            if (err) {
              otherpgpoolhost='NONE';
            }
            stream.on('close', function(code, signal) {
              appLogger.info('Stream :: close :: code: ' + code + ', signal: ' + signal);
              conn.end();
              callback();
            }).on('data', function(data) {
              otherpgpoolhost=data;
            }).stderr.on('data', function(data) {
              otherpgpoolhost='NONE';
            });
          });
        }).connect({
          host: 'dbaascluster',
          port: 49155,
          username: 'root',
          password: sshpw
        });
      },
      function(callback) {
        pgClient.connect(function(err) {
          if (err) {
            appLogger.info('DatabaseManager.alterDatabaseOwner, error connecting to postgresql at dbaascluster' + ', err=' + err);
            appLogger.info('DatabaseManager.alterDatabaseOwner.exit');
            return cb(new Error('Error connecting to postgresql at dbaascluster' + ', err=' + err),1,'Error connecting to postgresql at dbaascluster' + ', err=' + err);
          }
          pgClient.query("SELECT r.usename from pg_shadow r where r.usename=$1 and r.passwd='md5'||MD5($2||$3) and pg_catalog.shobj_description(usesysid,'pg_authid')=$4", [oldOwnerName,oldOwnerPassword,oldOwnerName,appId] ,function(err, result) {
            if (err) {
              appLogger.info('DatabaseManager.alterDatabaseOwner, error running query on dbaascluster' + ', err=' + err);
              appLogger.info('DatabaseManager.alterDatabaseOwner.exit');
              return cb(new Error('Error running query on dbaascluster' + ', err=' + err),1,'Error running query on dbaascluster' + ', err=' + err);
            }
            if (typeof result.rows[0] != "undefined") {
              appLogger.info('Found user ' + oldOwnerName + ' with appId ' + appId + ' and verified password, so continuing with alter database owner.');
              callback();
            } else
            {
              appLogger.info('Did not find user ' + oldOwnerName + ' with appId = ' + appId + ' or password was invalid, so will not attempt to alter database owner.');
              return cb(new Error('Incorrect password or did not find user ' + oldOwnerName + ' with appId ' + appId),2,'Incorrect password or did not find user ' + oldOwnerName + ' with appId ' + appId);
            }
            pgClient.end();
          });
        });
      },
      function(callback) {
        pgClient2.connect(function(err) {
          if (err) {
            appLogger.info('DatabaseManager.alterDatabaseOwner, error connecting to postgresql at dbaascluster' + ', err=' + err);
            appLogger.info('DatabaseManager.alterDatabaseOwner.exit');
            return cb(new Error('Error connecting to postgresql at dbaascluster' + ', err=' + err),1,'Error connecting to postgresql at dbaascluster' + ', err=' + err);
          }
          pgClient2.query("SELECT u.usename from pg_database d, pg_user u where d.datname=$1 and d.datdba = u.usesysid", [databaseName] ,function(err, result) {
            if (err) {
              appLogger.info('DatabaseManager.alterDatabaseOwner, error running query on dbaascluster' + ', err=' + err);
              appLogger.info('DatabaseManager.alterDatabaseOwner.exit');
              return cb(new Error('Error running query on dbaascluster' + ', err=' + err),1,'Error running query on dbaascluster' + ', err=' + err);
            }
            if (typeof result.rows[0] != "undefined") {
              appLogger.info('The database ' + databaseName + ' already exists.');
              if (result.rows[0].usename.toString() == oldOwnerName) {
                appLogger.info('The database ' + databaseName + ' already exists with ' + oldOwnerName + 'as the owner.  Continuing.');
                callback();
              } else {
                return cb(new Error('The database ' + databaseName + ' already exists with a different owner.'),2,'The database ' + databaseName + ' already exists with a different owner.');
              }
            } else
            {
              appLogger.info('Did not find database ' + databaseName + ' in dbaascluster.');
              return cb(new Error('The database ' + databaseName + ' does not exist.'),1,'The database ' + databaseName + ' does not exist.');
            }
            pgClient2.end();
          });
        });
      },
      function(callback) {
        conn2.on('ready', function() {
          conn2.exec(alter_database_owner_command, function(err, stream) {
            if (err) {
              appLogger.info('DatabaseManager.alterDatabaseOwner, SSH error connecting to postgresql at dbaascluster' + ', err=' + err);
              appLogger.info('DatabaseManager.alterDatabaseOwner.exit');
              return cb(new Error('Error found: ' + err),1,'Error found: ' + err);
            }
            stream.on('close', function(code, signal) {
               appLogger.info('Stream :: close :: code: ' + code + ', signal: ' + signal);
              conn2.end();
              callback();
            }).on('data', function(data) {
              appLogger.info("STDOUT: " + data);
              userlistMessage=data;
            }).stderr.on('data', function(data) {
              appLogger.info("STDERR: " + data);
              stderrMessage=data;
            });
          });
        }).connect({
          host: 'dbaascluster',
          port: 49155,
          username: 'root',
          password: sshpw
        });
      },
      function(callback) {
        if (otherpgpoolhost == 'NONE') { callback();} else {
          var pgp=otherpgpoolhost.toString();
          conn3.on('ready', function() {
            conn3.exec(associate_database_command, function(err, stream) {
              if (err) {
                appLogger.info('DatabaseManager.alterDatabaseOwner, SSH error connecting to postgresql at dbaascluster' + ', err=' + err);
                appLogger.info('DatabaseManager.alterDatabaseOwner.exit');
                return cb(new Error('Error found: ' + err),1,'Error found: ' + err);
              }
              stream.on('close', function(code, signal) {
                appLogger.info('Stream :: close :: code: ' + code + ', signal: ' + signal);
                conn3.end();
                callback();
              }).on('data', function(data) {
                appLogger.info("STDOUT: " + data);
                /*stdoutMessage=data;*/
              }).stderr.on('data', function(data) {
                appLogger.info("STDERR: " + data);
                var match = data.toString().match(/AlreadyExists/);
                if (match !== null) {
                  stderrMessage='';
                } else {
                  stderrMessage=data;
                }
              });
            });
          }).connect({
            host: pgp,
            port: 49155,
            username: 'root',
            password: sshpw
          });
        }
      },
      function(callback) {
        if (stderrMessage != '') {
          rcode=2;
          message=stderrMessage;
        } else {
          rcode=0;
          message=stdoutMessage;
        }
        callback();
        return cb(null,rcode,message);
      }
    ], function(err) {
       if (err) {
         appLogger.info('DatabaseManager.alterDatabaseOwner, error: ' + ', err=' + err);
         appLogger.info('DatabaseManager.alterDatabaseOwner.exit');
         return cb(new Error('Error altering database ' + databaseName + ', owner ' + oldOwnerName));
       }
       appLogger.info('DatabaseManager.alterDatbaseOwner.exit');
       return cb(null, rcode, message);
    });
  }
 
  /**
   * Associate database and user
   */

  this.associateDatabase = function(databaseName, ownerName, password, targetUserName, action, cb)  {
    appLogger.info("DatabaseManager.associateDatabase.enter");

    databaseNameRef = databaseName;
    ownerNameRef = ownerName;
    passwordRef = password;
    targetUserNameRef = targetUserName;
    actionRef = action;
    associate_database_command = '/var/www/html/associate_db.sh ' + databaseName + ' ' + targetUserName;
    var sshpw = getPassword('ssh');
    var postgrespw = getPassword('postgres');
    var connString = "postgres://postgres:" + postgrespw + "@dbaascluster:9999/postgres";
    var otherpgpoolhost;
    var stdoutMessage = '';
    var stderrMessage = '';
    var userlistMessage = '';
    var rcode=0;
    var message='Success';
    var classification;
    var collation;
    var encoding;
    var pgClient = new postgresql.Client(connString);
    var pgClient2 = new postgresql.Client(connString);
    var pgClient3 = new postgresql.Client(connString);
    var conn = new Client();
    var conn2 = new Client();
    var conn3 = new Client();
    async.series([
      function(callback) {
        conn.on('ready', function() {
          conn.exec('/var/www/html/get_standby_pgpool_ip.sh', function(err, stream) {
            if (err) {
              otherpgpoolhost='NONE';
            }
            stream.on('close', function(code, signal) {
              appLogger.info('Stream :: close :: code: ' + code + ', signal: ' + signal);
              conn.end();
              callback();
            }).on('data', function(data) {
              otherpgpoolhost=data;
            }).stderr.on('data', function(data) {
              otherpgpoolhost='NONE';
            });
          });
        }).connect({
          host: 'dbaascluster',
          port: 49155,
          username: 'root',
          password: sshpw
        });
      },
      function(callback) {
        pgClient.connect(function(err) {
          if (err) {
            appLogger.info('DatabaseManager.associateDatabase, error connecting to postgresql at dbaascluster' + ', err=' + err);
            appLogger.info('DatabaseManager.associateDatabase.exit');
            return cb(new Error('Error connecting to postgresql at dbaascluster' + ', err=' + err),1,'Error connecting to postgresql at dbaascluster' + ', err=' + err);
          }
          pgClient.query("SELECT r.usename from pg_shadow r where r.usename=$1 and r.passwd='md5'||MD5($2||$3) and pg_catalog.shobj_description(usesysid,'pg_authid')=$4", [ownerName,password,ownerName,appId] ,function(err, result) {
            if (err) {
              appLogger.info('DatabaseManager.associateDatabase, error running query on dbaascluster' + ', err=' + err);
              appLogger.info('DatabaseManager.associateDatabase.exit');
              return cb(new Error('Error running query on dbaascluster' + ', err=' + err),1,'Error running query on dbaascluster' + ', err=' + err);
            }
            if (typeof result.rows[0] != "undefined") {
              appLogger.info('Found owner =  ' + ownerName + ' with appId = ' + appId + ' and verified password, so continuing with associate database and user.');
              callback();
            } else
            {
              appLogger.info('Did not find owner = ' + ownerName + ' with appId = ' + appId + ' or password was invalid, so will not attempt to associate database and user.');
              return cb(new Error('Incorrect password or did not find owner = ' + ownerName + ' with appId = ' + appId),2,'Incorrect password or did not find owner = ' + ownerName + ' with appId = ' + appId);
            }
            pgClient.end();
          });
        });
      },
      function(callback) {
        pgClient2.connect(function(err) {
          if (err) {
            appLogger.info('DatabaseManager.associateDatabase, error connecting to postgresql at dbaascluster' + ', err=' + err);
            appLogger.info('DatabaseManager.associateDatabase.exit');
            return cb(new Error('Error connecting to postgresql at dbaascluster' + ', err=' + err),1,'Error connecting to postgresql at dbaascluster' + ', err=' + err);
          }
          pgClient2.query("SELECT u.usename from pg_database d, pg_user u where d.datdba = u.usesysid and d.datname=$1",[databaseName] ,function(err, result) {
            if (err) {
              appLogger.info('DatabaseManager.associateDatabase, error running query on dbaascluster' + ', err=' + err);
              appLogger.info('DatabaseManager.associateDatabase.exit');
              return cb(new Error('Error running query on dbaascluster' + ', err=' + err),1,'Error running query on dbaascluster' + ', err=' + err);
            }
            if (typeof result.rows[0] != "undefined") {
              if (result.rows[0].usename.toString() == ownerName) {
                appLogger.info('Owner ' + ownerName + ' actually does own the database ' + databaseName + '.  Continuing.');
                callback();
              } else {
                appLogger.info('Owner ' + ownerName + ' does not own the database ' + databaseName + ', so will not attempt to associate database and user.');
                return cb(new Error('Database ' + databaseName + ' is not owned by user ' + ownerName+'.'),3,'Database ' + databaseName + ' is not owned by user ' + ownerName + '.');
              }
            } else
            {
              appLogger.info('Database ' + databaseName + ' does not exist. Exiting.');
              return cb(new Error('Database ' + databaseName + ' does not exist.'),1,'Database ' + databaseName + ' does not exist.');
            }
            pgClient2.end();
          });
        });
      },
      function(callback) {
        pgClient3.connect(function(err) {
          if (err) {
            appLogger.info('UserManager.associateDatabase, error connecting to postgresql at dbaascluster' + ', err=' + err);
            appLogger.info('UserManager.associateDatabase.exit');
            return cb(new Error('Error connecting to postgresql at dbaascluster' + ', err=' + err),2,'Error connecting to postgresql at dbaascluster' + ', err=' + err);
          }
          pgClient3.query("SELECT pg_catalog.shobj_description(usesysid,'pg_authid') as userapp from pg_shadow r where r.usename=$1", [targetUserName] ,function(err, result) {
            if (err) {
              appLogger.info('UserManager.associateDatabase, error running query on dbaascluster' + ', err=' + err);
              appLogger.info('UserManager.associateDatabase.exit');
              return cb(new Error('Error running query on dbaascluster' + ', err=' + err),2,'Error running query on dbaascluster' + ', err=' + err);
            }
            if (typeof result.rows[0] != "undefined") {
              appLogger.info('Found target user ' + targetUserName + '.');
              if (result.rows[0].userapp.toString() == appId) {
                appLogger.info('Target user exists under existing appId.  Continuing.');
                callback();
              } else {
                appLogger.info('AppId does not match for target user.  Exit with error.');
                return cb(new Error('Target user ' + targetUserName + ' already exists with a different appId than ' + appId),3,'Target user ' + targetUserName + ' already exists with a different appId than ' + appId);
              }
            } else
            {
              appLogger.info('Did not find user ' + targetUserName + '.');
              return cb(new Error('Target user ' + targetUserName + ' does not exist.'),3,'Target user ' + targetUserName + ' does not exist.');
            }
            pgClient3.end();
          });
        });
      },
      function(callback) {
        conn2.on('ready', function() {
          conn2.exec(associate_database_command, function(err, stream) {
            if (err) {
              appLogger.info('DatabaseManager.associateDatabase, SSH error connecting to postgresql at dbaascluster' + ', err=' + err);
              appLogger.info('DatabaseManager.associateDatabase.exit');
              return cb(new Error('Error found: ' + err),1,'Error found: ' + err);
            }
            stream.on('close', function(code, signal) {
               appLogger.info('Stream :: close :: code: ' + code + ', signal: ' + signal);
              conn2.end();
              callback();
            }).on('data', function(data) {
              appLogger.info("STDOUT: " + data);
              userlistMessage=data;
            }).stderr.on('data', function(data) {
              appLogger.info("STDERR: " + data);
              stderrMessage=data;
            });
          });
        }).connect({
          host: 'dbaascluster',
          port: 49155,
          username: 'root',
          password: sshpw
        });
      },
      function(callback) {
        if (otherpgpoolhost == 'NONE') { callback();} else {
          var pgp=otherpgpoolhost.toString();
          conn3.on('ready', function() {
            conn3.exec(associate_database_command, function(err, stream) {
              if (err) {
                appLogger.info('DatabaseManager.associateDatabase, SSH error connecting to postgresql at dbaascluster' + ', err=' + err);
                appLogger.info('DatabaseManager.associateDatabase.exit');
                return cb(new Error('Error found: ' + err),1,'Error found: ' + err);
              }
              stream.on('close', function(code, signal) {
                appLogger.info('Stream :: close :: code: ' + code + ', signal: ' + signal);
                conn3.end();
                callback();
              }).on('data', function(data) {
                appLogger.info("STDOUT: " + data);
                /*stdoutMessage=data;*/
              }).stderr.on('data', function(data) {
                appLogger.info("STDERR: " + data);
                var match = data.toString().match(/AlreadyExists/);
                if (match !== null) {
                  stderrMessage='';
                } else {
                  stderrMessage=data;
                }
              });
            });
          }).connect({
            host: pgp,
            port: 49155,
            username: 'root',
            password: sshpw
          });
        }
      },
      function(callback) {
        if (stderrMessage != '') {
          rcode=1;
          message=stderrMessage;
        } else {
          rcode=0;
          message=stdoutMessage;
        }
        callback();
        return cb(null,rcode,message);
      }
    ], function(err) {
       if (err) {
         appLogger.info('DatabaseManager.associateDatabase, error: ' + ', err=' + err);
         appLogger.info('DatabaseManager.associateDatabase.exit');
         return cb(new Error('Error associating database ' + databaseName + ' and user ' + targetUserName));
       }
       appLogger.info('DatabaseManager.associateDatabase.exit');
       return cb(null, rcode, message);
    });
  } 

  /**
   * Disassociate database and user
   */

  this.disassociateDatabase = function(databaseName, ownerName, password, targetUserName, action, cb)  {
    appLogger.info("DatabaseManager.disassociateDatabase.enter");

    databaseNameRef = databaseName;
    ownerNameRef = ownerName;
    passwordRef = password;
    targetUserNameRef = targetUserName;
    actionRef = action;
    disassociate_database_command = '/var/www/html/disassociate_db.sh ' + databaseName + ' ' + targetUserName;
    var sshpw = getPassword('ssh');
    var postgrespw = getPassword('postgres');
    var connString = "postgres://postgres:" + postgrespw + "@dbaascluster:9999/postgres";
    var otherpgpoolhost;
    var stdoutMessage = '';
    var stderrMessage = '';
    var userlistMessage = '';
    var rcode=0;
    var message='Success';
    var classification;
    var collation;
    var encoding;
    var pgClient = new postgresql.Client(connString);
    var pgClient2 = new postgresql.Client(connString);
    var pgClient3 = new postgresql.Client(connString);
    var conn = new Client();
    var conn2 = new Client();
    var conn3 = new Client();
    async.series([
      function(callback) {
        conn.on('ready', function() {
          conn.exec('/var/www/html/get_standby_pgpool_ip.sh', function(err, stream) {
            if (err) {
              otherpgpoolhost='NONE';
            }
            stream.on('close', function(code, signal) {
              appLogger.info('Stream :: close :: code: ' + code + ', signal: ' + signal);
              conn.end();
              callback();
            }).on('data', function(data) {
              otherpgpoolhost=data;
            }).stderr.on('data', function(data) {
              otherpgpoolhost='NONE';
            });
          });
        }).connect({
          host: 'dbaascluster',
          port: 49155,
          username: 'root',
          password: sshpw
        });
      },
      function(callback) {
        pgClient.connect(function(err) {
          if (err) {
            appLogger.info('DatabaseManager.disassociateDatabase, error connecting to postgresql at dbaascluster' + ', err=' + err);
            appLogger.info('DatabaseManager.disassociateDatabase.exit');
            return cb(new Error('Error connecting to postgresql at dbaascluster' + ', err=' + err),1,'Error connecting to postgresql at dbaascluster' + ', err=' + err);
          }
          pgClient.query("SELECT r.usename from pg_shadow r where r.usename=$1 and r.passwd='md5'||MD5($2||$3) and pg_catalog.shobj_description(usesysid,'pg_authid')=$4", [ownerName,password,ownerName,appId] ,function(err, result) {
            if (err) {
              appLogger.info('DatabaseManager.disassociateDatabase, error running query on dbaascluster' + ', err=' + err);
              appLogger.info('DatabaseManager.disassociateDatabase.exit');
              return cb(new Error('Error running query on dbaascluster' + ', err=' + err),1,'Error running query on dbaascluster' + ', err=' + err);
            }
            if (typeof result.rows[0] != "undefined") {
              appLogger.info('Found owner ' + ownerName + ' with appId ' + appId + ' and verified password, so continuing with disassociate database and user.');
              callback();
            } else
            {
              appLogger.info('Did not find owner ' + ownerName + ' with appId ' + appId + ' or password was invalid, so will not attempt to disassociate database and user.');
              return cb(new Error('Incorrect password or did not find owner = ' + ownerName + ' with appId = ' + appId),2,'Incorrect password or did not find owner = ' + ownerName + ' with appId = ' + appId);
            }
            pgClient.end();
          });
        });
      },
      function(callback) {
        pgClient2.connect(function(err) {
          if (err) {
            appLogger.info('DatabaseManager.disassociateDatabase, error connecting to postgresql at dbaascluster' + ', err=' + err);
            appLogger.info('DatabaseManager.disassociateDatabase.exit');
            return cb(new Error('Error connecting to postgresql at dbaascluster' + ', err=' + err),1,'Error connecting to postgresql at dbaascluster' + ', err=' + err);
          }
          pgClient2.query("SELECT u.usename from pg_database d, pg_user u where d.datdba = u.usesysid and d.datname=$1",[databaseName] ,function(err, result) {
            if (err) {
              appLogger.info('DatabaseManager.disassociateDatabase, error running query on dbaascluster' + ', err=' + err);
              appLogger.info('DatabaseManager.disassociateDatabase.exit');
              return cb(new Error('Error running query on dbaascluster' + ', err=' + err),1,'Error running query on dbaascluster' + ', err=' + err);
            }
            if (typeof result.rows[0] != "undefined") {
              if (result.rows[0].usename.toString() == ownerName) {
                appLogger.info('Owner =  ' + ownerName + ' actually does own the database ' + databaseName + '.  Continuing.');
                callback();
              } else {
                appLogger.info('Owner ' + ownerName + ' does not own the database ' + databaseName + ', so will not attempt to disassociate database and user.');
                return cb(new Error('Database ' + databaseName + ' is not owned by user ' + ownerName+'.'),3,'Database ' + databaseName + ' is not owned by user ' + ownerName + '.');
              }
            } else
            {
              appLogger.info('Database ' + databaseName + ' does not exist.  Exiting.');
              return cb(new Error('Database ' + databaseName + ' does not exist.'),1,'Database ' + databaseName + ' does not exist.');
            }
            pgClient2.end();
          });
        });
      },
      function(callback) {
        pgClient3.connect(function(err) {
          if (err) {
            appLogger.info('UserManager.disassociateDatabase, error connecting to postgresql at dbaascluster' + ', err=' + err);
            appLogger.info('UserManager.disassociateDatabase.exit');
            return cb(new Error('Error connecting to postgresql at dbaascluster' + ', err=' + err),2,'Error connecting to postgresql at dbaascluster' + ', err=' + err);
          }
          pgClient3.query("SELECT pg_catalog.shobj_description(usesysid,'pg_authid') as userapp from pg_shadow r where r.usename=$1", [targetUserName] ,function(err, result) {
            if (err) {
              appLogger.info('UserManager.disassociateDatabase, error running query on dbaascluster' + ', err=' + err);
              appLogger.info('UserManager.disassociateDatabase.exit');
              return cb(new Error('Error running query on dbaascluster' + ', err=' + err),2,'Error running query on dbaascluster' + ', err=' + err);
            }
            if (typeof result.rows[0] != "undefined") {
              appLogger.info('Found target user ' + targetUserName + '.');
              if (result.rows[0].userapp.toString() == appId) {
                appLogger.info('Target user exists under existing appId.  Continuing.');
                callback();
              } else {
                appLogger.info('AppId does not match for target user.  Exit with error.');
                return cb(new Error('Target user ' + targetUserName + ' already exists with a different appId than ' + appId),3,'Target user ' + targetUserName + ' already exists with a different appId than ' + appId);
              }
            } else
            {
              appLogger.info('Did not find user ' + targetUserName + '.');
              return cb(new Error('Target user ' + targetUserName + ' does not exist.'),3,'Target user ' + targetUserName + ' does not exist.');
            }
            pgClient3.end();
          });
        });
      },
      function(callback) {
        conn2.on('ready', function() {
          conn2.exec(disassociate_database_command, function(err, stream) {
            if (err) {
              appLogger.info('DatabaseManager.disassociateDatabase, SSH error connecting to postgresql at dbaascluster' + ', err=' + err);
              appLogger.info('DatabaseManager.disassociateDatabase.exit');
              return cb(new Error('Error found: ' + err),1,'Error found: ' + err);
            }
            stream.on('close', function(code, signal) {
               appLogger.info('Stream :: close :: code: ' + code + ', signal: ' + signal);
              conn2.end();
              callback();
            }).on('data', function(data) {
              appLogger.info("STDOUT: " + data);
              userlistMessage=data;
            }).stderr.on('data', function(data) {
              appLogger.info("STDERR: " + data);
              stderrMessage=data;
            });
          });
        }).connect({
          host: 'dbaascluster',
          port: 49155,
          username: 'root',
          password: sshpw
        });
      },
      function(callback) {
        if (otherpgpoolhost == 'NONE') { callback();} else {
          var pgp=otherpgpoolhost.toString();
          conn3.on('ready', function() {
            conn3.exec(disassociate_database_command, function(err, stream) {
              if (err) {
                appLogger.info('DatabaseManager.disassociateDatabase, SSH error connecting to postgresql at dbaascluster' + ', err=' + err);
                appLogger.info('DatabaseManager.disassociateDatabase.exit');
                return cb(new Error('Error found: ' + err),1,'Error found: ' + err);
              }
              stream.on('close', function(code, signal) {
                appLogger.info('Stream :: close :: code: ' + code + ', signal: ' + signal);
                conn3.end();
                callback();
              }).on('data', function(data) {
                appLogger.info("STDOUT: " + data);
                /*stdoutMessage=data;*/
              }).stderr.on('data', function(data) {
                appLogger.info("STDERR: " + data);
                var match = data.toString().match(/AlreadyExists/);
                if (match !== null) {
                  stderrMessage='';
                } else {
                  stderrMessage=data;
                }
              });
            });
          }).connect({
            host: pgp,
            port: 49155,
            username: 'root',
            password: sshpw
          });
        }
      },
      function(callback) {
        if (stderrMessage != '') {
          rcode=3;
          message=stderrMessage;
        } else {
          rcode=0;
          message=stdoutMessage;
        }
        callback();
        return cb(null,rcode,message);
      }
    ], function(err) {
       if (err) {
         appLogger.info('DatabaseManager.disassociateDatabase, error: ' + ', err=' + err);
         appLogger.info('DatabaseManager.disassociateDatabase.exit');
         return cb(new Error('Error disassociating database ' + databaseName + ' and user ' + targetUserName));
       }
       appLogger.info('DatabaseManager.disassociateDatabase.exit');
       return cb(null, rcode, message);
    });
  }

  /**
   * Delete database 
   */
  this.deleteDatabase = function(databaseName, userName, password, cb)
  {
    appLogger.info("DatabaseManager.deleteDatabase.enter");

    databaseNameRef = databaseName;
    userNameRef = userName;
    passwordRef = password;
    drop_database_command = '/var/www/html/drop_db.sh ' + databaseName + ' ' + userName; 
    var sshpw = getPassword('ssh');
    var postgrespw = getPassword('postgres');
    var connString = "postgres://postgres:" + postgrespw + "@dbaascluster:9999/postgres"; 
    var otherpgpoolhost;
    var stdoutMessage = '';
    var stderrMessage = '';
    var rcode=0;
    var message='Success';
    var pgClient = new postgresql.Client(connString);
    var pgClient2 = new postgresql.Client(connString);
    var pgClient3 = new postgresql.Client(connString);
    var conn = new Client();
    var conn2 = new Client();
    var conn3 = new Client();
    async.series([
      function(callback) {
        conn.on('ready', function() {
          conn.exec('/var/www/html/get_standby_pgpool_ip.sh', function(err, stream) {
            if (err) {
              otherpgpoolhost='NONE';
            }
            stream.on('close', function(code, signal) {
              appLogger.info('Stream :: close :: code: ' + code + ', signal: ' + signal);
              conn.end();
              callback();
            }).on('data', function(data) {
              otherpgpoolhost=data;
              appLogger.info('otherpgpoolhost = '+otherpgpoolhost);
            }).stderr.on('data', function(data) {
              otherpgpoolhost='NONE';
            });
          });
        }).connect({
          host: 'dbaascluster',
          port: 49155,
          username: 'root',
          password: sshpw
        });
      },
      function(callback) {
        pgClient.connect(function(err) {
          if (err) {
            appLogger.info('DatabaseManager.deleteDatabase, error connecting to postgresql at dbaascluster' + ', err=' + err);
            appLogger.info('DatabaseManager.deleteDatabase.exit');
            return cb(new Error('Error connecting to postgresql at dbaascluster' + ', err=' + err),1,'Error connecting to postgresql at dbaascluster' + ', err=' + err);
          }
          pgClient.query("SELECT r.usename from pg_shadow r where r.usename=$1 and r.passwd='md5'||MD5($2||$3) and pg_catalog.shobj_description(usesysid,'pg_authid')=$4", [userName,password,userName,appId] ,function(err, result) {
            if (err) {
              appLogger.info('DatabaseManager.deleteDatabase, error running query on dbaascluster' + ', err=' + err);
              appLogger.info('DatabaseManager.deleteDatabase.exit');
              return cb(new Error('Error running query on dbaascluster' + ', err=' + err),1,'Error running query on dbaascluster' + ', err=' + err);
            }
            if (typeof result.rows[0] != "undefined") {
              appLogger.info('Found owner =  ' + userName + ' with appId = ' + appId + ' and verified password, so continuing with delete database.');
              callback();
            } else
            {
              appLogger.info('Did not find user = ' + userName + ' with appId = ' + appId + ' or password was invalid, so will not attempt to delete database.');
              return cb(new Error('Incorrect password or did not find user = ' + userName + ' with appId = ' + appId),2,'Incorrect password or did not find user = ' + userName + ' with appId = ' + appId); 
            }
            pgClient.end();
          });
        });
      },
      function(callback) {
        pgClient2.connect(function(err) {
          if (err) {
            appLogger.info('DatabaseManager.deleteDatabase, error connecting to postgresql at dbaascluster' + ', err=' + err);
            appLogger.info('DatabaseManager.deleteDatabase.exit');
            return cb(new Error('Error connecting to postgresql at dbaascluster' + ', err=' + err),1,'Error connecting to postgresql at dbaascluster' + ', err=' + err);
          }
          pgClient2.query("SELECT u.usename from pg_database d, pg_user u where d.datdba = u.usesysid and d.datname=$1",[databaseName] ,function(err, result) {
            if (err) {
              appLogger.info('DatabaseManager.deleteDatabase, error running query on dbaascluster' + ', err=' + err);
              appLogger.info('DatabaseManager.deleteDatabase.exit');
              return cb(new Error('Error running query on dbaascluster' + ', err=' + err),1,'Error running query on dbaascluster' + ', err=' + err);
            }
            if (typeof result.rows[0] != "undefined") {
              if (result.rows[0].usename.toString() == userName) {
                appLogger.info('User ' + userName+ ' actually does own the database ' + databaseName + '.  Continuing.');
                callback();
              } else {
                appLogger.info('User ' + userName + ' does not own the database ' + databaseName + ', so will not attempt to delete database.');
                return cb(new Error('Database ' + databaseName + ' is not owned by user ' + userName +'.'),3,'Database ' + databaseName + ' is not owned by user ' + userName + '.');
              }
            } else
            {
              appLogger.info('Database ' + databaseName + ' does not exist.');
              return cb(new Error('Database ' + databaseName + ' does not exist.'),1,'Database ' + databaseName + ' does not exist.');
            }
            pgClient2.end();
          });
        });
      },
      function(callback) {
        pgClient3.connect(function(err) {
          if (err) {
            appLogger.info('DatabaseManager.deleteDatabase, error connecting to postgresql at dbaascluster' + ', err=' + err);
            appLogger.info('DatabaseManager.deleteDatabase.exit');
            return cb(new Error('Error connecting to postgresql at dbaascluster' + ', err=' + err),1,'Error connecting to postgresql at dbaascluster' + ', err=' + err);
          }
          pgClient3.query("SELECT count(*) as activeconn from pg_stat_activity where datname=$1",[databaseName] ,function(err, result) {
            if (err) {
              appLogger.info('DatabaseManager.deleteDatabase, error running query on dbaascluster' + ', err=' + err);
              appLogger.info('DatabaseManager.deleteDatabase.exit');
              return cb(new Error('Error running query on dbaascluster' + ', err=' + err),1,'Error running query on dbaascluster' + ', err=' + err);
            }
            if (typeof result.rows[0] != "undefined") {
              if (result.rows[0].activeconn ==0) {
                appLogger.info('Database ' + databaseName  + ' has no active connections against it.  Continuing.');
                callback();
              } else {
                appLogger.info('Database ' + databaseName + ' has open connections against it.  Will not drop database.');
                return cb(new Error('Database ' + databaseName  + ' has open connections against it.'),5,'Database ' + databaseName + ' has open connections against it.');
              }
            } else
            {
              appLogger.info('Error in checking active database activty on database ' + databaseName + '.');
              return cb(new Error('Error in checking active database activity on database ' + databaseName  + '.'),1,'Error in checking active database activity on database ' + databaseName + '.');
            }
            pgClient3.end();
          });
        });
      },
      function(callback) {
        conn2.on('ready', function() {
        conn2.exec(drop_database_command, function(err, stream) {
          if (err) {
            appLogger.info('DatabaseManager.deleteDatabase, SSH error connecting to postgresql at dbaascluster' + ', err=' + err);
            appLogger.info('DatabaseManager.deleteDatabase.exit');
            return cb(new Error('Error found: ' + err),1,'Error found: ' + err);;
          }
          stream.on('close', function(code, signal) {
            appLogger.info('Stream :: close :: code: ' + code + ', signal: ' + signal);
            conn2.end();
            callback();
            }).on('data', function(data) {
              appLogger.info("STDOUT: " + data);
              stdoutMessage=data;
            }).stderr.on('data', function(data) {
              appLogger.info("STDERR: " + data);
              stderrMessage=data;
            });
          });
        }).connect({
          host: 'dbaascluster',
          port: 49155,
          username: 'root',
          password: sshpw
        });
      },
      function(callback) {
        if (otherpgpoolhost == 'NONE') { callback();} else {
          var pgp=otherpgpoolhost.toString();
          conn3.on('ready', function() {
            conn3.exec(drop_database_command, function(err, stream) {
              if (err) {
                appLogger.info('DatabaseManager.deleteDatabase, SSH error connecting to postgresql at dbaascluster' + ', err=' + err);
                appLogger.info('DatabaseManager.deleteDatabase.exit');
                return cb(new Error('Error found: ' + err),1,'Error found: ' + err);
              }
              stream.on('close', function(code, signal) {
                appLogger.info('Stream :: close :: code: ' + code + ', signal: ' + signal);
                conn3.end();
                callback();
              }).on('data', function(data) {
                appLogger.info("STDOUT: " + data);
                /*stdoutMessage=data;*/
              }).stderr.on('data', function(data) {
                appLogger.info("STDERR: " + data);
                var match = data.toString().match(/Warning/);
                if (match !== null) {
                  stderrMessage='';
                } else {
                  stderrMessage=data;
                }
              });
            });
          }).connect({
            host: pgp,
            port: 49155,
            username: 'root',
            password: sshpw
          });
        }
      },
      function(callback) {
        if (stderrMessage != '') {
          rcode=1;
          message=stderrMessage;
        } else {
          rcode=0;
          message=stdoutMessage;
        }
        callback();
        return cb(null,rcode,message);
      }
    ], function(err) {
       if (err) {
         appLogger.info('DatabaseManager.deleteDatabase, error: ' + ', err=' + err);
         appLogger.info('DatabaseManager.deleteDatabase.exit');
         return cb(new Error('Error dropping  user ' + userName + ', app ' + appId));
       }
       appLogger.info('DatabaseManager.deleteDatabase.exit');
       return;
    });
  }

  /**
   * Retrieve database
   */

  this.retrieveDatabase = function(databaseName, appId, cb)
  {
    appLogger.info('DatabaseManager.retrieveDatabase.enter');
    databaseNameRef = databaseName;
    appIdRef = appId;
    var sshpw = getPassword('ssh');
    var postgrespw = getPassword('postgres');
    var found = false;
    var connString = "postgres://postgres:"+postgrespw+"@dbaascluster:5432/postgres";
    var pgClient = new postgresql.Client(connString);
    var conn = new Client();
    var founddatabase;
    async.series([
      function(callback) {
        pgClient.connect(function(err) {
          if (err) {
            appLogger.info('DatabaseManager.retrieveDatabase, error connecting to postgresql at dbaascluster' + ', err=' + err);
            appLogger.info('DatabaseManager.retrieveDatabase.exit');
            return cb(new Error('Error connecting to postgresql at dbaascluster' + ', err=' + err),1,'Error connecting to postgresql at dbaascluster' + ', err=' + err);
          }
          pgClient.query("SELECT d.datcollate as classification,d.datctype as collation,pg_encoding_to_char(d.encoding) as encoding from pg_database d, pg_user u where u.usesysid = d.datdba and d.datname=$1 and pg_catalog.shobj_description(u.usesysid,'pg_authid')=$2",[databaseName,appId] ,function(err, result) {
            if (err) {
              appLogger.info('DatabaseManager.retrieveDatabase, error running query on dbaascluster' + ', err=' + err);
              appLogger.info('DatabaseManager.retrieveDatabase.exit');
              return cb(new Error('Error running query on dbaascluster' + ', err=' + err),1,'Error running query on dbaascluster' + ', err=' + err);
            }
            if (typeof result.rows[0] != "undefined") {
              founddatabase=databaseName;
              classification=result.rows[0].classification;
              collation=result.rows[0].collation;
              encoding=result.rows[0].encoding;
              callback();
            } else
            {
              appLogger.info('Did not find database ' + databaseName + ' under appid ' + appId + '.');
              return cb(new Error('Did not find database ' + databaseName + '.'),1,'Did not find database ' + databaseName + ' under appid '+appId);
            }
            pgClient.end();
          });
        });
      },
      function(callback) {
        conn.on('ready', function() {
          conn.exec('/var/www/html/get_user_list_for_db.sh '+databaseName, function(err, stream) {
            if (err) {
              appLogger.info('DatabaseManager.retrieveeDatabase, SSH error connecting to postgresql at dbaascluster' + ', err=' + err);
              appLogger.info('DatabaseManager.retrieveDatabase.exit');
              return cb(new Error('Error found: ' + err),1,'Error found: ' + err);
            }
            stream.on('close', function(code, signal) {
               appLogger.info('Stream :: close :: code: ' + code + ', signal: ' + signal);
              conn.end();
              callback();
            }).on('data', function(data) {
              appLogger.info("STDOUT: " + data);
              userlistMessage=data;
            }).stderr.on('data', function(data) {
              appLogger.info("STDERR: " + data);
              stderrMessage=data;
            });
          });
        }).connect({
          host: 'dbaascluster',
          port: 49155,
          username: 'root',
          password: sshpw
        });
      },
      function(callback) {
        if (typeof founddatabase != "undefined") {
          appLogger.info('Found database =  ' + founddatabase);
          rcode=0;
          appLogger.info('Generating JSON');
          userList=[];
          userlist=userlistMessage.toString().split(' ');
          appLogger.info('userlist = ' + userlist);
          for (var i=0; i< userlist.length; i++) {
            userList.push(userlist[i]);
          }
          finalJson = {'$schema': '/schemas/Database/v1.0',
            'Database': {
              'classification': classification,
              'collation': collation,
              'encoding': encoding,
              'instance': {
                 'host': 'dbaascluster',
                 'port': '9999'
              },
              'name': databaseName,
              'platform': 'postgresql',
              'users': userList
            }
          };
          message=JSON.stringify(finalJson);
          appLogger.info(JSON.stringify(finalJson));
          return cb(null, rcode, message);
        } else {
          rcode=1;
          message='Database ' + databaseName + ' not found.';
        }
        callback();
        return cb(null, rcode, message);
      }
    ], function(err) {
       if (err) {
         appLogger.info('DatabaseManager.retrieveDatabase, error: ' + ', err=' + err);
         appLogger.info('DatabaseManager.retrieveDatabase.exit');
         return cb(new Error('Database ' + databaseName + ' not found.'));
       }
       appLogger.info('DatabaseManager.retrieveDatabase.exit');
    });
  }

/*****
 * Retrieve database list TODO
 **/

  this.retrieveDatabaseList = function(cb)
  {
    appLogger.info('DatabaseManager.retrieveDatabaseList.enter');
    var sshpw = getPassword('ssh');
    var postgrespw = getPassword('postgres');
    var rowList = [];
    var databaseUserList = [];
    var finalJson;
    var connString = "postgres://postgres:"+postgrespw+"@dbaascluster:5432/postgres";
    var conn = new Client();
    var pgClient = new postgresql.Client(connString);
    async.series([
      function(callback) {
        pgClient.connect(function(err) {
          if (err) return callback(err);
          var pgsqlQuery = "SELECT datcollate as classification,datctype as collation,pg_encoding_to_char(encoding) as encoding, datname from pg_database where datname != 'postgres' and datname not like '%template%' order by datname";
          var resultrow = pgClient.query(pgsqlQuery ,function(err, result) {
            pgClient.end();
            if (err) return callback(err);
            result.rows.forEach(function(row) {
              appLogger.info('Found database =  ' + row.datname);
              rowList.push(row);
            });
            callback();
          });
        });
      },
      function(callback) {
        conn.on('ready', function() {
          conn.exec('/var/www/html/user_list_all_dbs.sh', function(err, stream) {
            if (err) {
              appLogger.info('DatabaseManager.retrieveDatabaseList, SSH error connecting to postgresql at dbaascluster' + ', err=' + err);
              appLogger.info('DatabaseManager.retrieveDatabase.exit');
              return cb(new Error('Error found: ' + err),1,'Error found: ' + err);
            }
            stream.on('close', function(code, signal) {
               appLogger.info('Stream :: close :: code: ' + code + ', signal: ' + signal);
              conn.end();
              callback();
            }).on('data', function(data) {
              appLogger.info("STDOUT: " + data);
              databaseUserList.push(data.toString().replace(/\n/gm,""));
            }).stderr.on('data', function(data) {
              appLogger.info("STDERR: " + data);
              stderrMessage=data;
            });
          });
        }).connect({
          host: 'dbaascluster',
          port: 49155,
          username: 'root',
          password: sshpw
        });
      },
      function(callback) {
        appLogger.info('Generating JSON');
        databaseList=[];
        len=rowList.length;
        for (i=0; i<len; ++i) {
          if (i in rowList) {
            r = rowList[i];
            dul = databaseUserList[i];
            dbJson = {
              'classification': r.classification,
              'collation': r.collation,
              'encoding': r.encoding,
              'instance': {
                 'host': 'dbaascluster',
                 'port': '9999'
              },
              'name': r.datname,
              'platform': 'postgresql',
              'users': dul
             }
             databaseList.push(dbJson);
           }
        }
        finalJson = {'$schema': '/schemas/DatabaseList/v1.0','DatabaseList':databaseList};
        appLogger.info(JSON.stringify(finalJson));
        appLogger.info('DatabaseManager.retrieveDatabaseList.exit');
        callback();
      } 
    ], function(err) {
       if (err) {
         appLogger.info('DatabaseManager.retrieveDatabaseList, error: ' + ', err=' + err);
         appLogger.info('DatabaseManager.retrieveDatabaseList.exit');
         return cb(new Error('Error found: ' + err));
       }
       return cb(null, finalJson);
    });
 }
}
