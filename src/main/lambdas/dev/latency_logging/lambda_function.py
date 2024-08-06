import json

def lambda_handler(event, context):

    latency_type = event.get('latency_type')
    latency_value = event.get('latency_value')
    
    print("Latency ", latency_type, " [ms] = ", latency_value)