# Deployment

## Steps

- create each lambda function
- each lambda function must have a role which has athena access and CW access
- Create API Gateway with 2 routes:
  - GET /measurements
  - GET /queries/{queryId}
- Each route must use lambda proxy
- API Gateway must be configured with a "CloudWatch log role ARN" which has access to CW logs and trust relationship with AWS API Gateway

## TODO

- Create Cloudformation template for the above
