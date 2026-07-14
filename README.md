<div align="center">

# 🛒 CloudCart Production DevOps Platform

### A production-style e-commerce platform built on AWS using modern Cloud and DevOps practices

[![AWS](https://img.shields.io/badge/AWS-Cloud-FF9900?logo=amazonaws&logoColor=white)](https://aws.amazon.com/)
[![Terraform](https://img.shields.io/badge/Terraform-IaC-844FBA?logo=terraform&logoColor=white)](https://www.terraform.io/)
[![Docker](https://img.shields.io/badge/Docker-Containers-2496ED?logo=docker&logoColor=white)](https://www.docker.com/)
[![Kubernetes](https://img.shields.io/badge/Kubernetes-Orchestration-326CE5?logo=kubernetes&logoColor=white)](https://kubernetes.io/)
[![Jenkins](https://img.shields.io/badge/Jenkins-CI%2FCD-D24939?logo=jenkins&logoColor=white)](https://www.jenkins.io/)
[![Status](https://img.shields.io/badge/Status-In%20Development-F59E0B)](#project-status)

</div>

---

## 📖 Project Overview

CloudCart is a production-style e-commerce platform created to demonstrate how a company application can be provisioned, deployed, secured, monitored and recovered using AWS and modern DevOps tools.

The project begins with a lightweight Nginx placeholder workload. It will gradually evolve into a complete application while the underlying infrastructure, CI/CD, container platform, security and observability systems are developed.

The main focus of this project is Cloud and DevOps engineering rather than frontend or backend development.

---

## 🎯 Project Objectives

- Provision AWS infrastructure using reusable Terraform modules
- Configure servers automatically using Ansible
- Containerize application services using Docker
- Build an automated Jenkins CI/CD pipeline
- Store approved container images in Amazon ECR
- Deploy workloads using Kubernetes and Helm
- Implement GitOps using Argo CD
- Add security and vulnerability scanning
- Monitor infrastructure and applications
- Demonstrate scaling, rollback, backup and recovery
- Maintain Free Tier-conscious lab and production-reference profiles
- Document errors, fixes and engineering decisions

---

## 🏗️ Architecture Strategy

This project contains two deployment profiles.

### Cost-Optimized Lab Profile

The lab profile is designed for hands-on deployment while controlling AWS usage.

```text
User
  │
  ▼
Nginx / EC2
  │
  ▼
Dockerized Application
  │
  ├── Health Checks
  ├── CloudWatch Logs
  └── Automated Jenkins Deployment