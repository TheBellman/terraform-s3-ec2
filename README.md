# terraform-s3-ec2

This project is to demonstrate the basis of restricting S3 access to specific EC2 instances. This should be in general terms a straightforward proposition, but the documentation around this is not ideal. The best resource is actually in the developer documentation at <https://docs.aws.amazon.com/AmazonS3/latest/dev/s3-access-control.html>, but even there it is not entirely obvious. There are a variety of ways to achieve the desired effect which are demonstrated by this set of scripts, but what is shown here is using an EC2 Instance Profile to grant specific access. The S3 buckets are created without assigning any rights (which fortunately now defaults to denying all access), and then the instance is configured to allow access to one of the buckets, but not the other.

It is assumed that you are familiar with both AWS and Terraform, and have a recent version of the AWS CLI and Terraform installed and in the operating path. In addition it is expected that you are executing the script using access credentials which has a high level of privilege, preferably full admin access. It is also assumed that you are running on some variety of Unix.

The scripts create two S3 buckets, some IAM role and policy artefacts, and an EC2 instance. More relevantly, it creates a VPC and subnet in which to place the instance. This is becoming my preference for doing this kind of exploratory work, as it allows good isolation of network resources, and good control over that isolation. The drawback is that there's more plumbing to set up before we can launch the EC2 instance, as we usually need to set up an Internet Gateway, routing tables, NACLs and Security Groups just to do something as simple as _ssh_ to the instance and perform a _yum update_.

## Usage
The top level `setup.sh` and `teardown.sh` scripts can be executed (as long as the `env.rc` has been setup correctly) to run up and tear down the assets. You will first need to copy the `env.rc.template` file to `env.rc`, then provide appropriate values:

| Value | Purpose |
| ----- | ------- |
| AWS_PROFILE | name of the AWS profile to use |
| AWS_DEFAULT_REGION | the region to build assets into |
| KEY_NAME | the name of the SSH keypair to create |
| CIDR | a CIDR block to allow SSH access from |

When you have executed `setup.sh` successfully, the EC2 instance should be up and running, and the SSH private key will be in the `data` directory (note that the `teardown.sh` script will remove this). The Terraform execution will report a variety of useful facts, including the names of the two buckets, and an example connection string, such as:
```
ssh -i data/s3ec2example.pem ec2-user@ec2-35-177-134-32.eu-west-2.compute.amazonaws.com
```

If you SSH to the host, you will be able to use the AWS CLI to explore the behaviour of access to the buckets.

A simple `list-buckets` will fail, as the instance does not have rights to list all of the buckets. Similarly attempting to do a "head" on the bucket which the instance has no rights to will fail:

```
[ec2-user@ip-172-40-1-188 ~]$ aws s3api list-buckets

An error occurred (AccessDenied) when calling the ListBuckets operation: Access Denied

[ec2-user@ip-172-40-1-188 ~]$ aws s3api head-bucket --bucket s3ec2test-closed-20180524161848095000000002

An error occurred (403) when calling the HeadBucket operation: Forbidden
```

In contrast, the instance can do a "head" on the open bucket, and list objects within it:

```
[ec2-user@ip-172-40-1-188 ~]$ aws s3api head-bucket --bucket s3ec2test-open-20180524161848095000000001
[ec2-user@ip-172-40-1-188 ~]$ aws s3api list-objects --bucket s3ec2test-closed-20180524161848095000000002

An error occurred (AccessDenied) when calling the ListObjects operation: Access Denied
[ec2-user@ip-172-40-1-188 ~]$ aws s3api list-objects --bucket s3ec2test-open-20180524161848095000000001
{
    "Contents": [
        {
            "Key": "test.txt",
            "LastModified": "2018-05-24T16:19:22.000Z",
            "ETag": "\"daf14106b2be2d68c24fbc04e76c81ef\"",
            "Size": 623,
            "StorageClass": "STANDARD",
            "Owner": {
                "ID": "81b0fd234b0c35d681cbf13a585e1153f03cb4973f5b0127339c967ddb452de9"
            }
        }
    ]
}
```

Finally, it is simple to demonstrate that the instance can read from one bucket, and not the other:

```
[ec2-user@ip-172-40-1-188 ~]$ aws s3api get-object  --bucket s3ec2test-open-20180524161848095000000001 --key test.txt test.txt
{
    "AcceptRanges": "bytes",
    "LastModified": "Thu, 24 May 2018 16:19:22 GMT",
    "ContentLength": 623,
    "ETag": "\"daf14106b2be2d68c24fbc04e76c81ef\"",
    "ContentType": "text/plain",
    "Metadata": {}
}

[ec2-user@ip-172-40-1-188 ~]$ ll
total 4
-rw-rw-r-- 1 ec2-user ec2-user 623 May 24 17:27 test.txt

[ec2-user@ip-172-40-1-188 ~]$ cat test.txt
When I do count the clock that tells the time,
And see the brave day sunk in hideous night,
When I behold the violet past prime,
And sable curls all silvered o'er with white:
When lofty trees I see barren of leaves,
Which erst from heat did canopy the herd
And summer's green all girded up in sheaves
Borne on the bier with white and bristly beard:
Then of thy beauty do I question make
That thou among the wastes of time must go,
Since sweets and beauties do themselves forsake,
And die as fast as they see others grow,
And nothing 'gainst Time's scythe can make defence
Save breed to brave him, when he takes thee hence.

[ec2-user@ip-172-40-1-188 ~]$ aws s3api get-object  --bucket s3ec2test-closed-20180524161848095000000002 --key test.txt test.txt

An error occurred (AccessDenied) when calling the GetObject operation: Access Denied
```

## AWS Policy

The core of the solution (in `main.tf`) is the policy attached to the IAM Instance Profile:

```
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:List*",
        "s3:Get*"
      ],
      "Resource": [
        "arn:aws:s3:::s3ec2test-open-20180524161848095000000001",
        "arn:aws:s3:::s3ec2test-open-20180524161848095000000001/*"
      ]
    }
  ]
}
```

This can be made even more precise as required - using the wildcard `List*` and `Get*` reveals quite a lot of information about the bucket and objects that an instance which just needs to be able to find and read objects won't need, so it is best to fine-tune the specific allowable resources. Similarly the resource key specified can easily be used to partition data and access to partitions of the data based on careful use of object keys.

Further security can be put in place using a combination of a VPC Endpoint, and policies on the buckets themselves. By associating a VPC endpoint with the subnet containing the instance, we can put a policy on the bucket that requires (for example) "get" operations to be sourced via the VPC endpoint. This will then prevent the objects being downloaded from the AWS console, or by a privileged user from anywhere other than the subnet. An alternative would have been to _not_ use the VPC endpoint, in which case the policy would have to restrict access to the _public_ IP address range for the EC2 instances.


# Security Notes
In addition to the constraints around the use of S3 buckets, this project demonstrates a fairly rigorous locking down of outgoing traffic from the EC2 instance. By default, security groups do not constrain connections initiated from the instance, and this leads to a lot of fairly simplistic thinking around how to lock down such outgoing connections. The internet is _littered_ with blogs and comments saying "oh, it's easy, just whitelist services", which turns out, broadly, to not work.

To begin with, this example includes the use of a VPC Endpoint for S3 access. This does _nothing_ to help with filtering outgoing traffic, all it does is help ensure that traffic remains within the AWS network rather than possibly traversing the broader internet. Traffic needs to be able to get out of the EC2 instance (past it's security group stateful firewall) and out of the subnet (past the NACL stateless firewall) before it can get routed through the VPC Endpoint, which is really just a specialised gateway.

As an aside, the VPC endpoint does not have a policy on it - ideally it does, but that's beyond the scope of what I wanted to do here.

Restricting outgoing access is a real problem if you want to do things like keep the EC2 instance updated and use any AWS services. To begin with, we need to crack open port 80 so that _yum_ can call out. Fortunately for at least the Amazon Linux instances, _yum_ comes wired to reach out to `http://amazonlinux.<REGION>.amazonaws.com`, and that resolves to a _somewhat_ predictable IP range (for `eu-west-1` this is probably `52.95.150.0/24` but I played it safe with `52.95.0.0/16`).

Restricting 443 is a much more painful problem: calls to the AWS API from the EC2 host travel (pretty obviously) off the host to various destinations in the AWS infrastructure via 443 using HTTPS. Block 443, and you block access to the AWS API. In this example I was able to open access to S3 by whitelisting the documented CIDR blocks for S3 for both `eu-west-1` *AND* `us-east-1`. It's not clear why the latter needs to be added, but it categorically does. Ok, great, the box that this example creates can execute _yum_ and use S3... but it can't use any other services unless we identify and whitelist more IP ranges, for both the target region and `us-east-1`.

Think about this for a moment. _Any_ services - IAM calls, use of KMS to encrypt data in the S3 bucket, DynamoDB calls. Blocking 443 _seriously_ hampers the ability of the host to do interesting and useful things.

It is broadly feasible to find the list of required CIDR blocks, as Amazon now list them. These resources can help you along the way:

 - [AWS Regions and Endpoints](https://docs.aws.amazon.com/general/latest/gr/rande.html)
 - [AWS IP Address Ranges](https://docs.aws.amazon.com/general/latest/gr/aws-ip-ranges.html)
 - [Terraform aws_ip_ranges](https://www.terraform.io/docs/providers/aws/d/ip_ranges.html) (this uses the IP Address Range file from above)

Playing with these will show that at the time of writing there are 203 CIDR blocks we need to whitelist, 78 for `eu-west-1` and 125 for `us-east-1`. This becomes a problem because there are quite small limits on how many rules Security Groups and NACLs are allowed to have. The list could be reduced somewhat by rolling up the various smaller CIDR blocks into `/16` blocks, but at that point, you have to ask what benefit you are getting.
