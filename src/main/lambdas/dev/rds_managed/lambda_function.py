import boto3
import json
import os

rds = boto3.client('rds')
db_cluster = os.environ['DBCLUSTER']

def lambda_handler(event, context):
    action = event["action"]
    
    try:
        if action == "off":
            response = rds.stop_db_cluster(DBClusterIdentifier=db_cluster)
        elif action == "on":
            response = rds.start_db_cluster(DBClusterIdentifier=db_cluster)   
        else:
            raise RuntimeError('Action not valid.')

        return {
            'statusCode': 200,
            'body': json.dumps('Turn '+action+' successful.')
        }
         
    except Exception as e:
        print ("Error: "+str(e))
        return {
            'statusCode': 500,
            'body': json.dumps('Error.')
        }
