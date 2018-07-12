const AWS = require('aws-sdk');

const athena = new AWS.Athena({
  region: 'us-east-1',
  apiVersion: '2017-05-18'
});

let params = {
  ResultConfiguration: { /* required */
    OutputLocation: 's3://aws-athena-query-results-openaq', /* required */
    EncryptionConfiguration: {
      EncryptionOption: 'SSE_S3'
    }
  }
};

exports.handler = (event, context, cb) => {
    let queryString = `SELECT * FROM "openaq_realtime_gzipped"."fetches_realtime_gzipped" `;
    const queryKeys = Object.keys(event.queryStringParameters);
    const queryValues = Object.values(event.queryStringParameters);
    if (queryKeys.length > 0) {
        queryString += `WHERE ${queryKeys[0]} = '${queryValues[0]}' `;
    }
    queryString += `limit 10;`;
    console.log(`Query string is ${queryString}`);
    params.QueryString = queryString;

    let response = {
      isBase64Encoded: true,
      headers: {
        "Content-Type": "application/json"
      }
    };
    athena.startQueryExecution(params).promise()
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
