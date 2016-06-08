/**
 * Copyright 2015 ARRIS Enterprises, Inc. All rights reserved.
 * This program is confidential and proprietary to ARRIS Enterprises, Inc. (ARRIS),
 * and may not be copied, reproduced, modified, disclosed to others, published or used,
 * in whole or in part, without the express prior written permission of ARRIS.
 */

/**
 * This module handles database user management
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
var userNameRef;
var passwordRef;
var oldPasswordRef;
var child;

/**
 * Module class definition 
 */
module.exports = function(platform, appId) 
{
  appLogger.info("UserManager.enter");

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
   * Create user 
   */
  this.createUser = function(userName, password, cb)
  {
    appLogger.info("UserManager.createUser.enter");

    userNameRef = userName;
    passwordRef = password;
    create_user_command = '/var/www/html/create_user.sh ' + userName + ' ' + password + ' ' + appId + ' noadmin';
    var otherpgpoolhost;
    var sshpw = getPassword('ssh');
    var postgrespw = getPassword('postgres');
    var connString = "postgres://postgres:" + postgrespw + "@dbaascluster:9999/postgres";
    var stdoutMessage = '';
    var stderrMessage = '';
    var rcode=0;
    var message='Success';
    var userexists=0;
    var pgClient = new postgresql.Client(connString);
    var pgClient2 = new postgresql.Client(connString);
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
            appLogger.info('UserManager.createUser, error connecting to postgresql at dbaascluster' + ', err=' + err);
            appLogger.info('UserManager.createUser.exit');
            return cb(new Error('Error connecting to postgresql at dbaascluster' + ', err=' + err),2,'Error connecting to postgresql at dbaascluster' + ', err=' + err);
          }
          pgClient.query("SELECT pg_catalog.shobj_description(usesysid,'pg_authid') as userapp from pg_shadow r where r.usename=$1", [userName] ,function(err, result) {
            if (err) {
              appLogger.info('UserManager.createUser, error running query on dbaascluster' + ', err=' + err);
              appLogger.info('UserManager.createUser.exit');
              return cb(new Error('Error running query on dbaascluster' + ', err=' + err),2,'Error running query on dbaascluster' + ', err=' + err);
            }
            if (typeof result.rows[0] != "undefined") {
              appLogger.info('Found user = ' + userName + ' with old password, so will not attempt to create user.');
              if (result.rows[0].userapp.toString() == appId) {
                appLogger.info('User already exists under existing appId.  Checking password next...');
                userexists=1;
                callback();  
              } else {
                appLogger.info('AppId does not match.  Exit with error.');
                return cb(new Error('User ' + userName + ' already exists with a different appId than ' + appId),3,'User ' + userName + ' already exists with a different appId than ' + appId);
              }              
            } else
            {
              appLogger.info('Did not find user =  ' + userName + ' with old password, so continuing with create user.');
              callback();           
            }
            pgClient.end();
          });
        });
      },
      function(callback) {
        if ( userexists == 0 ) {callback();} else {
          pgClient2.connect(function(err) {
            if (err) {
              appLogger.info('UserManager.createUser, error connecting to postgresql at dbaascluster' + ', err=' + err);
              appLogger.info('UserManager.createUser.exit');
              return cb(new Error('Error connecting to postgresql at dbaascluster' + ', err=' + err),2,'Error connecting to postgresql at dbaascluster' + ', err=' + err);
            }
            pgClient2.query("SELECT r.usename from pg_shadow r where r.usename=$1 and r.passwd='md5'||MD5($2||$3)", [userName,password,userName] ,function(err, result) {
              if (err) {
                appLogger.info('UserManager.createUser, error running query on dbaascluster' + ', err=' + err);
                appLogger.info('UserManager.createUser.exit');
                return cb(new Error('Error running query on dbaascluster' + ', err=' + err),2,'Error running query on dbaascluster' + ', err=' + err);
              }
              if (typeof result.rows[0] != "undefined") {
                appLogger.info('Found user =  ' + userName + ' and verified old password, so this user already exists with this password.');
                return cb(new Error('Found user ' + userName + ' with appId ' + appId + 'and verified password.'),1,'Found user ' + userName + ' with appId ' + appId + 'and verified password.');
              } else {
                appLogger.info('Found existing user ' + userName + ' and password did not match.');
                return cb(new Error('Found existing user = ' + userName + ' and password did not match.'),3,'Found existing user ' + userName + ' and password did not match.');
              }
              pgClient2.end();
            });
          });
        }
      },
      function(callback) {
        conn2.on('ready', function() {
          conn2.exec(create_user_command, function(err, stream) {
            if (err) {
              appLogger.info('UserManager.createUser, SSH error connecting to postgresql at dbaascluster' + ', err=' + err);
              appLogger.info('UserManager.createUser.exit');
              return cb(new Error('Error found: ' + err),1,'Error found: ' + err);
            }
            stream.on('close', function(code, signal) {
              appLogger.info('Stream :: close :: code: ' + code + ', signal: ' + signal);
              conn2.end()
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
            conn3.exec(create_user_command, function(err, stream) {
              if (err) {
                appLogger.info('UserManager.createUser, SSH error connecting to postgresql at dbaascluster' + ', err=' + err);
                appLogger.info('UserManager.createUser.exit');
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
        return cb(null,rcode,message);
      }
    ], function(err) {
       if (err) {
         appLogger.info('UserManager.createUser, error: ' + ', err=' + err);
         appLogger.info('UserManager.createUser.exit');
         return cb(new Error('Error creating user ' + userName + ', app ' + appId));
       }
       appLogger.info('UserManager.createUser.exit');
       return;
    });
  }

  /**
   * Alter User Password
   */
  this.alterUserPassword = function(userName, password, oldPassword, cb)
  {
    appLogger.info("UserManager.alterUserPassword.enter");

    userNameRef = userName;
    passwordRef = password;
    oldPasswordRef = oldPassword;
    var sshpw = getPassword('ssh');
    var postgrespw = getPassword('postgres');
    alter_user_command = '/var/www/html/alter_user_password.sh ' + userName + ' ' + password + ' noadmin';
    var otherpgpoolhost;
    var connString = "postgres://postgres:" + postgrespw + "@dbaascluster:9999/postgres";
    var stdoutMessage = '';
    var stderrMessage = '';
    var rcode=0;
    var message='Success';
    var pgClient = new postgresql.Client(connString);
    var pgClient2 = new postgresql.Client(connString);
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
            appLogger.info('UserManager.alterUserPassword, error connecting to postgresql at dbaascluster' + ', err=' + err);
            appLogger.info('UserManager.alterUserPassword.exit');
            return cb(new Error('Error connecting to postgresql at dbaascluster' + ', err=' + err),2,'Error connecting to postgresql at dbaascluster' + ', err=' + err);
          }
          pgClient.query("SELECT pg_catalog.shobj_description(usesysid,'pg_authid') as userapp from pg_shadow r where r.usename=$1", [userName] ,function(err, result) {
            if (err) {
              appLogger.info('UserManager.alterUserPassword, error running query on dbaascluster' + ', err=' + err);
              appLogger.info('UserManager.alterUserPassword.exit');
              return cb(new Error('Error running query on dbaascluster' + ', err=' + err),2,'Error running query on dbaascluster' + ', err=' + err);
            }
            if (typeof result.rows[0] != "undefined") {
              appLogger.info('Found user = ' + userName + '.');
              if (result.rows[0].userapp.toString() == appId) {
                appLogger.info('User exists under existing appId.  Checking password next...');
                callback();
              } else {
                appLogger.info('AppId does not match.  Exit with error.');
                return cb(new Error('User ' + userName + ' already exists with a different appId than ' + appId),2,'User ' + userName + ' already exists with a different appId than ' + appId);
              }
            } else
            {
              appLogger.info('User ' + userName + ' does not exist.');
              return cb(new Error('User ' + userName + ' does not exist.'),3,'User ' + userName + ' does not exist.');
            }
            pgClient.end();
          });
        });
      },
      function(callback) {
        pgClient2.connect(function(err) {
          if (err) {
            appLogger.info('UserManager.alterUserPassword, error connecting to postgresql at dbaascluster' + ', err=' + err);
            appLogger.info('UserManager.alterUserPassword.exit');
            return cb(new Error('Error connecting to postgresql at dbaascluster' + ', err=' + err),2,'Error connecting to postgresql at dbaascluster' + ', err=' + err);
          }
          pgClient2.query("SELECT r.usename from pg_shadow r where r.usename=$1 and r.passwd='md5'||MD5($2||$3) and pg_catalog.shobj_description(usesysid,'pg_authid')=$4", [userName,oldPassword,userName,appId] ,function(err, result) {
            if (err) {
              appLogger.info('UserManager.alterUserPassword, error running query on dbaascluster' + ', err=' + err);
              appLogger.info('UserManager.alterUserPassword.exit');
              return cb(new Error('Error running query on dbaascluster' + ', err=' + err),2,'Error running query on dbaascluster' + ', err=' + err);
            }
            if (typeof result.rows[0] != "undefined") {
              appLogger.info('Found user ' + userName + ' with appId ' + appId + ',and verified old password, so continuing with alter user password.');
              callback();
            } else
            {
              appLogger.info('Password for user ' + userName + ' with appId ' + appId + ' was invalid, so will not attempt to alter user password.');
              return cb(new Error('Incorrect password for user ' + userName + ' and appId ' + appId),1,'Incorrect password for user ' + userName + ' and appId ' + appId);
            }
            pgClient2.end();
          });
        });
      },
      function(callback) {
        conn2.on('ready', function() {
          conn2.exec(alter_user_command, function(err, stream) {
            if (err) {
              appLogger.info('UserManager.alterUserPassword, SSH error connecting to postgresql at dbaascluster' + ', err=' + err);
              appLogger.info('UserManager.alterUserPassword.exit');
              return cb(new Error('Error found: ' + err),2,'Error found: ' + err);
            }
            stream.on('close', function(code, signal) {
              appLogger.info('Stream :: close :: code: ' + code + ', signal: ' + signal);
              conn2.end()
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
            conn3.exec(alter_user_command, function(err, stream) {
              if (err) {
                appLogger.info('UserManager.alterUserPassword, SSH error connecting to postgresql at dbaascluster' + ', err=' + err);
                appLogger.info('UserManager.alterUserPassword.exit');
                return cb(new Error('Error found: ' + err),2,'Error found: ' + err);
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
        return cb(null,rcode,message);
      }
    ], function(err) {
       if (err) {
         appLogger.info('UserManager.alterUserPassword, error: ' + ', err=' + err);
         appLogger.info('UserManager.alterUserPassword.exit');
         return cb(new Error('Error changing user password' + userName + ', app ' + appId),2,'Error changing user password' + userName + ', app ' + appId);
       }
       appLogger.info('UserManager.alterUserPassword.exit');
       return;
    });
  }

  /**
   * Delete user
   */
  this.deleteUser = function(userName, password, cb)
  {
    appLogger.info("UserManager.deleteUser.enter");

    userNameRef = userName;
    passwordRef = password;
    drop_user_command = '/var/www/html/drop_user.sh ' + userName + ' ' + password; 
    var otherpgpoolhost;
    var sshpw = getPassword('ssh');
    var postgrespw = getPassword('postgres');
    var connString = "postgres://postgres:" + postgrespw + "@dbaascluster:9999/postgres"; 
    var stdoutMessage = '';
    var stderrMessage = '';
    var rcode=0;
    var isUserThere=1;
    var message='Success';
    var pgClient = new postgresql.Client(connString);
    var pgClient2 = new postgresql.Client(connString);
    var pgClient3 = new postgresql.Client(connString);
    var conn = new Client();
    var conn2 = new Client();
    var conn3 = new Client();
    var conn4 = new Client();
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
            appLogger.info('UserManager.deleteUser, error connecting to postgresql at dbaascluster' + ', err=' + err);
            appLogger.info('UserManager.deleteUser.exit');
            return cb(new Error('Error connecting to postgresql at dbaascluster' + ', err=' + err),1,'Error connecting to postgresql at dbaascluster' + ', err=' + err);
          }
          pgClient.query("SELECT r.usename from pg_shadow r where r.usename=$1 and pg_catalog.shobj_description(usesysid,'pg_authid')=$2", [userName,appId] ,function(err, result) {
            if (err) {
              appLogger.info('UserManager.deleteUser, error running query on dbaascluster' + ', err=' + err);
              appLogger.info('UserManager.deleteUser.exit');
              return cb(new Error('Error running query on dbaascluster' + ', err=' + err),1,'Error running query on dbaascluster' + ', err=' + err);
            }
            if (typeof result.rows[0] != "undefined") {
              appLogger.info('Found user ' + userName + ' with appId ' + appId + ', so continuing with delete user.');
              callback();
            } else
            {
              appLogger.info('Did not find user ' + userName + ' with appId ' + appId + ', so will not attempt to delete user.');
              return cb(new Error('Did not user ' + userName + ' with appId ' + appId),1,'Did not find user ' + userName + ' with appId ' + appId); 
            }
            pgClient.end();
          });
        });
      },
      function(callback) {
        pgClient2.connect(function(err) {
          if (err) {
            appLogger.info('UserManager.deleteUser, error connecting to postgresql at dbaascluster' + ', err=' + err);
            appLogger.info('UserManager.deleteUser.exit');
            return cb(new Error('Error connecting to postgresql at dbaascluster' + ', err=' + err),1,'Error connecting to postgresql at dbaascluster' + ', err=' + err);
          }
          pgClient2.query("SELECT r.usename from pg_shadow r where r.usename=$1 and r.passwd='md5'||MD5($2||$3) and pg_catalog.shobj_description(usesysid,'pg_authid')=$4", [userName,password,userName,appId] ,function(err, result) {
            if (err) {
              appLogger.info('UserManager.deleteUser, error running query on dbaascluster' + ', err=' + err);
              appLogger.info('UserManager.deleteUser.exit');
              return cb(new Error('Error running query on dbaascluster' + ', err=' + err),1,'Error running query on dbaascluster' + ', err=' + err);
            }
            if (typeof result.rows[0] != "undefined") {
              appLogger.info('Found user =  ' + userName + ' with appId = ' + appId + ', so continuing with delete user.');
              callback();
            } else
            {
              appLogger.info('Incorrect password for user ' + userName + ' with appId ' + appId + ', so will not attempt to delete user.');
              return cb(new Error('Incorrect password for user ' + userName + ' with appId ' + appId),2,'Incorrect password for user ' + userName + ' with appId ' + appId);
            }
            pgClient2.end();
          });
        });
      },
      function(callback) {
        pgClient3.connect(function(err) {
          if (err) {
            appLogger.info('UserManager.deleteUser, error connecting to postgresql at dbaascluster' + ', err=' + err);
            appLogger.info('UserManager.deleteUser.exit');
            return cb(new Error('Error connecting to postgresql at dbaascluster' + ', err=' + err),1,'Error connecting to postgresql at dbaascluster' + ', err=' + err);
          }
          pgClient3.query("SELECT d.datname from pg_database d, pg_user u where d.datdba = u.usesysid and u.usename=$1",[userName] ,function(err, result) {
            if (err) {
              appLogger.info('UserManager.deleteUser, error running query on dbaascluster' + ', err=' + err);
              appLogger.info('UserManager.deleteUser.exit');
              return cb(new Error('Error running query on dbaascluster' + ', err=' + err),1,'Error running query on dbaascluster' + ', err=' + err);
            }
            if (typeof result.rows[0] == "undefined") {
              appLogger.info('User ' + userName + ' owns no databases.  Continuing.');
              callback();
            } else
            {
              appLogger.info('User = ' + userName + ' owns one or more databases, so will not attempt to delete user.');
              return cb(new Error('User ' + userName + ' owns one or more databases.'),3,'User ' + userName + ' owns one or more databases.');
            }
            pgClient3.end();
          });
        });
      },
      function(callback) {
        conn2.on('ready', function() {
          conn2.exec('/var/www/html/check_user_list_for_user.sh '+userName, function(err, stream) {
            if (err) {
              appLogger.info('UserManager.deleteUser, SSH error connecting to postgresql at dbaascluster' + ', err=' + err);
              appLogger.info('UserManager.deleteUser.exit');
              return cb(new Error('Error found: ' + err),1,'Error found: ' + err);
            }
            stream.on('close', function(code, signal) {
               appLogger.info('Stream :: close :: code: ' + code + ', signal: ' + signal);
              conn.end();
              callback();
            }).on('data', function(data) {
              appLogger.info("STDOUT: " + data);
              isUserThere=parseInt(data);
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
       if (isUserThere != 0) { callback();} else {
        conn3.on('ready', function() {
        conn3.exec(drop_user_command, function(err, stream) {
          if (err) {
            appLogger.info('UserManager.deleteUser, SSH error connecting to postgresql at dbaascluster' + ', err=' + err);
            appLogger.info('UserManager.deleteUser.exit');
            return cb(new Error('Error found: ' + err),1,'Error found: ' + err);;
          }
          stream.on('close', function(code, signal) {
            appLogger.info('Stream :: close :: code: ' + code + ', signal: ' + signal);
            conn3.end();
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
       }
      },
      function(callback) {
        if (isUserThere != 0 || otherpgpoolhost == 'NONE') { callback();} else {
          var pgp=otherpgpoolhost.toString();
          conn4.on('ready', function() {
            conn4.exec(drop_user_command, function(err, stream) {
              if (err) {
                appLogger.info('UserManager.deleteUser, SSH error connecting to postgresql at dbaascluster' + ', err=' + err);
                appLogger.info('UserManager.deleteUser.exit');
                return cb(new Error('Error found: ' + err),1,'Error found: ' + err);
              }
              stream.on('close', function(code, signal) {
                appLogger.info('Stream :: close :: code: ' + code + ', signal: ' + signal);
                conn4.end();
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
          rcode=2;
          message=stderrMessage;
        } else {
          rcode=0;
          message=stdoutMessage;
        }
        if (isUserThere != 0) {
          rcode=3;
          message='The user is still associated with one or more databases.';
        }
        callback();
        return cb(null,rcode,message);
      }
    ], function(err) {
       if (err) {
         appLogger.info('UserManager.deleteUser, error: ' + ', err=' + err);
         appLogger.info('UserManager.deleteeUser.exit');
         return cb(new Error('Error dropping  user ' + userName + ', app ' + appId));
       }
       appLogger.info('UserManager.deleteUser.exit');
       return;
    });
  }

  /**
   * Retrieve user
   */

  this.retrieveUser = function(userName, cb)
  {
    appLogger.info('UserManager.retrieveUser.enter');
    userNameRef = userName;
    var postgrespw = getPassword('postgres');
    var found = false;
    userNameRef = userName;
    var connString = "postgres://postgres:"+postgrespw+"@dbaascluster:5432/postgres";
    var pgClient = new postgresql.Client(connString);
    var founduser;
    async.series([
      function(callback) {
        pgClient.connect(function(err) {
          if (err) return callback(err);
          pgClient.query("SELECT r.rolname from pg_catalog.pg_roles r where r.rolname=$1 and pg_catalog.shobj_description(r.oid,'pg_authid')=$2", [userName,appId] ,function(err, result) {
            pgClient.end();
            if (err) return callback(err);
            if (typeof result.rows[0] != "undefined") {
              founduser = result.rows[0].rolname;
              appLogger.info('Found user here! ' + founduser);
              appLogger.info('UserManager.retrieveUser.exit');
            } 
            callback();
          });
        });
      },
      function(callback) {
        if (typeof founduser != "undefined") {
          appLogger.info('Found user =  ' + founduser);
        } else {
          return callback(new Error('User ' + userName + ', app ' + appId + ' not found.'));
        }
        callback();
      }
    ], function(err) {
       if (err) {
         appLogger.info('UserManager.retrieveUser, error: ' + ', err=' + err);
         appLogger.info('UserManager.retrieveUser.exit');
         return cb(new Error('User ' + userName + ', app ' + appId + ' not found.'));
       }
       appLogger.info('UserManager.retrieveUser.exit');
       return;
    });
  }

/*****
 * Retrieve user list
 **/

  this.retrieveUserList = function(cb)
  {
    appLogger.info('UserManager.retrieveUserList.enter');
    var postgrespw = getPassword('postgres');
    var userList = [];
    var finalJson;
    var connString = "postgres://postgres:"+postgrespw+"@dbaascluster:5432/postgres";
    var pgClient = new postgresql.Client(connString);
    async.series([
      function(callback) {
        pgClient.connect(function(err) {
          if (err) return callback(err);
          var pgsqlQuery = "SELECT r.rolname from pg_catalog.pg_roles r where pg_catalog.shobj_description(r.oid,'pg_authid') = '" + appId + "'"
          var resultrow = pgClient.query(pgsqlQuery ,function(err, result) {
            pgClient.end();
            if (err) return callback(err);
            result.rows.forEach(function(row) {
              appLogger.info('Found user =  ' + row.rolname);
              userList.push({'name':row.rolname});
            });
            callback();
          });
        });
      },
      function(callback) {
        appLogger.info('Generating JSON');
        finalJson = {'$schema': '/schemas/UserList/v1.0','UserList':userList};
        appLogger.info(JSON.stringify(finalJson));
        appLogger.info('UserManager.retrieveUserList.exit');
        callback();
      } 
    ], function(err) {
       if (err) {
         appLogger.info('UserManager.retrieveUserList, error: ' + ', err=' + err);
         appLogger.info('UserManager.retrieveUserList.exit');
         return cb(new Error('Error found: ' + err));
       }
       return cb(null, finalJson);
    });
 }
}
