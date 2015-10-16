console.log('Loading function');
var AWS = require('aws-sdk');
var async = require('async');

var docClient = new AWS.DynamoDB.DocumentClient({region: 'us-east-1'});

exports.handler = function(event, context) {
    //console.log('Received event:', JSON.stringify(event, null, 2));
    
    var tableName = 'sensor';
    var processTime = new Date().toISOString();
    var pass = 0;
    var fail = 0;
    
    var workList = [];
    event.Records.forEach(function(record) {
                          
        // Kinesis data is base64 encoded so decode here
        var jsonPayload = new Buffer(record.kinesis.data, 'base64').toString('ascii');
                          
        var payload = JSON.parse(jsonPayload);
                          
        payload.data.forEach(function(entry) {
            var params = {
                TableName: tableName,
                Item: {
                    hashKey: payload.userId,
                    rangeKey: entry.ts,
                    phoneDate: payload.processDate,
                    batchId: payload.id,
                    processTime: processTime,
                    entry: entry
                }
            };
    
            workList.push({ params: params });
        });
    });
    
    var q = async.queue(function(task, callback) {
        docClient.put(task.params, function(err, data) {
            if (err) {
                console.log(err);
                fail++;
                callback(err);
            } else {
                pass++;
                callback();
            }
        });
    }, 8);
    q.drain = function() {
        console.log("Records: " + event.Records.length + " pass: " + pass + " fail: " + fail);
        context.succeed("done");
    };
    
    q.push(workList);
};
