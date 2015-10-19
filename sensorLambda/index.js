console.log('Loading function');
var AWS = require('aws-sdk');
var async = require('async');

var docClient = new AWS.DynamoDB.DocumentClient({region: 'us-east-1'});

exports.handler = function(event, context) {
    //console.log('Received event:', JSON.stringify(event, null, 2));
    
    var processTime = new Date().toISOString();
    var pass = 0;
    var fail = 0;
    var unproc = 0;
    
    var workList = [];
    event.Records.forEach(function(record) {
        
        // Kinesis data is base64 encoded so decode here
        var jsonPayload = new Buffer(record.kinesis.data, 'base64').toString('ascii');
        
        var payload = JSON.parse(jsonPayload);
                          
        console.log('Process user=' + payload.userId + ' batch=' + payload.id + ' size=' + payload.data.length);
        
        var batch = [];
        payload.data.forEach(function(entry) {
            batch.push({
                PutRequest : {
                    Item: {
                        hashKey: payload.userId,
                        rangeKey: entry.ts + '_' + processTime + '_' + context.awsRequestId,
                        pDate: payload.processDate,
                        bId: payload.id,
                        id: entry.id,
                        x: entry.x,
                        y: entry.y,
                        z: entry.z,
                    }
                }
            });
            if (batch.length >= 25) {
                workList.push({ params : batch });
                batch = [];
            }
        });
        if (batch.length > 0) {
            workList.push({ params : batch });
        }
    });
    
    var q = async.queue(function(task, callback) {
        // TODO get the table name set as a param
        var req = {
            RequestItems: {
                sensor: task.params
            }
        };
        docClient.batchWrite(req, function(err, data) {
            if (err) {
                console.log(err);
                fail++;
                callback(err);
            } else {
                pass += task.params.length;
                //unproc += data.UnprocessedItems.PutRequest.length;
                callback();
            }
        });
    }, 8);
    q.drain = function() {
        console.log('Records=' + event.Records.length + ' pass=' + pass + ' fail=' + fail + ' unproc=' + unproc);
        context.succeed("done");
    };
    
    q.push(workList);
};
