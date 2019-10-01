import boto3
import uuid
import json
from datetime import datetime
from datetime import timedelta

def lambda_handler(event, context):

  user_data = json.loads(event["body"])

  user_data["id"] = str(uuid.uuid1())
  user_data["ExpirationTime"] = str(datetime.now() + timedelta(days=180))

  dynamo = boto3.resource('dynamodb').Table("serverlesstesttable")
  dynamo.put_item(Item = user_data)

  return {
    "statusCode": 200
  }

def main(argv):
  lambda_handler(None, None)

if __name__ == "__main__":
  main(sys.argv)