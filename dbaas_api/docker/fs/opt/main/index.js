/**
 * Copyright 2015 ARRIS Enterprises, Inc. All rights reserved.
 * This program is confidential and proprietary to ARRIS Enterprises, Inc. (ARRIS),
 * and may not be copied, reproduced, modified, disclosed to others, published or used,
 * in whole or in part, without the express prior written permission of ARRIS.
 */

/**
 * Main dbaas_api REST API Handlers
 */

/**
 * Import modules
 */
var express = require('express');
var router = express.Router();
var appLogger = require('../utils/app_logger');
var UserManager = require('./UserManager');
var DatabaseManager = require('./DatabaseManager');

/**
 * Global variables
 */

/**
 * GET home page. 
 */
router.get('/', function(req, res, next) {
  res.render('index', { title: 'Express' });
});

/** 
 * Handler for create user and alter user password
 */
router.put('/dbaas/v1.0/:platform/apps/:appId/users/:userName', function(req, res, next)
  {
    var platform = req.params.platform;
    var appId = req.params.appId.toLowerCase();
    var userName = req.params.userName;
    var password = req.query.pw;
    var oldPassword = req.query.oldPw;

    appLogger.info("DBAPI: Received create user request, platform=" + platform + ", appId=" + appId +
                   ", userName=" + userName + ", password=" + password + ", oldPassword=" + oldPassword);

    if (!platform || !appId || !userName || !password)
    {
      appLogger.info("DBAPI: Not all required parameters are supplied to create user");
      res.status(400).send("Not all required parameters are supplied to create user"); 
      return;
    }

    var userManager = new UserManager(platform, appId);

    try 
    { 
      var statcode = 201;
      var output_message='Created';
      if (!oldPassword) {
        userManager.createUser(userName, password, function (err, rcode, message) {
           if (err) {
             if (rcode == 1) {
               statcode= 200;
               output_message='';
             } else {
               if (rcode == 3) {
                 statcode= 409;
                 output_message=message;
               } else {
                 statcode= 404;
                 output_message='Failed';
               }
             }
             return;
           }
           if (rcode != 0) {
             if (rcode == 1) {
               statcode= 200;
               message='';
             } else {
               if (rcode == 3) {
                 statcode= 409;
                 output_message=message;
               } else {
                 statcode= 404;
                 output_message='Failed';
               }
             }
           }
           output_message=message;
           appLogger.info("DBAPI: statcode="+statcode);
           appLogger.info("DBAPI: output_message="+output_message);
         });
       } else {
         statcode = 200;
         output_message = 'User updated.'
         userManager.alterUserPassword(userName, password, oldPassword, function (err, rcode, message) {
           if (err) {
             if (rcode == 1) {
               statcode=403;
             } else {
               statcode= 404;
             }
             output_message=message;
             return;
           }
           if (rcode != 0) {
             if (rcode == 1) {
               statcode= 403;
             } else {
               statcode= 404;
             }
           }
           output_message=message;
           appLogger.info("DBAPI: statcode="+statcode);
           appLogger.info("DBAPI: output_message="+output_message);
         });
       }
       setTimeout (function () {
         res.status(statcode).send(output_message);
       }, 3000);
    }
    catch (err)
    {
      appLogger.info("DBAPI: Encountered error when creating user=" + userName + ", err=" + JSON.stringify(err));
      res.status(400).send("Encountered error when creating user: " + userName);
    }
  }
);

/**
 * Handler for create database, associate user, disassociate user, alter database owner
 */
router.put('/dbaas/v1.0/:platform/apps/:appId/databases/:databaseName', function(req, res, next)
  {
    var platform = req.params.platform;
    var appId = req.params.appId.toLowerCase();
    var databaseName = req.params.databaseName;
    var userName = req.query.user;
    var password = req.query.pw;
    var ownerName = req.query.owner;
    var targetUserName = req.query.targetUser;
    var action = req.query.action;
    var oldOwner = req.query.oldOwner;
    var oldOwnerPw = req.query.oldOwnerPw;
    var newOwner = req.query.newOwner;
    var potentialActivityFlag = 1;
    var potentialActivity = 'creating';
    if (!userName)
    {
      if (!oldOwner)
      {
        potentialActivity='associating';
        potentialActivityFlag=0;
        if (!platform || !appId || !databaseName || !ownerName || !password || !targetUserName || !action)
        {
          appLogger.info("DBAPI: Not all required parameters are supplied to associate database and user");
          res.status(400).send("Not all required parameters are supplied to associate database and user");
          return;
        }
        if (ownerName == targetUserName)
        {
          appLogger.info("DBAPI: Database owner cannot associate or disassociate itself.");
          res.status(403).send("Database owner cannot associate or disassociate itself.");
          return;
        }
        appLogger.info("DBAPI: Received associate user and database request, platform=" + platform + ", appId=" + appId + ", databaseName=" + databaseName + ", ownerName =" + ownerName + ", Password=" + password + ", targetUser = " + targetUserName + ", action = " + action);
      } else {
        potentialActivity='changedbowner';
        potentialActivityFlag=2;
        if (!platform || !appId || !oldOwner || !oldOwnerPw || !newOwner)
        {
          appLogger.info("DBAPI: Not all required parameters are supplied to alter database owner");
          res.status(400).send("Not all required parameters are supplied to alter database owner");
          return;
        }
        appLogger.info("DBAPI: Received alter database owner request, platform=" + platform + ", appId=" + appId + ", databaseName=" + databaseName + ", oldOwnerName =" + oldOwner + ", Password=" + oldOwnerPw + ", newOwner = " + newOwner);
      }
    } else {
      appLogger.info("DBAPI: Received create database request, platform=" + platform + ", appId=" + appId + ", databaseName=" + databaseName + ", userName =" + userName + ", Password=" + password);
      if (!platform || !appId || !databaseName || !userName || !password)
        {
          appLogger.info("DBAPI: Not all required parameters are supplied to create database");
          res.status(400).send("Not all required parameters are supplied to create database");
          return;
        }
    }
    appLogger.info("potentialActivity = "+potentialActivity);
    appLogger.info("potentialActivityFlag = "+potentialActivityFlag);
    var databaseManager = new DatabaseManager(platform, appId);
    try
    {
      if (potentialActivityFlag == 1)
      {
        var statcode = 201;
        var output_message='Created';
        databaseManager.createDatabase(databaseName, userName, password, function (err, rcode, message) {
           if (err) {
             if (rcode == 1) {
               statcode= 200;
             } else {
               if (rcode == 3) {
                 statcode= 409;
               } else {
                 statcode= 403;
               }
             }
             output_message=message;
             return;
           }
           if (rcode != 0) {
             if (rcode == 1) {
               statcode= 200;
             } else {
               if (rcode == 3) {
                 statcode= 409;
               } else {
                 statcode= 403;
               }
             }
           }
           output_message=message;
           appLogger.info("DBAPI: statcode="+statcode);
           appLogger.info("DBAPI: output_message="+output_message);
        });
        setTimeout (function () {
          res.status(statcode).send(output_message);
        }, 5000);
     } else {
        if (potentialActivityFlag == 2) {
          var statcode = 200;
          var output_message='';
          databaseManager.alterDatabaseOwner(databaseName, oldOwner, oldOwnerPw, newOwner, function (err, rcode, message) {
             if (err) {
               if (rcode == 2 || rcode == 3) {
                 statcode= 403;
               } else {
                 statcode= 404;
               }
               output_message=message;
               return;
             }
             if (rcode != 0) {
               if (rcode == 2 || rcode == 3) {
                 statcode= 403;
               } else {
                 statcode= 404;
               }
             }
             output_message=message;
             appLogger.info("DBAPI: statcode="+statcode);
             appLogger.info("DBAPI: output_message="+output_message);
            });
        } else {
          var statcode = 200;
          var output_message='';
          appLogger.info('action = '+action);     
          if ( action.toString() == 'remove') {
            databaseManager.disassociateDatabase(databaseName, ownerName, password, targetUserName, action, function (err, rcode, message) {
             if (err) {
               if (rcode == 2 || rcode == 3) {
                 statcode= 403;
               } else {
                 statcode= 404;
               }
               output_message=message;
               return;
             }
             if (rcode != 0) {
               if (rcode == 2 || rcode == 3) {
                 statcode= 403;
               } else {
                 statcode= 404;
               }
             }
             output_message=message;
             appLogger.info("DBAPI: statcode="+statcode);
             appLogger.info("DBAPI: output_message="+output_message);
            });
          } else {
            databaseManager.associateDatabase(databaseName, ownerName, password, targetUserName, action, function (err, rcode, message) {
             if (err) {
               if (rcode == 2 || rcode == 3) {
                 statcode= 403;
               } else {
                 statcode= 404;
               }
               output_message=message;
               return;
             }
             if (rcode != 0) {
                if (rcode == 2 || rcode == 3) {
                 statcode= 403;
               } else {
                 statcode= 404;
               }
             }
             output_message=message;
             appLogger.info("DBAPI: statcode="+statcode);
             appLogger.info("DBAPI: output_message="+output_message);
            });
          }
        }
        setTimeout (function () {
          res.status(statcode).send(output_message);
        }, 5000);
       }
    }
    catch (err)
    {
      appLogger.info("DBAPI: Encountered error when " + potentialActivity + " database=" + databaseName + ", err=" + JSON.stringify(err));
      res.status(400).send("Encountered error when " + potentialActivity + " database: " + databaseName);
    }
  }
);

/**
 * Handler for delete user
 */
router.delete('/dbaas/v1.0/:platform/apps/:appId/users/:userName', function(req, res, next)
  {
    var platform = req.params.platform;
    var appId = req.params.appId.toLowerCase();
    var userName = req.params.userName;
    var password = req.query.pw;

    appLogger.info("DBAPI: Received delete user request, platform=" + platform + ", appId=" + appId + ", userName=" + userName);

    if (!platform || !appId || !userName || !password )
    {
      appLogger.info("DBAPI: Not all required parameters are supplied to delete user");
      res.status(400).send("Not all required parameters are supplied to delete user");
      return;
    }

    var userManager = new UserManager(platform, appId);

    try
    {
      var statcode = 200;
      var output_message='OK';
      userManager.deleteUser(userName, password, function (err, rcode, message) {
         if (err) {
           if (rcode == 3) {
               statcode= 409;
           } else {
               if (rcode == 2) {
                 statcode= 403;
               } else {
                 statcode= 404;
               }
           }
           output_message=message;
           return;
         }
         if (rcode != 0) {
             if (rcode == 3) {
               statcode= 409;
             } else {
               if (rcode == 2) {
                 statcode= 403;
               } else {
                 statcode= 404;
               }
             }
         }
         output_message=message;
         appLogger.info("DBAPI: statcode="+statcode);
         appLogger.info("DBAPI: output_message="+output_message);
       });
       setTimeout (function () {
         res.status(statcode).send(output_message);
       }, 3000);
    }
    catch (err)
    {
      appLogger.info("DBAPI: Encountered error when deleting user=" + userName + ", err=" + JSON.stringify(err));
      res.status(400).send("Encountered error when deleting user: " + userName);
    }
  }
);

/**
 * Handler for delete database
 */
router.delete('/dbaas/v1.0/:platform/apps/:appId/databases/:databaseName', function(req, res, next)
  {
    var platform = req.params.platform;
    var appId = req.params.appId.toLowerCase();
    var databaseName = req.params.databaseName;
    var databaseOwner = req.query.owner;
    var password = req.query.pw;
    var targetUser = req.query.targetUser;
    var action = req.query.action;

    appLogger.info("DBAPI: Received delete database request, platform=" + platform + ", appId=" + appId + ", databaseName=" + databaseName + ", owner = " + databaseOwner);

    if (!platform || !appId || !databaseName || !databaseOwner || !password )
    {
      appLogger.info("DBAPI: Not all required parameters are supplied to delete database");
      res.status(400).send("Not all required parameters are supplied to delete database");
      return;
    }
    if (targetUser || action)
    {
      appLogger.info("DBAPI: Incorrect parameters are supplied for delete database");
      res.status(400).send("Incorrect parameters are supplied for delete database");
      return;
    }
    var databaseManager = new DatabaseManager(platform, appId);

    try
    {
      var statcode = 200;
      var output_message='OK';
      databaseManager.deleteDatabase(databaseName, databaseOwner, password, function (err, rcode, message) {
         if (err) {
           if (rcode == 2 || rcode == 3) {
             statcode= 403;
             output_message=message;
           } else {
             if (rcode == 5) {
               statcode= 409;
               output_message=message;
             } else {
               statcode= 404;
               output_message=message;
             }
           }
           return;
         }
         if (rcode != 0) {
           if (rcode == 2 || rcode == 3) {
             statcode= 403;
           } else {
             if (rcode == 5) {
               statcode= 409;
             } else {
               statcode= 404;
             }
           }
         }
         output_message=message;
         appLogger.info("DBAPI: statcode="+statcode);
         appLogger.info("DBAPI: output_message="+output_message);
       });
       setTimeout (function () {
         res.status(statcode).send(output_message);
       }, 13000);
    }
    catch (err)
    {
      appLogger.info("DBAPI: Encountered error when deleting database=" + databaseName + ", err=" + JSON.stringify(err));
      res.status(400).send("Encountered error when creatingi database: " + databaseName);
    }
  }
);

/**
 * Handler for get user 
 */
router.get('/dbaas/v1.0/:platform/apps/:appId/users/:userName?', function(req, res)
  {
    var platform = req.params.platform;
    var appId = req.params.appId.toLowerCase();
    var userName = req.params.userName;

    appLogger.info("DBAPI: Received retrieve user request, platform=" + platform + ", appId=" + appId + ",userName = " + userName);

    if (!platform || !appId )
    {
      appLogger.info("DBAPI: Not all required parameters are supplied for retrieve");
      res.status(400).send("Not all required parameters are supplied retrieve");
      return;
    }

    var userManager = new UserManager(platform, appId);

    try
    {
       var statcode = 200;
       var finalJson;
       if (!userName) {
         userManager.retrieveUserList(function (err,finalJson) {
           if (err) {
             statcode= 400;
             return "Encountered error when retrieving user list: " + err;
           }
           res.status(statcode).send(JSON.stringify(finalJson));
           appLogger.info("Final output = " + JSON.stringify(finalJson));
         });
       } else {
         userManager.retrieveUser(userName,function (err) {
           if (err) {
             statcode= 404;
             return;
           }
         });
         setTimeout (function () {
           res.status(statcode).send('');
         }, 1000);
       }
    }
    catch (err)
    {
      appLogger.info("Err = " + err);
      appLogger.info("DBAPI: Encountered error during retreive, err=" + JSON.stringify(err));
      res.status(400).send("Encountered error during retrieve");
    }
  }
);

/**
 * Handler for get database
 */
router.get('/dbaas/v1.0/:platform/apps/:appId/databases/:databaseName?', function(req, res, next)
  {
    var platform = req.params.platform;
    var appId = req.params.appId.toLowerCase();
    var databaseName = req.params.databaseName;

    appLogger.info("DBAPI: Received retrieve database request, platform=" + platform + ", appId=" + appId + ", databaseName=" + databaseName);

    if (!platform || !appId)
    {
      appLogger.info("DBAPI: Not all required parameters are supplied to retrieve database");
      res.status(400).send("Not all required parameters are supplied to retrieve database");
      return;
    }

    var databaseManager = new DatabaseManager(platform, appId);

    try
    {
       var statcode = 200;
       var output_message="";
       if (!databaseName) {
         databaseManager.retrieveDatabaseList(function (err,finalJson) {
           if (err) {
             statcode= 400;
             return "Encountered error when retrieving database list: " + err;
           }
           res.status(statcode).send(JSON.stringify(finalJson));
           appLogger.info("Final output = " + JSON.stringify(finalJson));
         });
       } else {
         databaseManager.retrieveDatabase(databaseName,appId,function (err) {
           if (err) {
             statcode= 404;
             output_message='Database not found under this appId.';
             return;
           }
           if (rcode != 0) {
             statcode= 404;
           }
           output_message=message;
           appLogger.info("DBAPI: statcode="+statcode);
           appLogger.info("DBAPI: output_message="+output_message);
         });
         setTimeout (function () {
           res.status(statcode).send(output_message);
         }, 2500);
       }
    }
    catch (err)
    {
      appLogger.info("Err = " + err);
      appLogger.info("DBAPI: Encountered error when retreiving database=" + databaseName + ", err=" + JSON.stringify(err));
      res.status(400).send("Encountered error when retrieving database: " + databaseName);
    }
  }
);

module.exports = router;
