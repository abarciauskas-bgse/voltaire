const AWS = require('aws-sdk');
const knex = require('knex')({
  client: 'pg'//,
  // connection: process.env.PG_CONNECTION_STRING,
  // searchPath: ['knex', 'public'],
});

const athena = new AWS.Athena({
  region: 'us-east-1',
  apiVersion: '2017-05-18'
});

let params = {
  ResultConfiguration: { /* required */
    OutputLocation: process.env.OUTPUT_LOCATION, /* required */
    EncryptionConfiguration: {
      EncryptionOption: 'SSE_S3'
    }
  }
};

const _ = require('lodash');

function generateQuery(event) {
  // Initiate the quety string
  const table = `openaq_realtime_gzipped.fetches_realtime_gzipped`;
  let queryString = knex(table);

  const queries = event.queryStringParameters;
  // filter by one or more air quality parameters
  let aqParameterQueries = [];
  Object.keys(queries).forEach((key) => {
    if (key.includes('parameter')) {
      aqParameterQueries.push(queries[key]);
      delete queries[key];
    }
  });
  if (queries) {
    queryString = queryString.where(queries);      
  }
  if (aqParameterQueries.length > 0) {
    queryString = queryString.whereIn('parameter', aqParameterQueries);
  }
  queryString = queryString.select('*').limit(10).toString();
  return queryString;
}

function handler(event, context, cb) {
    const queryString = generateQuery(event);
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

module.exports = { handler, generateQuery };
