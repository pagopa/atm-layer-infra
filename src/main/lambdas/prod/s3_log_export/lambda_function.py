import boto3
import json
import os
from datetime import datetime, timedelta

cw_client = boto3.client('logs')
s3_bucket = os.environ['DESTINATION_BUCKET']
log_group = os.environ['LOG_GROUP']

def lambda_handler(event, context):    
    try:
        yesterday = datetime.now() - timedelta(days=1)
        s3_prefix = yesterday.strftime('%Y/%m/%d')
        
        timestamp_start = int(datetime(yesterday.year, yesterday.month, yesterday.day, 0, 0).timestamp()*1000)
        timestamp_end = int(datetime(yesterday.year, yesterday.month, yesterday.day, 23, 59).timestamp()*1000)
        
        export = cw_client.create_export_task(
            logGroupName=log_group,
            fromTime=timestamp_start,
            to=timestamp_end,
            destination=s3_bucket,
            destinationPrefix=s3_prefix
        )
    
        return {
            'statusCode': 200,
            'body': json.dumps('Export task '+export["taskId"]+' started.')
        }
         
    except Exception as e:
        print ("Error: "+str(e))
        return {
            'statusCode': 500,
            'body': json.dumps('Error.')
        }
             
