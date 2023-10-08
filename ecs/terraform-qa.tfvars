name                  = "comms"
environment           = "qa"
availability_zones    = ["ap-south-1a", "ap-south-1b", "ap-south-1c"]
private_subnets       = [] #TODO: Add private ips for Prod
public_subnets        = ["10.0.0.0/20", "10.0.16.0/20", "10.0.32.0/20"]
service_desired_count = 1
s3_bucket_name        = "comms-qa-documents"