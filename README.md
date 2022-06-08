# Terraform Exercises
This repository contains Terraform exercises. The idea is to use Terraform to generate infrastructure according to the exercise. When studying Terraform or cloud providers,
it's easier to learn the concepts by doing exercises.

## VPC with public and private subnets

This exercise is in the folder [vpc-public-private-load-balancer](./vpc-public-private-load-balancer/).

![Exercise diagram](./vpc-public-private-load-balancer/exercise-web-architecture.png)

This exercise consists of creating a VPC with public and private subnets, and a load balancer in the public subnet.
In the private subnets, create 2 EC2 instances, one in each AZ. The instances should run a small web server.
Accessing to the Load Balancer should be possible from the internet. And the requests should be forwarder to the servers.

In this way we will have a fully isolated servers in a private subnet, and a load balancer in the public subnet.