import json

def send_notification(message):
    # Insert SNS code
    print(message)

def lambda_handler(event, context):
    output = []

    # Estrai il dettaglio dell'evento
    detail = event.get('detail', {})
    event_name = detail.get('eventName', "")
    request_parameters = detail.get('requestParameters', {})
    

    # Controlla se l'evento riguarda una Route Table
    if event_name in ["CreateRoute", "DeleteRoute", "ReplaceRouteTableAssociation"]:
        route_table_id = request_parameters.get('routeTableId', 'Unknown Route Table ID')
        output.append(f"Action on Route Table: {event_name} on {route_table_id}")
        
        # Dettagli specifici per le Route Tables
        if event_name == "CreateRoute":
            destination_cidr = request_parameters.get('destinationCidrBlock', 'Unknown CIDR')
            gateway_id = request_parameters.get('gatewayId', 'Unknown Gateway ID')
            output.append(f"- Route added to {route_table_id}: Destination {destination_cidr}, Gateway {gateway_id}")
        
        elif event_name == "DeleteRoute":
            destination_cidr = request_parameters.get('destinationCidrBlock', 'Unknown CIDR')
            output.append(f"- Route deleted from {route_table_id}: Destination {destination_cidr}")
        
        elif event_name == "ReplaceRouteTableAssociation":
            association_id = request_parameters.get('associationId', 'Unknown Association ID')
            subnet_id = request_parameters.get('subnetId', 'Unknown Subnet ID')
            new_route_table_id = request_parameters.get('routeTableId', 'Unknown New Route Table ID')
            output.append(f"- Route Table association changed: Association {association_id}, Subnet {subnet_id}, New Route Table {new_route_table_id}")
    
    # Controlla se l'evento riguarda un Security Group
    elif event_name in ["AuthorizeSecurityGroupIngress", "AuthorizeSecurityGroupEgress", "RevokeSecurityGroupIngress", 
                        "RevokeSecurityGroupEgress", "CreateSecurityGroup", "DeleteSecurityGroup", "ModifySecurityGroupRules"]:
        security_group_id = request_parameters.get('groupId', 'Unknown Security Group ID')
        output.append(f"Action on Security Group: {event_name} on {security_group_id}")
        
        # Dettagli specifici per i Security Groups (Ingress o Egress)
        ip_permissions = request_parameters.get('ipPermissions', {}).get('items', [])
        if not ip_permissions:
            output.append(f"- No IP permissions found for {event_name} on {security_group_id}")
        
        for permission in ip_permissions:
            # Verifica se permission è un dizionario
            if isinstance(permission, dict):
                from_port = permission.get('fromPort', 'All Ports')
                to_port = permission.get('toPort', 'All Ports')
                ip_protocol = permission.get('ipProtocol', 'Unknown Protocol')

                # Estrai gli IP ranges (IPv4)
                ip_ranges = permission.get('ipRanges', {}).get('items', [])
                for ip_range in ip_ranges:
                    if isinstance(ip_range, dict):
                        cidr_ip = ip_range.get('cidrIp', 'Unknown CIDR')
                        description = ip_range.get('description', 'No description')
                        output.append(f"- Protocol: {ip_protocol}, Ports: {from_port}-{to_port}, CIDR: {cidr_ip}, Description: {description}")

                # Estrai gli IP ranges (IPv6)
                ipv6_ranges = permission.get('ipv6Ranges', {}).get('items', [])
                for ipv6_range in ipv6_ranges:
                    if isinstance(ipv6_range, dict):
                        cidr_ipv6 = ipv6_range.get('cidrIpv6', 'Unknown CIDR')
                        description = ipv6_range.get('description', 'No description')
                        output.append(f"- Protocol: {ip_protocol}, Ports: {from_port}-{to_port}, CIDR (IPv6): {cidr_ipv6}, Description: {description}")
    
    else:
        output.append(f"Event {event_name} is not related to Route Tables or Security Groups.")
    
    # Estrai l'informazione sull'autore dell'azione
    user_identity = detail.get('userIdentity', {})
    user_type = user_identity.get('type', 'Unknown Type')
    user_name = user_identity.get('userName') or user_identity.get('principalId', 'Unknown User')
    output.append(f"Action performed by: {user_name} (Type: {user_type})")

    # Raggruppa tutti gli output in un'unica stringa
    final_output = "\n".join(output)
    send_notification(final_output)

    return {
        'statusCode': 200,
        'body': json.dumps('Lambda executed successfully')
    }
