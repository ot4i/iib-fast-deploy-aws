**Overview**

This repository contains a Quickstart for deploying IBM Integration Bus v10.0.0.11 and IBM MQ v9.0.4 to the AWS Cloud.

It uses the same technology that is used in AWS Quick Starts. Using this approach it is possible to deploy a fully functioning copy of an IBM Integration Bus integration node with an embedded queue manager and security enabled in around 30 minutes.

The facilities of the AWS Cloud environment are used to provide automatic restart of the Integration node and associated queue manager in a different, named, availability zone should there be a failure of the system as a whole, the Integration node or the Integration node queue manager.

**Deployment guides**

This contains the CloudFormation templates which can be used to build stacks using the publically avaialable AMI with the developer edition of IBM Integration Bus and IBM MQ. A guide for this deployment can be found here: https://developer.ibm.com/integration/blog/2018/01/16/quickstart-deployment-ibm-integration-bus-aws-cloud/

If you wish to build your own AMI, using differnt product versions, please follow the steps in this blog article:   https://developer.ibm.com/integration/blog/2018/01/16/building-amazon-machine-image-ibm-integration-bus/ and https://github.com/ot4i/iib-fast-deploy-aws
