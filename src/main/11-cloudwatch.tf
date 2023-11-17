locals {
  dashboard_name = "${local.namespace}-dashboard"
}

resource "aws_cloudwatch_dashboard" "overview" {
  dashboard_name = "${local.dashboard_name}-overview"

  dashboard_body = <<EOF
{
  "widgets": [
    {
      "type": "metric",
      "x": 0,
      "y": 0,
      "width": 12,
      "height": 6,
      "properties": {
        "metrics": [
          ["AWS/ApiGateway", "5XXError", "ApiName", "${local.api_gateway_name}", "Stage", "${var.environment}", { "stat": "Sum" }]
        ],
        "period": 300,
        "region": "${var.aws_region}",
        "title": "API Gateway 5XX Requests"
      }
    },
    {
      "type": "metric",
      "x": 0,
      "y": 6,
      "width": 12,
      "height": 6,
      "properties": {
        "metrics": [
          ["AWS/ApiGateway", "4XXError", "ApiName", "${local.api_gateway_name}", "Stage", "${var.environment}", { "stat": "Sum" }]
        ],
        "period": 300,
        "region": "${var.aws_region}",
        "title": "API Gateway 4XX Requests"
      }
    },
    {
      "type": "metric",
      "x": 12,
      "y": 6,
      "width": 12,
      "height": 6,
      "properties": {
        "metrics": [
          ["AWS/EC2", "CPUUtilization", "AutoScalingGroupName", "${aws_eks_node_group.eks_node_group.resources[0].autoscaling_groups[0].name}", { "stat": "Average"}]
        ],
        "period": 300,
        "region": "${var.aws_region}",
        "title": "EKS Nodes CPU Utilizations"
      }
    },
    {
      "type": "metric",
      "x": 12,
      "y": 12,
      "width": 12,
      "height": 6,
      "properties": {
        "metrics": [
          ["AWS/EC2", "NetworkIn", "AutoScalingGroupName", "${aws_eks_node_group.eks_node_group.resources[0].autoscaling_groups[0].name}", { "stat": "Sum"}],
          ["AWS/EC2", "NetworkOut", "AutoScalingGroupName", "${aws_eks_node_group.eks_node_group.resources[0].autoscaling_groups[0].name}", { "stat": "Sum"}]
        ],
        "period": 300,
        "region": "${var.aws_region}",
        "title": "EKS Nodes Network Traffic"
      }
    }
  ]
}
EOF

  depends_on = [aws_api_gateway_rest_api.api, aws_eks_node_group.eks_node_group]
}

resource "aws_cloudwatch_dashboard" "api_details" {
  for_each = { for k, v in var.services : k => v if v.api_enabled }

  dashboard_name = "${local.dashboard_name}-${each.value.api_path}-api-details"

  dashboard_body = <<EOF
{
  "widgets": [
    {
      "type": "metric",
      "x": 0,
      "y": 0,
      "width": 12,
      "height": 6,
      "properties": {
        "metrics": [
          ["AWS/ApiGateway", "5XXError", 
            "ApiName", "${local.api_gateway_name}", 
            "Method", "GET", 
            "Resource", "/api/v1/${each.value.api_path}/{proxy+}", 
            "Stage", "${var.environment}", 
            { "stat": "Sum" }],
          ["AWS/ApiGateway", "4XXError", 
            "ApiName", "${local.api_gateway_name}", 
            "Method", "GET", 
            "Resource", "/api/v1/${each.value.api_path}/{proxy+}", 
            "Stage", "${var.environment}", 
            { "stat": "Sum" }]
        ],
        "period": 300,
        "region": "${var.aws_region}",
        "title": "GET tasks/ API Error"
      }
    },
    {
      "type": "metric",
      "x": 0,
      "y": 6,
      "width": 12,
      "height": 6,
      "properties": {
        "metrics": [
          ["AWS/ApiGateway", "5XXError", 
            "ApiName", "${local.api_gateway_name}", 
            "Method", "POST", 
            "Resource", "/api/v1/${each.value.api_path}/{proxy+}", 
            "Stage", "${var.environment}", 
            { "stat": "Sum" }],
          ["AWS/ApiGateway", "4XXError", 
            "ApiName", "${local.api_gateway_name}", 
            "Method", "POST", 
            "Resource", "/api/v1/${each.value.api_path}/{proxy+}", 
            "Stage", "${var.environment}", 
            { "stat": "Sum" }]
        ],
        "period": 300,
        "region": "${var.aws_region}",
        "title": "POST tasks/ API Error"
      }
    },
    {
      "type": "metric",
      "x": 12,
      "y": 6,
      "width": 12,
      "height": 6,
      "properties": {
        "metrics": [
          ["AWS/ApiGateway", "5XXError", 
            "ApiName", "${local.api_gateway_name}", 
            "Method", "PUT", 
            "Resource", "/api/v1/${each.value.api_path}/{proxy+}", 
            "Stage", "${var.environment}", 
            { "stat": "Sum" }],
          ["AWS/ApiGateway", "4XXError", 
            "ApiName", "${local.api_gateway_name}", 
            "Method", "PUT", 
            "Resource", "/api/v1/${each.value.api_path}/{proxy+}", 
            "Stage", "${var.environment}", 
            { "stat": "Sum" }]
        ],
        "period": 300,
        "region": "${var.aws_region}",
        "title": "PUT tasks/ API Error"
      }
    },
    {
      "type": "metric",
      "x": 12,
      "y": 12,
      "width": 12,
      "height": 6,
      "properties": {
        "view": "singleValue",
        "sparkline": false,
        "metrics": [
          ["AWS/ApiGateway", "Latency", 
            "ApiName", "${local.api_gateway_name}", 
            "Method", "GET", 
            "Resource", "/api/v1/${each.value.api_path}/{proxy+}", 
            "Stage", "${var.environment}", 
            { "stat": "Average", "period": 300 }],
          ["AWS/ApiGateway", "Latency", 
            "ApiName", "${local.api_gateway_name}", 
            "Method", "POST", 
            "Resource", "/api/v1/${each.value.api_path}/{proxy+}", 
            "Stage", "${var.environment}", 
            { "stat": "Average", "period": 300 }],
          ["AWS/ApiGateway", "Latency", 
            "ApiName", "${local.api_gateway_name}", 
            "Method", "PUT", 
            "Resource", "/api/v1/${each.value.api_path}/{proxy+}", 
            "Stage", "${var.environment}", 
            { "stat": "Average", "period": 300 }]
        ],
        "region": "${var.aws_region}",
        "title": "tasks/ API Latency"
      }
    }
  ]
}
EOF

  depends_on = [aws_api_gateway_rest_api.api, aws_eks_node_group.eks_node_group]
}
