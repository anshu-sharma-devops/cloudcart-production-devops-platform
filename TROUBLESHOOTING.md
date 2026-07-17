# 🔧 CloudCart Troubleshooting Guide

This document records errors encountered while building the CloudCart production-style DevOps platform and the steps used to resolve them.

---



> **Security note:** Commands in this guide use placeholders. Never add AWS credentials, SSH private keys, Jenkins passwords, real public IP addresses, Terraform state, or sensitive inventory values to documentation.

---

## Quick Index

| Phase | Area | Issues documented |
|---:|---|---:|
| 1 | Docker, Compose and Nginx | 5 |
| 2 | Terraform and AWS networking | 5 |
| 3 | Terraform EC2 and SSH | 5 |
| 4 | Ansible and server configuration | 4 |
| 5 | Amazon ECR and IAM | 3 |
| 6 | Jenkins, Docker and Trivy | 4 |
| 7 | Kind and Kubernetes | 8 |
| 8 | Helm packaging and migration | 5 |
| 9 | Argo CD GitOps | 3 |
| 10 | Prometheus, Grafana and alerting | 3 |

---

# Phase 1 — Docker, Docker Compose and Nginx

## 1. Docker daemon was not running

### Symptom

```text
failed to connect to the docker API
dial unix .../.docker/run/docker.sock: connect: no such file or directory
```

### Root cause

The Docker CLI was installed, but Docker Desktop—and therefore the Docker daemon—was not running.

### Resolution

Start Docker Desktop and wait until the engine reports that it is running.

### Verification

```bash
docker info >/dev/null && echo "Docker is running"
docker ps
```

### Lesson

Installing a command-line client does not guarantee that its required background service is available. Add dependency checks before builds and CI jobs.

---

## 2. Container reported `unhealthy` while the endpoint worked manually

### Symptom

```text
STATUS: Up (...) (unhealthy)
wget: can't connect to remote host: Connection refused
```

However, a manual request succeeded:

```bash
docker exec cloudcart-placeholder \
  wget -S -O- http://127.0.0.1/health
```

### Root cause

The Docker health check used an address that did not resolve or connect correctly inside the container. Health checks run inside the container network namespace, not from the host.

### Resolution

Use the explicit loopback address:

```dockerfile
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget --quiet --tries=1 --spider http://127.0.0.1/health || exit 1
```

### Verification

```bash
docker inspect \
  --format='{{json .State.Health}}' \
  cloudcart-placeholder

curl -i http://localhost:8081/health
```

### Lesson

Test health commands from the same execution context used by the health checker.

---

## 3. Jenkins and CloudCart competed for port `8080`

### Symptom

A request intended for CloudCart returned Jenkins headers or redirected to a Jenkins URL:

```text
Server: Jetty
X-Jenkins: ...
Location: /health/
```

### Root cause

Jenkins was already listening on host port `8080`. The CloudCart mapping attempted to use the same host port.

### Resolution

Keep Jenkins on `8080` and map the local Docker workload to `8081`:

```yaml
ports:
  - "8081:80"
```

### Verification

```bash
docker compose ps
curl -i http://localhost:8081/health
curl -I http://localhost:8080/login
```

### Lesson

Document a local port allocation plan when multiple services run on one workstation.

---

## 4. Nginx container entered a restart loop

### Symptom

```text
Restarting (1)
curl: (7) Failed to connect
```

### Diagnosis

```bash
docker compose logs cloudcart-placeholder
```

### Root cause

The Nginx configuration contained invalid syntax, such as an extra closing brace.

### Resolution

Validate the configuration before starting the normal container:

```bash
docker run --rm \
  -v "$PWD/application/placeholder/nginx.conf:/etc/nginx/conf.d/default.conf:ro" \
  nginx:1.28.3-alpine nginx -t
```

Correct the syntax, rebuild, and recreate the workload:

```bash
docker compose up -d --build --force-recreate
```

### Lesson

Configuration validation belongs before deployment. This check was later added to Jenkins.

---

## 5. Requests failed after changing the Compose port

### Symptom

```text
curl: (7) Failed to connect to localhost port 8081
```

### Root cause

The container was still restarting, or the Compose service had not been recreated with the new port mapping.

### Resolution

```bash
docker compose down
docker compose up -d --build
docker compose ps
docker compose logs --tail=100 cloudcart-placeholder
```

### Verification

```bash
curl -i http://localhost:8081/health
```

---

# Phase 2 — Terraform and AWS Networking

## 6. Terraform module directory did not exist

### Symptom

```text
touch: infrastructure/modules/vpc/main.tf: No such file or directory
```

### Root cause

The parent module directory had not been created.

### Resolution

```bash
mkdir -p infrastructure/modules/vpc
touch infrastructure/modules/vpc/main.tf
touch infrastructure/modules/vpc/variables.tf
touch infrastructure/modules/vpc/outputs.tf
```

### Verification

```bash
tree infrastructure -L 4
```

### Lesson

`touch` creates a file, not missing parent directories.

---

## 7. Duplicate Terraform variable declarations

### Symptom

```text
Error: Duplicate variable declaration
A variable named "project_name" was already declared...
```

### Root cause

The same `variable` blocks were present in both `main.tf` and `variables.tf`. Terraform loads every `.tf` file in a directory as one module, so variable names must be unique across the entire directory.

### Diagnosis

```bash
grep -R -n '^variable "' infrastructure/modules/vpc
```

### Resolution

- Keep input declarations in `variables.tf`.
- Keep resources and child-module calls in `main.tf`.
- Keep exported values in `outputs.tf`.
- Remove duplicate declarations; do not rename duplicates to hide the problem.

### Verification

```bash
terraform -chdir=infrastructure/environments/lab fmt -check
terraform -chdir=infrastructure/environments/lab validate
```

### Lesson

Terraform file boundaries are for organization. All `.tf` files in one directory form a single module namespace.

---

## 8. Terraform initialized an empty directory

### Symptom

```text
Terraform initialized in an empty directory!
Error: No configuration files
```

### Root cause

Terraform was executed from `infrastructure/`, while the environment root configuration was located in `infrastructure/environments/lab/`.

### Resolution

Either change directory:

```bash
cd infrastructure/environments/lab
terraform init
terraform validate
terraform plan
```

Or use `-chdir` from the repository root:

```bash
terraform -chdir=infrastructure/environments/lab init
terraform -chdir=infrastructure/environments/lab validate
terraform -chdir=infrastructure/environments/lab plan
```

### Lesson

Always verify `pwd` and `ls` before running stateful infrastructure commands.

---

## 9. Terraform repeatedly prompted for `ssh_cidr`

### Symptom

```text
var.ssh_cidr
Administrator public IP address allowed to use SSH
Enter a value:
```

### Root cause

The variables file was named `terraform.tfvar` instead of `terraform.tfvars`. Terraform automatically loads `terraform.tfvars`, not the singular filename.

### Resolution

```bash
mv infrastructure/environments/lab/terraform.tfvar \
   infrastructure/environments/lab/terraform.tfvars
```

Confirm it is ignored:

```bash
git check-ignore infrastructure/environments/lab/terraform.tfvars
```

### Lesson

Terraform variable-file naming is exact. Real values should remain local and ignored; commit only `terraform.tfvars.example`.

---

## 10. Invalid SSH CIDR value

### Symptom

```text
ssh_cidr must be a valid IPv4 CIDR
var.ssh_cidr is "yes"
```

### Root cause

An interactive confirmation value was entered where Terraform expected an IPv4 CIDR.

### Resolution

Get the administrator”™s current public IP:

```bash
curl -s https://checkip.amazonaws.com
```

Store it using `/32` notation in the ignored `terraform.tfvars` file:

```hcl
ssh_cidr = "203.0.113.10/32"
```

The address above is documentation-only. Replace it with the actual current public IP.

### Lesson

Use input validation and least-privilege CIDRs. Never use `0.0.0.0/0` for SSH in this lab.

---

# Phase 3 — Terraform EC2 and SSH

## 11. EC2 variables and module call were placed inside the VPC module

### Symptom

Terraform reported that the VPC module required unrelated inputs such as:

```text
instance_type
key_name
ssh_cidr
root_volume_size
```

### Root cause

EC2 variable blocks and a child EC2 module call were accidentally copied into `infrastructure/modules/vpc/main.tf`.

### Diagnosis

```bash
grep -R -n \
  -e 'instance_type' \
  -e 'key_name' \
  -e 'ssh_cidr' \
  -e 'root_volume_size' \
  infrastructure/modules/vpc
```

### Resolution

- Keep VPC resources only in `modules/vpc`.
- Keep EC2 resources only in `modules/ec2`.
- Call both modules independently from `environments/lab/main.tf`.

### Verification

```bash
terraform -chdir=infrastructure/environments/lab fmt -recursive
terraform -chdir=infrastructure/environments/lab validate
```

### Lesson

Modules should have one clear responsibility. Cross-contamination creates confusing required arguments and weak reuse boundaries.

---

## 12. Duplicate EC2 variables existed in `main.tf` and `variables.tf`

### Symptom

```text
Duplicate variable declaration: instance_type
Duplicate variable declaration: key_name
Duplicate variable declaration: ssh_cidr
Duplicate variable declaration: root_volume_size
```

### Resolution

Remove `variable` blocks from `main.tf` and declare each input once in `variables.tf`.

### Verification

```bash
grep -R -n '^variable "' \
  infrastructure/environments/lab \
  infrastructure/modules/ec2
```

---

## 13. Terraform plan applied zero EC2 resources

### Symptom

```text
Apply complete! Resources: 0 added, 0 changed, 0 destroyed.
```

The output contained only VPC values, and the state had no EC2 module:

```bash
terraform state list | grep module.ec2
```

### Root cause

The root environment did not yet contain the `module "ec2"` block, so Terraform had no EC2 resources in its desired state.

### Resolution

Add the EC2 module call to `infrastructure/environments/lab/main.tf`, reference the VPC outputs, then run a new plan.

### Lesson

An `apply` can succeed while doing nothing. Review the plan summary and state list instead of treating exit code zero as proof that the intended resources exist.

---

## 14. SSH private key path was incorrect

### Symptom

```text
no such identity: ~/.ssh/jenkins-key.pem
Permission denied (publickey)
```

### Root cause

The key existed in `~/Downloads`, but SSH and Ansible were configured to use `~/.ssh`.

### Diagnosis

```bash
find ~/.ssh ~/Desktop ~/Downloads \
  -name "jenkins-key.pem" \
  -type f 2>/dev/null
```

### Resolution

Use the actual local path and restrict permissions:

```bash
chmod 400 ~/Downloads/jenkins-key.pem
ssh -i ~/Downloads/jenkins-key.pem ubuntu@<APP_HOST>
```

Update the ignored Ansible inventory to use the same path.

### Lesson

The private key is a local workstation file. A macOS path will not exist after connecting to the Ubuntu EC2 host.

---

## 15. EC2 public IP changed after stopping and starting the instance

### Symptom

SSH, Ansible, Jenkins, or browser requests failed even though the instance was running.

### Root cause

A normal public IPv4 address can change when an instance is stopped and started.

### Resolution

Retrieve the current value from Terraform or AWS, then update ignored local configuration and Jenkins parameters:

```bash
terraform -chdir=infrastructure/environments/lab output -raw app_public_ip
```

### Lesson

Do not hard-code temporary public addresses. A production environment would normally use DNS and a load balancer rather than distributing instance IPs.

---

# Phase 4 — Ansible and Server Configuration

## 16. Ansible could not reach the EC2 host

### Symptom

```text
UNREACHABLE
Permission denied (publickey)
```

### Root cause

The inventory used a missing private-key path, an outdated public IP, or the current administrator IP was not allowed by the security group.

### Verification checklist

```bash
terraform -chdir=infrastructure/environments/lab output -raw app_public_ip
chmod 400 <PATH_TO_PRIVATE_KEY>
ansible-inventory --graph
ansible cloudcart_lab -m ping
```

### Lesson

Test raw SSH first, then Ansible. This separates network and authentication problems from playbook problems.

---

## 17. Ubuntu 24.04 could not install the `awscli` apt package

### Symptom

```text
No package matching 'awscli' is available
```

### Root cause

The expected `awscli` package was unavailable from the enabled Ubuntu 24.04 repositories.

### Resolution

Install AWS CLI v2 using the official AWS installer from Ansible:

1. Install `curl` and `unzip`.
2. Download the architecture-appropriate AWS CLI v2 archive.
3. Extract it.
4. Run the installer.
5. Verify `/usr/local/bin/aws --version`.

### Verification

```bash
ansible cloudcart_lab -m command \
  -a "/usr/local/bin/aws --version"
```

### Lesson

Package availability differs by operating-system release. Automation should use a supported installation source and verify the resulting binary.

---

## 18. Ansible role failed YAML parsing

### Symptom

```text
YAML parsing failed
did not find expected key
```

### Root cause

A task beginning with `- name:` was indented as though it were nested inside the previous task.

### Resolution

Align every top-level task at the same indentation level:

```yaml
---
- name: First task
  ansible.builtin.debug:
    msg: "first"

- name: Second task
  ansible.builtin.debug:
    msg: "second"
```

### Verification

```bash
ansible-playbook --syntax-check ansible/playbooks/deploy-cloudcart.yml
```

### Lesson

Run syntax checks after every YAML edit and before connecting to a remote host.

---

## 19. AWS CLI command failed on EC2

### Symptom

```text
No such file or directory: aws
```

### Root cause

AWS CLI was not yet installed or its location was not available in the non-interactive Ansible PATH.

### Resolution

Install AWS CLI v2 and use its explicit path during verification:

```bash
ansible cloudcart_lab -m command \
  -a "/usr/local/bin/aws sts get-caller-identity"
```

### Lesson

Non-interactive automation may have a different PATH from an interactive SSH shell.

---

# Phase 5 — Amazon ECR and IAM

## 20. EC2 needed ECR access without stored AWS keys

### Problem

The EC2 host needed permission to inspect and pull private ECR images, but storing an IAM user’s long-lived access keys on the host would be insecure.

### Resolution

Attach an IAM role to the EC2 instance with the required ECR read permissions. AWS supplies temporary credentials through the instance metadata service.

### Verification

```bash
ansible cloudcart_lab -m command \
  -a "/usr/local/bin/aws sts get-caller-identity"

ansible cloudcart_lab -m command \
  -a "/usr/local/bin/aws ecr describe-repositories --region ap-south-1"
```

The returned identity should be an assumed role associated with the EC2 instance, not an IAM user access key.

### Lesson

Prefer temporary role credentials over distributing long-lived secrets.

---

## 21. ECR authentication is temporary

### Symptom

```text
no basic auth credentials
```

### Root cause

Docker had not logged in to the private ECR registry, or its ECR authorization token had expired.

### Resolution

```bash
aws ecr get-login-password --region ap-south-1 | \
  docker login \
    --username AWS \
    --password-stdin <ECR_REGISTRY>
```

### Lesson

ECR login tokens are temporary. Authenticate during the pipeline or deployment rather than treating Docker login as permanent configuration.

---

## 22. Immutable ECR tag could not be overwritten

### Symptom

An image push failed because the same tag already existed in an immutable repository.

### Root cause

Tag immutability was enabled intentionally.

### Resolution

Publish a new version tag instead of overwriting an existing release:

```text
v1.0.1 → v1.0.2 → v1.0.3
```

### Lesson

Immutable artifacts improve traceability. A new build should create a new version rather than mutating a previously deployed version.

---

# Phase 6 — Jenkins CI/CD

## 23. Jenkins pipeline could not access Docker

### Symptom

```text
failed to connect to the docker API
...docker.sock: connect: no such file or directory
```

### Root cause

The local Jenkins process attempted to run Docker while Docker Desktop was not running.

### Resolution

Start Docker Desktop and verify access before triggering the pipeline:

```bash
docker info >/dev/null && echo "Docker is running"
```

### Improvement

Add an early Jenkins preflight stage so the pipeline fails with a short, intentional message before checkout/build work begins.

---

## 24. Trivy blocked the image because of a critical vulnerability

### Symptom

The `Security Scan` stage failed with a critical OpenSSL/Alpine vulnerability.

### Root cause

The pinned base image contained installed packages with a critical vulnerability that had a newer fixed package release.

### Resolution

Update packages during the image build:

```dockerfile
RUN apk upgrade --no-cache
```

Rebuild and scan again under the configured policy:

```bash
trivy image \
  --exit-code 1 \
  --severity CRITICAL \
  --ignore-unfixed \
  --scanners vuln \
  <IMAGE_URI>
```

### Lesson

A security gate is valuable when it blocks a release. Record both the failure and the remediation as evidence.

> Passing this policy means no matching critical vulnerabilities were detected under the configured options. It does not prove that an image has no security risk.

---

## 25. ARM workstation and AMD64 EC2 architecture mismatch

### Risk

The development Mac uses ARM64, while the EC2 instance uses AMD64. A native ARM image may not run on the AWS host.

### Resolution

Build the deployment image explicitly for AMD64:

```bash
docker build \
  --platform linux/amd64 \
  -t <IMAGE_URI> \
  application/placeholder
```

Use the same platform when running the CI test container.

### Lesson

Container images are portable only when the target CPU architecture is available in the image manifest.

---

## 26. Git push was rejected after committing the Jenkinsfile

### Symptom

```text
remote rejected main -> main
fatal error in commit_refs
```

### Resolution workflow

Confirm the local commit, fetch the remote, and retry without rewriting or discarding work:

```bash
git status
git log -1 --oneline
git pull --rebase origin main
git push origin main
```

If the remote service reports an internal failure and the branch is otherwise synchronized, retry after confirming GitHub status.

### Lesson

Do not repeat commits or force-push automatically after a remote error. First determine whether the commit exists locally or remotely.

---

# Phase 7 — Kind and Kubernetes

## 27. `kubectl` pointed to a deleted EKS cluster

### Symptom

```text
Unable to connect to the server
dial tcp: lookup ...eks.amazonaws.com: no such host
```

### Root cause

The active kubeconfig context referenced an older EKS cluster that no longer existed.

### Diagnosis

```bash
kubectl config current-context
kubectl config get-contexts
```

### Resolution

After creating the Kind cluster, select its context:

```bash
kubectl config use-context kind-cloudcart
kubectl get nodes
```

Remove only a confirmed stale context when appropriate:

```bash
kubectl config delete-context <STALE_CONTEXT_NAME>
```

### Lesson

Always confirm the active cluster before applying or deleting Kubernetes resources.

---

## 28. Kind command was unavailable

### Symptom

```text
zsh: command not found: kind
```

### Resolution on macOS

```bash
brew install kind
kind version
```

### Lesson

Check tool prerequisites and versions before starting a phase.

---

## 29. Kustomize path contained `kubernetes/kubernetes`

### Symptom

```text
not a valid directory
.../kubernetes/kubernetes: no such file or directory
```

### Root cause

The current directory was already `kubernetes/`, but the command used `kubernetes/base` again.

### Resolution

From `kubernetes/`:

```bash
kubectl apply -k base
```

From the repository root:

```bash
kubectl apply -k kubernetes/base
```

### Lesson

Paths are relative to the current directory. Run `pwd` before repeating a failing command.

---

## 30. Server-side dry run could not find the new Namespace

### Symptom

```text
namespace/cloudcart created (server dry run)
Error from server (NotFound): namespaces "cloudcart" not found
```

### Root cause

Server-side dry run validated the Namespace but did not persist it. Namespaced resources in the same request were then validated against a Namespace that did not actually exist.

### Resolution

Use client-side dry run for the initial complete set:

```bash
kubectl apply -k kubernetes/base --dry-run=client
```

Then perform the real apply:

```bash
kubectl apply -k kubernetes/base
```

Alternatively, create the Namespace first, then use server-side validation for the remaining resources.

### Lesson

Dry-run behavior matters when one resource depends on another resource being persisted.

---

## 31. Deployment rollout timed out with `CrashLoopBackOff`

### Symptom

```text
0 of 2 updated replicas are available
error: timed out waiting for the condition
CrashLoopBackOff
Startup probe failed: connect: connection refused
```

### Diagnosis

```bash
kubectl get pods -n cloudcart -o wide

kubectl logs -n cloudcart deployment/cloudcart \
  --all-pods=true \
  --previous \
  --tail=100

kubectl describe pod -n cloudcart \
  $(kubectl get pods -n cloudcart \
    -o jsonpath='{.items[0].metadata.name}')
```

### Root cause

The hardened container dropped every Linux capability. Nginx required permission to bind to port 80.

### Resolution

Keep the restricted context while adding only the required capability:

```yaml
securityContext:
  allowPrivilegeEscalation: false
  capabilities:
    drop:
      - ALL
    add:
      - NET_BIND_SERVICE
```

### Verification

```bash
kubectl apply -k kubernetes/base
kubectl rollout status deployment/cloudcart -n cloudcart --timeout=180s
kubectl get pods -n cloudcart -o wide
```

### Lesson

Least privilege means granting the minimum capabilities required—not assuming that removing every capability will preserve application functionality.

---

## 32. Kubernetes manifest had a YAML indentation error

### Symptom

```text
MalformedYAMLError
mapping values are not allowed in this context
```

### Root cause

The `securityContext` or topology-spread block was inserted at the wrong indentation level.

### Diagnosis

```bash
nl -ba kubernetes/base/deployment.yaml | sed -n '50,100p'
```

### Resolution

- Align `securityContext` with other container properties such as `resources`.
- Align `topologySpreadConstraints` with `containers` under the pod `spec`.
- Use spaces, not tabs.
- Remove Markdown fences accidentally pasted into YAML files.

### Verification

```bash
kubectl apply -k kubernetes/base --dry-run=client
```

### Lesson

Validate after each structural YAML edit instead of combining multiple untested changes.

---

## 33. Kubernetes reported `missing Resource metadata`

### Symptom

```text
missing Resource metadata
```

### Root cause

The beginning of `deployment.yaml` had been removed or malformed while replacing a lower section. Kubernetes resources require top-level `apiVersion`, `kind`, `metadata`, and `spec` fields.

### Resolution

Ensure the manifest starts with:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cloudcart
  namespace: cloudcart
spec:
  # deployment configuration
```

Check for pasted Markdown fences:

```bash
grep -n '```' kubernetes/base/deployment.yaml
```

### Verification

```bash
kubectl create --dry-run=client \
  --validate=true \
  -f kubernetes/base/deployment.yaml
```

---

## 34. Pods were healthy but the Service had no usable backend port

### Symptom

The pods were `1/1 Running`, but requests failed:

```text
curl: (56) Recv failure: Connection reset by peer
```

The EndpointSlice contained pod addresses but displayed an unset port:

```text
PORTS     <unset>
ENDPOINTS 10.x.x.x,10.x.x.x
```

### Diagnosis

```bash
kubectl get pods -n cloudcart --show-labels

kubectl get service cloudcart -n cloudcart \
  -o jsonpath='{.spec.selector}{"\n"}'

kubectl get endpointslice -n cloudcart \
  -l kubernetes.io/service-name=cloudcart \
  -o wide
```

### Root cause

The Service’s named `targetPort` did not resolve to a matching named container port.

### Resolution

Use the numeric container port:

```yaml
ports:
  - name: http
    protocol: TCP
    port: 80
    targetPort: 80
    nodePort: 30080
```

Reapply:

```bash
kubectl apply -k kubernetes/base
```

### Verification

```bash
kubectl get endpointslice -n cloudcart \
  -l kubernetes.io/service-name=cloudcart \
  -o wide

curl -i http://localhost:8082/health
```

Expected response:

```text
HTTP/1.1 200 OK

healthy
```

### Lesson

When pods are healthy but a Service fails, inspect selectors and EndpointSlices before debugging external port mappings.

---

## 35. Legacy `Endpoints` output was confusing

### Symptom

```text
Warning: v1 Endpoints is deprecated in v1.33+
endpoints/cloudcart <none>
```

### Root cause

Modern Kubernetes uses EndpointSlice as the scalable service-discovery API. The legacy Endpoints view was not the best source of truth for this cluster version.

### Resolution

Use:

```bash
kubectl get endpointslice -n cloudcart \
  -l kubernetes.io/service-name=cloudcart \
  -o wide
```

### Lesson

Use the current Kubernetes API recommended by the warning rather than relying on deprecated output.

---

# Phase 8 — Helm 4 Packaging and Migration

## 36. Helm template attempted to change an immutable Deployment selector

### Symptom

```text
The Deployment "cloudcart" is invalid: spec.selector: Invalid value: ... field is immutable
```

### Root cause

The original Kustomize Deployment selected pods using only `app.kubernetes.io/name`. The first Helm template also added `app.kubernetes.io/instance` to `spec.selector.matchLabels`. Kubernetes does not permit changing a Deployment selector after creation.

### Resolution

Keep the stable application name as the selector and use the Helm release instance only as a normal metadata and pod label:

```gotemplate
{{- define "cloudcart.selectorLabels" -}}
app.kubernetes.io/name: {{ include "cloudcart.name" . }}
{{- end }}
```

### Verification

```bash
helm template cloudcart helm/cloudcart --namespace cloudcart \
  --values helm/cloudcart/values-lab.yaml > /tmp/cloudcart-rendered.yaml

kubectl apply --dry-run=server -f /tmp/cloudcart-rendered.yaml
```

### Lesson

Plan label and selector conventions before creating workloads. Metadata labels can change, but Deployment selectors are immutable.

---

## 37. Rendered Deployment placed selector labels inside strategy

### Symptom

```text
strict decoding error: unknown field "spec.strategy.matchLabels"
```

### Root cause

Template indentation placed `selector.matchLabels` inside the `strategy` mapping.

### Resolution

Align `strategy`, `selector`, and `template` as separate children of Deployment `spec`. Render the chart and inspect its generated YAML before installation.

### Lesson

A chart can pass basic linting while still rendering an invalid Kubernetes object. Use `helm template` and server-side validation together.

---

## 38. Helm 4 installation encountered a server-side field conflict

### Symptom

```text
conflict with "kubectl-client-side-apply": .spec.revisionHistoryLimit
```

### Root cause

The existing resources were created with kubectl client-side apply. Helm 4 uses server-side apply and correctly detected that another field manager owned part of the Deployment.

### Resolution

After validating the complete rendered chart and confirming that Helm should become the only manager, install with intentional conflict takeover:

```bash
helm install cloudcart helm/cloudcart \
  --namespace cloudcart \
  --values helm/cloudcart/values-lab.yaml \
  --force-conflicts \
  --wait \
  --timeout 3m
```

### Lesson

Ownership metadata and Kubernetes field ownership are different concepts. Labels and annotations satisfy Helm release ownership checks; `--force-conflicts` transfers server-side field ownership.

---

## 39. Deprecated Helm 4 atomic flag triggered automatic rollback

### Symptom

```text
Flag --atomic has been deprecated, use --rollback-on-failure instead
```

The failed installation then removed the adopted Deployment, Service and PDB during rollback.

### Root cause

The pre-existing resources had already been labelled and annotated as belonging to the Helm release. When installation failed and automatic rollback ran, Helm treated those resources as part of the failed release and removed them.

### Recovery

Restore the working resources from the committed Phase 7 manifests:

```bash
kubectl apply -k kubernetes/base
kubectl rollout status deployment/cloudcart -n cloudcart --timeout=180s
```

Then restore Helm ownership metadata and retry the validated install with `--force-conflicts`, without automatic rollback during this one-time migration.

### Lesson

Automatic rollback is useful for normal Helm-managed releases, but adopting pre-existing resources requires additional care. Back up resources and avoid automatic deletion behavior until ownership migration succeeds.

---

## 40. Helm release upgrade and rollback behavior

### Demonstration

Revision 1 installed two replicas. Revision 2 used a safe override to scale to three replicas:

```bash
helm upgrade cloudcart helm/cloudcart \
  --namespace cloudcart \
  --values helm/cloudcart/values-lab.yaml \
  --set replicaCount=3 \
  --force-conflicts \
  --wait \
  --timeout 3m
```

The release was then restored to revision 1 configuration:

```bash
helm rollback cloudcart 1 \
  --namespace cloudcart \
  --force-conflicts \
  --wait \
  --timeout 3m
```

### Verification

```bash
helm history cloudcart -n cloudcart
kubectl get deployment,pods -n cloudcart -o wide
curl -i http://localhost:8082/health
```

### Lesson

A rollback does not delete history. It creates a new deployed revision using the selected earlier revision’s configuration.

---

# Phase 9 — Argo CD GitOps

## 41. Kubernetes warned about the Argo CD finalizer name

### Symptom

```text
prefer a domain-qualified finalizer name including a path
```

### Root cause

The Application used Argo CD's legacy foreground-unspecified finalizer.

### Resolution

```yaml
finalizers:
  - resources-finalizer.argocd.argoproj.io/foreground
```

### Lesson

Treat dry-run warnings as useful compatibility signals.

---

## 42. Argo CD did not show a Git change immediately

### Root cause

Without a GitHub webhook, Argo CD polls the repository periodically.

### Resolution

```bash
kubectl get application cloudcart-gitops -n argocd --watch
```

Wait for `Synced` and `Healthy`.

### Lesson

Continuous reconciliation is asynchronous; a short polling delay is not a failed deployment.

---

## 43. CloudCart localhost URL failed while Argo CD was healthy

### Symptom

```text
curl: (7) Failed to connect to localhost port 8084
```

### Root cause

The temporary `kubectl port-forward` process had ended. The in-cluster application was healthy.

### Resolution

```bash
kubectl port-forward service/cloudcart \
  --namespace cloudcart-gitops 8084:80
```

### Lesson

Separate application health from temporary local access tooling.

---

# Phase 10 — Prometheus, Grafana and Alerting

## 44. Helm 4 lint rejected the repository chart version flag

### Symptom

```text
Error: unknown flag: --version
```

### Root cause

Helm 4 `lint` does not accept `--version` for a repository chart.

### Resolution

Use `helm template` with the pinned version, then install the same version:

```bash
helm template monitoring prometheus-community/kube-prometheus-stack \
  --version 87.17.0 --namespace monitoring \
  --values monitoring/kube-prometheus-stack/values-lab.yaml \
  > /tmp/monitoring-rendered.yaml
```

### Lesson

Pin versions during rendering and installation instead of silently using latest.

---

## 45. Kubernetes internal DNS URL was entered as a shell command

### Symptom

```text
zsh: no such file or directory:
http://cloudcart.cloudcart-gitops.svc.cluster.local/health
```

### Root cause

A `.svc.cluster.local` URL is for clients inside Kubernetes, not an executable Mac command.

### Resolution

Let Blackbox Exporter probe the internal URL. For Mac testing, use `http://localhost:8084/health` with port-forwarding.

### Lesson

Host URLs, Kubernetes Service DNS and public cloud URLs are separate network paths.

---

## 46. Alert recovery succeeded but localhost verification failed

### Root cause

The Probe target was restored and Argo CD was healthy, but the unrelated local port-forward was no longer running.

### Resolution

Verify each layer independently:

```bash
kubectl get probe cloudcart-health -n monitoring
kubectl get application cloudcart-gitops -n argocd
kubectl port-forward service/cloudcart -n cloudcart-gitops 8084:80
curl -i http://localhost:8084/health
```

Prometheus returned `probe_success = 1` and the alert resolved.

### Lesson

Validate desired configuration, in-cluster health, monitoring state and local access separately.

---

# Standard Diagnostic Commands

## Docker

```bash
docker info
docker ps -a
docker compose ps
docker compose logs --tail=100
docker inspect <CONTAINER_NAME>
```

## Terraform

```bash
terraform -chdir=infrastructure/environments/lab fmt -check -recursive
terraform -chdir=infrastructure/environments/lab validate
terraform -chdir=infrastructure/environments/lab plan
terraform -chdir=infrastructure/environments/lab state list
terraform -chdir=infrastructure/environments/lab output
```

## AWS

```bash
aws sts get-caller-identity
aws configure get region
aws ec2 describe-instance-status --include-all-instances
```

Do not paste full credential output or sensitive identifiers into public issues or screenshots.

## Ansible

```bash
ansible-inventory --graph
ansible cloudcart_lab -m ping
ansible-playbook --syntax-check ansible/playbooks/deploy-cloudcart.yml
ansible-playbook ansible/playbooks/deploy-cloudcart.yml --check
```

## Kubernetes

```bash
kubectl config current-context
kubectl get nodes -o wide
kubectl get all -n cloudcart
kubectl get pods -n cloudcart -o wide
kubectl describe deployment cloudcart -n cloudcart
kubectl logs deployment/cloudcart -n cloudcart --all-pods=true
kubectl get endpointslice -n cloudcart -o wide
kubectl get events -n cloudcart --sort-by='.lastTimestamp'
```

---

# Safe Troubleshooting Rules

1. Confirm the current directory before running relative-path commands.
2. Confirm the AWS identity and region before provisioning resources.
3. Confirm the Kubernetes context before applying or deleting resources.
4. Read the plan before every Terraform apply.
5. Do not use `terraform apply` on an old saved plan after changing configuration.
6. Inspect logs before repeatedly restarting a failed service.
7. Test connectivity in layers: network, authentication, application, health endpoint.
8. Use dry-run, syntax-check, lint, and validation commands before applying changes.
9. Never fix access problems by opening SSH to the entire internet.
10. Never commit a workaround containing credentials, PEM files, Terraform state, or private values.
11. Preserve evidence of both the failure and successful remediation when it is safe to do so.
12. Stop chargeable AWS resources when the lab session is complete.

---

# Pre-Commit Safety Check

```bash
git status --short
git diff --cached

find . -type f \( \
  -name "*.pem" -o \
  -name "*.tfstate" -o \
  -name "*.tfstate.*" -o \
  -name "*.tfplan" \
\)
```

Confirm sensitive files are ignored:

```bash
git check-ignore \
  infrastructure/environments/lab/terraform.tfvars \
  infrastructure/environments/lab/terraform.tfstate \
  ansible/inventory/hosts.ini
```

---

# Incident Documentation Template

Use this template for future phases:

```markdown
## Issue: Short descriptive title

### Phase and component

Phase X — Tool or service

### Symptom

Exact error with sensitive values removed.

### Impact

What failed or became unavailable?

### Root cause

Why did it happen?

### Diagnosis

Safe commands used to isolate the problem.

### Resolution

The smallest change that corrected the problem.

### Verification

Commands and expected result proving the fix worked.

### Prevention

Validation, automation, monitoring, policy, or documentation that prevents recurrence.

### Lesson

The engineering principle learned from the incident.
```

---

## Current Coverage

This guide covers completed work through **Phase 10 — Prometheus, Grafana and Availability Alerting**.

Future issues from security automation, reliability testing, EKS, and full application integration will be added only after those phases are implemented and verified.
