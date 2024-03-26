import boto3
import json
import os
from datetime import datetime, timedelta
import time

cw_client = boto3.client('logs')
s3_bucket = os.environ['DESTINATION_BUCKET']
log_groups = os.environ['LOG_GROUP'].split(',')

def wait_for_export_to_complete(task_id):
    while True:
        response = cw_client.describe_export_tasks(taskId=task_id)
        status = response['exportTasks'][0]['status']['code']
        if status in ['COMPLETED', 'FAILED', 'CANCELLED']:
            break
        else:
            print(f"Waiting for export task {task_id} to complete. Current status: {status}")
            time.sleep(10)  # Aspetta 30 secondi prima di controllare nuovamente lo stato.


def lambda_handler(event, context):    
    try:
        yesterday = datetime.now() - timedelta(days=1)
        s3_prefix = yesterday.strftime('%Y/%m/%d')
        
        timestamp_start = int(datetime(yesterday.year, yesterday.month, yesterday.day, 0, 0).timestamp()*1000)
        timestamp_end = int(datetime(yesterday.year, yesterday.month, yesterday.day, 23, 59).timestamp()*1000)
        
        for log_group in log_groups:
            export = cw_client.create_export_task(
                logGroupName=log_group,
                fromTime=timestamp_start,
                to=timestamp_end,
                destination=s3_bucket,
                destinationPrefix=s3_prefix+'/'+log_group.replace("/", "-")
            )
            
            print(f"Export task {export['taskId']} started.")
            
            wait_for_export_to_complete(export['taskId'])
    
        return {
            'statusCode': 200,
            'body': json.dumps('Export task completed.')
        }
         
    except Exception as e:
        print ("Error: "+str(e))
        return {
            'statusCode': 500,
            'body': json.dumps('Error.')
        }
             
