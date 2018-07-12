const AWS = require('aws-sdk');

const athena = new AWS.Athena({
  region: 'us-east-1',
  apiVersion: '2017-05-18'
});

exports.handler = (event, context, cb) => {
  const params = {
    QueryExecutionId: event.pathParameters.queryId
  };

  let response = {
    isBase64Encoded: true,
    headers: {
      "Content-Type": "application/json"
    }
  };
  athena.getQueryExecution(params).promise()
     .then((data) => {
       console.log(`calling back with ${data}`)
       response.body = JSON.stringify(data);
       response.statusCode = 200;
       cb(null, response)
     })
     .catch((err) => {
       console.log(err);
       response.body = JSON.stringify({'error': err});
       response.statusCode = 500;         
       cb(null, response);
     });
};
