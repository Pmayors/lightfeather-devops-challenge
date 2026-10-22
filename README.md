# LightFeather DevOps challenge

One VPC in `us-east-1` hosts dev, stage, and prod. Each environment has a public subnet, a private subnet, and two ECS Fargate services (frontend and backend). Both images live in ECR. One Application Load Balancer serves all three environments by URL path.

```
browser
  |
  |  http://<alb>/dev/          static frontend
  |  http://<alb>/dev/api/      backend JSON
  v
Application Load Balancer  (public subnets in three AZs)
  |
  +-- lightfeather-dev-frontend     public subnet, dev AZ
  +-- lightfeather-dev-backend
  +-- lightfeather-stage-*          same pattern, desired count 0 until you deploy
  +-- lightfeather-prod-*
```

Private subnets are created and associated with a private route table. They have no default route unless you turn a NAT gateway on.

## Run the apps locally

Install Node.js 24 (`nvm use` reads `.nvmrc`), then start the backend first.

```bash
cd backend
npm ci
npm start
```

`GET http://localhost:8080/` returns JSON with an `id`.

```bash
cd frontend
npm ci
npm start
```

Open `http://localhost:3000`. A successful call shows `SUCCESS` and that id. The frontend reads `VITE_API_URL` when it is set, and otherwise calls `http://localhost:8080/`. The backend allows `http://localhost:3000` unless `CORS_ORIGIN` is set.

## Infrastructure

Install Terraform and use AWS credentials for an account you control, in `us-east-1`. The default stack stays off NAT Gateway. ECS services are created at `desired_count = 0` so the first apply does not need an image to exist.

```bash
cd live
terraform init
terraform plan -no-color -out=plan.out
terraform show -json plan.out > ../plan.json
terraform apply plan.out
```

Commit `plan.json` at the repository root. Do not commit `plan.out`.

Useful outputs after apply:

| Output | What it is |
| --- | --- |
| `alb_dns_name` | Host name of the load balancer |
| `environment_urls` | `http://<alb>/dev/`, `/stage/`, `/prod/` |
| `ecr_repository_urls` | Where the pipeline pushes images |
| `service_names` | ECS services Jenkins updates |

Turn on private-subnet tasks only together with NAT:

```bash
terraform apply -var enable_nat_gateway=true -var place_tasks_in_private_subnets=true
```

`place_tasks_in_private_subnets` without `enable_nat_gateway` fails the `private_tasks_need_nat` check. Tasks in a private subnet cannot pull from ECR with neither a NAT gateway nor VPC endpoints.

### Remote state

`bootstrap/` creates a versioned, encrypted, private S3 bucket and a DynamoDB lock table. It is a separate stack because the bucket has to exist before `live/` can store its state there.

```bash
cd bootstrap
terraform init
terraform apply -var state_bucket_name=YOUR-GLOBALLY-UNIQUE-BUCKET
```

Then uncomment the backend block in `live/backend.tf`, set the bucket name, and run `terraform init -migrate-state` from `live/`.

## Jenkins

Point two Pipeline jobs at this repo (or a multibranch job that picks up both files).

1. `Jenkinsfile.Terraform.groovy` runs `terraform fmt`, init, validate, and plan from `live/`. The saved plan is applied only when the `APPLY` parameter is checked, and only after a manual confirmation. Leave `APPLY` unchecked to plan only.
2. `Jenkinsfile.Application.groovy` builds both images for `linux/amd64`, pushes them to ECR with an immutable tag, registers a new ECS task definition revision, and waits until the service is stable.

Run the Terraform job's apply before the first application deploy. The application job reads the load balancer DNS name, bakes it into the frontend, and rolls:

- `lightfeather-<env>-backend`
- `lightfeather-<env>-frontend`

`ENVIRONMENT` chooses the pair. `DESIRED_COUNT` defaults to `1`. Set it to `0` to scale that environment back down. `PROJECT` must match the Terraform `project` variable (`lightfeather`).

The frontend for dev is built with `VITE_BASE=/dev/` and `VITE_API_URL=http://<alb>/dev/api/`. Stage and prod use their own prefix. The backend container gets `CORS_ORIGIN=http://<alb>` from the task definition, so one value covers every environment on that load balancer.

Open `http://<alb>/dev/` after the dev deploy. The page should show `SUCCESS` and an id.

The worker image includes `kubectl`. This solution does not use it. The brief asks for an ECS cluster.

## Design decisions and production improvements

### Trade-offs to stay within the free tier

- **No NAT gateway.** A NAT gateway is billed for every hour it exists, and one per availability zone would multiply that. Private subnets are still created, which is what the brief asks for, but their route table has no `0.0.0.0/0` route. Tasks run in the public subnet and get a public IP so they can pull from ECR and write logs. Security groups only accept traffic from the load balancer, so the public IP is not an open app port.
- **One subnet per environment, one shared load balancer.** The brief asks for a single public subnet and a single private subnet per environment. An ALB still needs subnets in two availability zones, so the one ALB is attached to all three public subnets. Dev tasks run in the dev subnet only. Stage and prod are the same shape with `desired_count = 0`, so they do not run Fargate tasks until you deploy them.
- **Small Fargate tasks, and none until a deploy.** Task size is 0.25 vCPU and 512 MB. Terraform leaves the desired count at 0. The application pipeline is what sets it to 1, and a deploy is allowed to stop the old task first (`deployment_minimum_healthy_percent = 0`) so a rollout does not briefly run two tasks.
- **HTTP on the shared ALB, Container Insights off, log retention 7 days.** HTTPS needs a domain and an ACM certificate. Container Insights and long log retention add CloudWatch cost. ECR keeps the 10 newest tagged images and expires untagged images after 7 days.
- **One VPC for all three environments.** The brief allows one VPC. Environments are separated by subnet, security group, service name, and URL prefix, not by account or VPC.

### How I would scale this for production

- Add a second public and private subnet in another AZ for each environment, and run at least two tasks spread across those subnets. Raise `deployment_minimum_healthy_percent` to 100 so a deploy does not drop capacity.
- Move tasks into the private subnets, set `enable_nat_gateway` (one NAT per AZ, not one shared NAT), or replace NAT with VPC endpoints for ECR, S3, and CloudWatch Logs.
- Add ECS service autoscaling on CPU (and request count per target on the ALB), with a higher Fargate size for prod than for dev. The `task_cpu` and `task_memory` variables are the manual version of that knob today.
- Put each environment in its own AWS account, with its own state key and its own ALB hostname, instead of path prefixes on one balancer.
- Keep the Jenkins split: infrastructure plan/apply stays separate from image build and rollout, and apply stays gated. Production apply would also require the saved plan to match `main`.

### Security hardening I would add with more time or budget

- HTTPS on the ALB with ACM, a redirect from port 80, and a locked-down ingress CIDR instead of `0.0.0.0/0` if the users are known.
- AWS WAF on the ALB, VPC flow logs, and alarms on unhealthy targets and failed deploys.
- Private subnets plus VPC endpoints, so task security groups do not need broad 443 egress to the internet.
- Jenkins authenticating to AWS with OIDC, not long-lived keys on the agent. ECR image scanning is already on; the pipeline would fail the deploy when a scan finds a fixable vulnerability.
- A non-root nginx image, a read-only root filesystem, and secrets in Secrets Manager or SSM if the apps ever grow any. The backend image already runs as the `node` user.
- Deletion protection on the prod load balancer, and the remote state bucket that `bootstrap/` already locks down (versioning, encryption, public access blocked, `prevent_destroy`).

### What I would change or finish with more time

- Generate `plan.json` against the real account and commit it. I would also migrate `live/` onto the S3 backend before anyone else applies.
- Replace path prefixes with real hostnames per environment. Path prefixes are what made one ALB work without a domain; host-based rules are the design I would rather operate.
- Add a second subnet per environment so tasks are not pinned to one AZ.
- Gate the Jenkins deploy on the ECR scan result, and add a rollback alarm when the deployment circuit breaker fires.
- The worker has `kubectl`, but I would not move this to EKS for this workload. I would only revisit that if the platform was already standardized on Kubernetes.

## Build log

1. **Private subnets without paying for NAT.** I wanted the tasks in the private subnets. They then had no way to pull from ECR, and a NAT gateway (or interface endpoints) is an always-on charge. I kept the private subnets and their route table, left NAT off, and placed the tasks in the public subnets with public IPs. Ingress is only from the load balancer. `enable_nat_gateway` and `place_tasks_in_private_subnets` are the two switches, and a check blocks the combination that cannot pull images. Commit: `600528b`.

2. **One load balancer, three environments, one subnet each.** An ALB needs two availability zones, and the brief only allows one public subnet per environment. Three load balancers would also triple the hourly charge. I attached one ALB to all three public subnets and routed `/dev`, `/stage`, and `/prod`, with `/<env>/api` in front of those rules so the API path is not swallowed by the frontend path. I rejected host-header routing because this challenge has no domain. Commit: `7bf5f4e`.

3. **The frontend image could not keep the Vite dev server.** `npm start` is a dev server, and the browser only learns the API URL from `VITE_*` values baked in at `npm run build`. I switched the frontend image to a build stage plus nginx, and the Jenkins job passes `VITE_BASE` and `VITE_API_URL` from the load balancer. The backend reads `CORS_ORIGIN` from the environment on each process start, so that value stays in the task definition instead of in the image. Commit: `944f5e8`. The pipeline passes those build args in `53e70ea`.

4. **Terraform should not own the running image.** A first apply with `desired_count = 1` fails when the `initial` tag is not in ECR yet, and a later apply would roll the service back to whatever tag Terraform last wrote. Services are created at count 0, and `ignore_changes` covers `task_definition` and `desired_count`. The application pipeline pushes an immutable tag, registers a new revision, and sets the count. Commit: `7bf5f4e` for the ignore rule, `53e70ea` for the pipeline that takes over the rollout.

5. **Remote state could not live in the same stack that creates the bucket.** Init of `live/` would need the bucket before apply could create it. I put S3 and the DynamoDB lock in `bootstrap/`, left the `live/` backend commented until that exists, and used local state so `terraform plan` can still produce `plan.json`. Commit: `7dd393a`.
