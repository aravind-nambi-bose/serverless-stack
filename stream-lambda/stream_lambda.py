import boto3
from os import environ

def lambda_handler(event, context):
  for record in event["Records"]:
    item = dynamodb_get_data(record["dynamodb"]["Keys"]["id"]["S"])
    print(item["Item"]["subject"], '-->', item["Item"]["body"])
    publish_to_sns(
        item["Item"]["subject"],
        item["Item"]["body"]
    )

def dynamodb_get_data(id):
  table = boto3.resource('dynamodb').Table('serverlesstesttable')
  return table.get_item(Key = {'id':str(id)})

def publish_to_sns(sub, msg):
  topic_arn = environ["email_sns"]
  print(topic_arn)
  sns = boto3.client("sns")
  sns.publish(
      TopicArn=topic_arn,
      Message=msg,
      Subject=sub
  )

def main(argv):
  lambda_handler(None, None)

if __name__ == "__main__":
  main(sys.argv)