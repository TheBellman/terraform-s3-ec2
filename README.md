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
