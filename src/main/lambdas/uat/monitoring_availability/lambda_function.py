import boto3
import time
import datetime
import os

# Inizializza i client AWS
logs_client = boto3.client('logs')
sns_client = boto3.client('sns')
dynamodb = boto3.resource('dynamodb')
log_group_apig = os.environ['LOG_GROUP']
env = os.environ['ENV']
notification_topic = os.environ['MONITORING_NOTIFICATION_TOPIC_ARN']
alert_topic = os.environ['MONITORING_ALERT_TOPIC_ARN']

def lambda_handler(event, context):

    # Calcola start_time e end_time per coprire gli ultimi 15 minuti
    now = datetime.datetime.now().replace(second=0, microsecond=0)
    if now.minute % 15 != 0:
        now -= datetime.timedelta(minutes=1)
        now -= datetime.timedelta(minutes=now.minute % 15)
    start_time = int((now - datetime.timedelta(minutes=15)).timestamp())
    end_time = int(now.timestamp())
    
    # Definisci il log group di API Gateway
    log_group_name = log_group_apig  
    
    # Query per recuperare le info dell'availability
    availability_query = """
        fields @timestamp, @message
        | filter @message like /HTTP Method: POST - Resource Path: \/.*\/api\/v.*\/console-service\/task\/.* - Status: /
        | parse @message /Status: (?<status_code>\\d+)/
        | fields (status_code != 408 AND status_code != 429 AND status_code != 500 AND status_code != 501 AND status_code != 502 AND status_code != 503 AND status_code != 504 AND status_code != 209 ) as request_ok
        | stats count(*) as total_requests, sum(request_ok) as successfull_requests, avg(request_ok) * 100 as Availability
    """
    
    # Esegui la query 
    availability_result = execute_logs_insights_query(log_group_name, availability_query, start_time, end_time)
    total_requests = availability_result['total_requests'] if availability_result else 0
    successfull_requests = availability_result['successfull_requests'] if availability_result else 0
    availability = availability_result['Availability'] if availability_result else 0
    availability = round(availability, 2)

    #Se non ci sono richieste in ingresso non vi è indisponibilità del sistema
    if total_requests == 0:
        availability = 100
        
    start_time_str = datetime.datetime.fromtimestamp(start_time).strftime("%d/%m/%Y %H:%M:%S")
    end_time_str = datetime.datetime.fromtimestamp(end_time).strftime("%d/%m/%Y %H:%M:%S")
    
    table = dynamodb.Table('pagopa-atm-layer-monitoring')
    item_id = 'availability'
    
    #Verifico se l'availability era già in alert nella precedente rilevazione
    alreadyInAlert = isAvailabilityAlreadyInAlert(table, item_id)
    inAlert = False
    
    alertType = ''    
    eventType = 'create'
	# Controllo dell'availability
    if availability <= 20:
        #send_alert_notification(availability, start_time_str, end_time_str, eventType, alert_topic)
        send_email_notification(availability, start_time_str, end_time_str, eventType, alertType, env, notification_topic)
        inAlert = True
    elif availability > 20 and availability <= 80:
        alertType = '[INTERNAL] '
        send_email_notification(availability, start_time_str, end_time_str, eventType, alertType, env, notification_topic)
        if alreadyInAlert:
            eventType = 'close'
            #send_alert_notification(availability, start_time_str, end_time_str, eventType, alert_topic)
    elif availability > 80 and alreadyInAlert:
        eventType = 'close'
        #send_alert_notification(availability, start_time_str, end_time_str, eventType, alert_topic)

    updateTableAlerting(table, item_id, inAlert, availability)
        
    print("Start Time:", start_time_str, "- End Time:", end_time_str)
    print(f"Total requests: {total_requests}, Successful requests: {successfull_requests}, Availability: {availability}%")

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


def send_email_notification(availability, start_time, end_time, eventType, alertType, env, notification_topic):
    # Messaggio per la mail
    message = f"""Availability rilevata nell'intervallo di tempo {start_time} - {end_time} : {availability}%."""
    subject = f"""{alertType}Alert: Pago PA ATM Layer – [{env}] Availability"""
                     
    # Invia la mail tramite SNS
    sns_client.publish(
        TopicArn=notification_topic, 
        Message=message,
        Subject=subject
    )
    
def send_alert_notification(availability, start_time, end_time, eventType, alert_topic):
    # Messaggio nel topic opsgenie
    message = f"""Availability rilevata nell'intervallo di tempo {start_time} - {end_time} : {availability}%."""
    subject = f"""Alert: Pago PA ATM Layer – Availability"""
                     
    # Invio il messaggio al topic opsgenie tramie SNS
    sns_client.publish(
        TopicArn=alert_topic, 
        Message=message,
        Subject=subject,
        MessageAttributes={
        'AlarmName': {
            'DataType': 'String',
            'StringValue': 'Availability'
        }, 
        'eventType': {
            'DataType': 'String',
            'StringValue': eventType
        },
        'alias': {
            'DataType': 'String',
            'StringValue': 'Availability'
        }
    }
    )

def isAvailabilityAlreadyInAlert(table, id):
    # Recupera l'elemento dalla tabella
    response = table.get_item(Key={'id': id})
    
    # Estrai il valore di 'inAlert'
    item = response['Item']
    in_alert = item['inAlert']  # Recupera direttamente il valore di inAlert
    
    return in_alert
    
def updateTableAlerting(table, id, inAlert, availability):
    update_response = table.update_item(
            Key={'id': id},
            UpdateExpression="SET inAlert = :inAlertVal, #val = :newValue",
            ExpressionAttributeValues={
                ':inAlertVal': inAlert,
                ':newValue': availability
            },
            ExpressionAttributeNames={
                '#val': 'value'  # `value` è una parola riservata in DynamoDB, quindi deve essere sostituita con un alias
            },
            ReturnValues="UPDATED_NEW"
        )
    