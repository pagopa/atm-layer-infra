import boto3
import time
import datetime
import os

logs_client = boto3.client('logs')
sns_client = boto3.client('sns')
log_group_latency = os.environ['LOG_GROUP']
env = os.environ['ENV']
notification_topic = os.environ['MONITORING_NOTIFICATION_TOPIC_ARN']

def lambda_handler(event, context):
    
    # Definisci la query
    latency_query = """
        fields @timestamp, @message
        | filter @message like /Latency Internal.*?\[ms\] = (\d+)/ or @message like /Latency External.*?\[ms\] = (\d+)/
        | parse @message /Latency Internal.*?\[ms\] = (?<internal_latency>\d+)/
        | parse @message /Latency External.*?\[ms\] = (?<external_latency>\d+)/
        | stats 
            round(avg(internal_latency), 2) as avg_internal_latency, 
            round(avg(external_latency), 2) as avg_external_latency,
            round(if((avg(internal_latency) - 250) < 0, 0, ((avg(internal_latency) - 250) / 250) * 100 - 0.10), 2) as percent_internal_latency_exceeding,
            round(if((avg(external_latency) - 5000) < 0, 0, ((avg(external_latency) - 5000) / 5000) * 100 - 0.10), 2) as percent_external_latency_exceeding
    """

    now = datetime.datetime.now().replace(second=0, microsecond=0)
    
    # Calcola il timestamp per l'ora di inizio (6 ore fa)
    start_time = int((now - datetime.timedelta(hours=6)).timestamp())
    
    # Calcola il timestamp per l'ora corrente (ora)
    end_time = int(now.timestamp())
    
    log_group_name = log_group_latency
    
     # Esegui la query 
    latency_result = execute_logs_insights_query(log_group_name, latency_query, start_time, end_time)

    percent_internal_latency_exceeding = latency_result.get('percent_internal_latency_exceeding', 0)
    percent_external_latency_exceeding = latency_result.get('percent_external_latency_exceeding', 0)
    
    start_time_str = datetime.datetime.fromtimestamp(start_time).strftime("%d/%m/%Y %H:%M:%S")
    end_time_str = datetime.datetime.fromtimestamp(end_time).strftime("%d/%m/%Y %H:%M:%S")
    
    if percent_internal_latency_exceeding > 0:
        send_email_notification(percent_internal_latency_exceeding, "Internal", start_time_str, end_time_str, env, notification_topic)
        
    if percent_external_latency_exceeding > 0:
        send_email_notification(percent_external_latency_exceeding, "External", start_time_str, end_time_str, env, notification_topic)
    
    print("Start Time:", start_time_str, "- End Time:", end_time_str)
    
    print(f"percent_internal_latency_exceeding: {percent_internal_latency_exceeding}%, percent_external_latency_exceeding: {percent_external_latency_exceeding}%")

def execute_logs_insights_query(log_group_name, query, start_time, end_time):
    # Inizia l'esecuzione della query
    start_query_response = logs_client.start_query(
        logGroupName=log_group_name,
        startTime=start_time,
        endTime=end_time,
        queryString=query,
    )
    
    query_id = start_query_response['queryId']
    
    # Aspetta che la query sia completata
    response = None
    while response == None or response['status'] == 'Running':
        time.sleep(1)
        response = logs_client.get_query_results(
            queryId=query_id
        )
    
    # Estrai i risultati
    for result in response['results']:
        if result:
            return {field['field']: float(field['value']) if '.' in field['value'] else int(field['value']) for field in result}
    return None

def send_email_notification(latency_exceeding, latency_type, start_time, end_time, env, notification_topic):
    # Messaggio per la mail
    message = f"""Rilevato sforamento Latency {latency_type} nell'intervallo di tempo {start_time} - {end_time}. Percentuale di sforamento: {latency_exceeding}%."""
    subject = f"""[INTERNAL] Alert: Pago PA ATM Layer – [{env}] {latency_type} Latency"""
                
    # Invia la mail tramite SNS
    sns_client.publish(
        TopicArn=notification_topic, 
        Message=message,
        Subject=subject
    )