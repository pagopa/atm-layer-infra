import json
import boto3
import urllib.request
import os

def lambda_handler(event, context):
    url = "https://ip-ranges.amazonaws.com/ip-ranges.json"
    response = urllib.request.urlopen(url)
    data = json.loads(response.read())

    region = "eu-south-1"
    service = "AMAZON"

    ip_ranges = [
        prefix['ip_prefix'] for prefix in data['prefixes']
        if prefix['region'] == region and prefix['service'] == service
    ]

    ec2 = boto3.client('ec2', region_name='eu-south-1')
    prefix_list_id = os.environ['PREFIX_LIST_ID']
    
    # Get current entries and version
    prefix_list = ec2.describe_managed_prefix_lists(PrefixListIds=[prefix_list_id])['PrefixLists'][0]
    current_version = prefix_list['Version']
    
    # Retrieve all entries with pagination
    current_entries = []
    next_token = None
    
    while True:
        if next_token:
            response = ec2.get_managed_prefix_list_entries(PrefixListId=prefix_list_id, MaxResults=100, NextToken=next_token)
        else:
            response = ec2.get_managed_prefix_list_entries(PrefixListId=prefix_list_id, MaxResults=100)
        
        current_entries.extend(response['Entries'])
        next_token = response.get('NextToken')
        
        if not next_token:
            break

    current_ip_ranges = {entry['Cidr']: entry['Description'] for entry in current_entries}
    
    print(current_ip_ranges)

    # Determine changes
    ip_ranges_to_add = [ip for ip in ip_ranges if ip not in current_ip_ranges]
    ip_ranges_to_remove = [ip for ip in current_ip_ranges if ip not in ip_ranges]

    # Prepare modifications in batches
    batch_size = 100
    add_batches = [ip_ranges_to_add[i:i + batch_size] for i in range(0, len(ip_ranges_to_add), batch_size)]
    remove_batches = [ip_ranges_to_remove[i:i + batch_size] for i in range(0, len(ip_ranges_to_remove), batch_size)]
    
    print("IP to add: "+str(add_batches))
    print("IP to remove: "+str(remove_batches))

    # Apply modifications
    for add_batch in add_batches:
        ec2.modify_managed_prefix_list(
            PrefixListId=prefix_list_id,
            CurrentVersion=current_version,
            AddEntries=[{'Cidr': ip, 'Description': 'Added by Lambda'} for ip in add_batch]
        )
        current_version += 1

    for remove_batch in remove_batches:
        ec2.modify_managed_prefix_list(
            PrefixListId=prefix_list_id,
            CurrentVersion=current_version,
            RemoveEntries=[{'Cidr': ip} for ip in remove_batch]
        )
        current_version += 1

    return {
        'statusCode': 200,
        'body': json.dumps('Prefix list updated successfully')
    }
