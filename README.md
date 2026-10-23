# LightFeather DevOps challenge

Dev, stage, and prod share one VPC in `us-east-1`. Each environment has one public subnet, one private subnet, and two ECS Fargate services (frontend and backend). Images are stored in ECR. One Application Load Balancer serves all three environments by URL path.

```
http://<alb>/dev/       frontend
http://<alb>/dev/api/   backend
```

The load balancer is attached to all three public subnets. Tasks for an environment run in that environment's public subnet. Stage and prod stay at desired count 0 until a deploy. Private subnets exist and use a private route table. That table has no default route unless a NAT gateway is enabled.

## Run the apps locally

Install Node.js 24. `nvm use` reads `.nvmrc`. Start the backend first.

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

Open `http://localhost:3000`. A successful call shows `SUCCESS` and that id. With `VITE_API_URL` unset, the page calls `http://localhost:8080/`. With `CORS_ORIGIN` unset, the backend allows `http://localhost:3000`.

## Infrastructure

Install Terraform and configure AWS credentials for an account you control, in `us-east-1`. The default stack leaves NAT off. ECS services are created at `desired_count = 0`, so the first apply does not require an image in ECR.

```bash
cd live
terraform init
terraform plan -no-color -out=plan.out
terraform show -json plan.out > ../plan.json
terraform apply plan.out
```

`plan.json` at the repository root is that JSON plan (`f81238b`). Do not commit `plan.out`.

| Output | What it is |
| --- | --- |
| `alb_dns_name` | Host name of the load balancer |
| `environment_urls` | `http://<alb>/dev/`, `/stage/`, `/prod/` |
| `ecr_repository_urls` | Where the pipeline pushes images |
| `service_names` | ECS services the Jenkins deploy updates |

Private-subnet tasks require NAT at the same time:

```bash
terraform apply -var enable_nat_gateway=true -var place_tasks_in_private_subnets=true
```

Setting `place_tasks_in_private_subnets` while NAT is off fails the `private_tasks_need_nat` check. A task in a private subnet cannot pull from ECR without a NAT gateway or VPC endpoints.

### Remote state

`bootstrap/` creates a versioned, encrypted, private S3 bucket and a DynamoDB lock table. It is a separate stack because the bucket has to exist before `live/` can store state there. I left the backend in `live/backend.tf` commented so this plan could be produced from local state.

```bash
cd bootstrap
terraform init
terraform apply -var state_bucket_name=YOUR-GLOBALLY-UNIQUE-BUCKET
```

After that apply, uncomment the backend block in `live/backend.tf`, set the bucket name, and run `terraform init -migrate-state` from `live/`.

## Jenkins

Create two Pipeline jobs from this repository.

1. `Jenkinsfile.Terraform.groovy` runs `terraform fmt`, init, validate, and plan in `live/`. The saved plan is applied only when the `APPLY` parameter is checked, and only after a manual confirmation. Leave `APPLY` unchecked to plan only.
2. `Jenkinsfile.Application.groovy` builds both images for `linux/amd64`, pushes them to ECR with an immutable tag, registers a new ECS task definition revision, and waits until the service is stable.

Run the Terraform apply before the first application deploy. The application job reads the load balancer DNS name, bakes it into the frontend image, and updates:

- `lightfeather-<env>-backend`
- `lightfeather-<env>-frontend`

`ENVIRONMENT` selects the pair. `DESIRED_COUNT` defaults to `1`. Set it to `0` to scale that environment back down. `PROJECT` must match the Terraform `project` variable (`lightfeather`).

The dev frontend is built with `VITE_BASE=/dev/` and `VITE_API_URL=http://<alb>/dev/api/`. Stage and prod use their own prefix. The backend task receives `CORS_ORIGIN=http://<alb>` from the task definition, so one value covers every environment on that load balancer.

After the dev deploy, open `http://<alb>/dev/`. The page should show `SUCCESS` and an id.

The Jenkins worker image includes `kubectl`. This submission uses ECS, which is what the task requires.

## Design decisions and production improvements

### Trade-offs to stay within the free tier

I left the NAT gateway off. It is billed for every hour it exists, and one per availability zone would multiply that cost. The private subnets are still created. Their route table has no `0.0.0.0/0` route. Tasks run in the public subnet and receive a public IP so they can pull from ECR and write logs. The security group accepts traffic only from the load balancer, so the public IP is not an open application port.

The task asks for one public subnet and one private subnet per environment. An ALB still needs subnets in two availability zones, so I attached the single load balancer to all three public subnets. Each environment's tasks stay in that environment's subnet. Stage and prod remain at `desired_count = 0` until a deploy, so they do not run Fargate tasks yet.

Task size is 0.25 vCPU and 512 MB. Terraform leaves the desired count at 0, and the application pipeline raises it to 1. `deployment_minimum_healthy_percent = 0` allows the old task to stop before the new one starts, so a rollout does not briefly run two tasks.

The load balancer listens on HTTP. HTTPS needs a domain and an ACM certificate. Container Insights is off, and logs are retained for 7 days. ECR keeps the 10 newest tagged images and expires untagged images after 7 days.

The task allows one VPC. Environments are separated by subnet, security group, service name, and URL prefix.

### How I would scale this for production

I would add a second public subnet and a second private subnet in another availability zone for each environment, and run at least two tasks across those subnets. I would raise `deployment_minimum_healthy_percent` to 100 so a deploy does not drop capacity.

I would move the tasks into the private subnets and enable one NAT gateway per availability zone, or replace NAT with VPC endpoints for ECR, S3, and CloudWatch Logs.

I would add ECS service autoscaling on CPU and on ALB request count, with a larger Fargate size for prod than for dev. `task_cpu` and `task_memory` are the manual form of that setting today.

I would place each environment in its own AWS account, with its own state key and its own load balancer hostname.

I would keep the current Jenkins split: infrastructure plan and apply stay separate from image build and rollout, and apply stays behind a manual confirmation. A production apply would also require the saved plan to come from `main`.

### Security hardening I would add with more time or budget

I would terminate HTTPS on the load balancer with ACM and redirect port 80. Where the users are known, I would limit ingress to their CIDR.

I would add AWS WAF on the load balancer, VPC flow logs, and alarms for unhealthy targets and failed deploys.

I would run tasks in private subnets with VPC endpoints, so the task security groups can drop broad egress on 443.

Jenkins would authenticate to AWS with OIDC, so the agent does not hold a long-lived key. ECR scanning is already enabled. I would fail the deploy when a scan reports a vulnerability that can be patched.

I would run nginx as a non-root user, use a read-only root filesystem, and store any future secrets in Secrets Manager or SSM. The backend image already runs as the `node` user.

I would enable deletion protection on the prod load balancer. The bucket created by `bootstrap/` already has versioning, encryption, public access blocked, and `prevent_destroy`.

### What I would change or finish with more time

`plan.json` is already committed from the local plan (`f81238b`). With more time I would apply `bootstrap/`, uncomment the backend in `live/backend.tf`, and run `terraform init -migrate-state` before anyone else applies the stack.

I would replace the path prefixes with a hostname per environment once a domain is available. Path routing is what made one load balancer work for this challenge.

I would add a second subnet per environment so tasks are not pinned to a single availability zone.

I would fail the Jenkins deploy on a bad ECR scan result, and add an alarm when the deployment circuit breaker rolls a service back.

The worker image includes `kubectl`. I kept this workload on ECS. I would revisit EKS only if the platform was already standardized on Kubernetes.

## Build log

1. **Private subnets without paying for NAT.** I wanted the tasks in the private subnets. They then had no route for pulling from ECR, and a NAT gateway or interface endpoints would be an always-on charge. I kept the private subnets and their route table, left NAT off, and placed the tasks in the public subnets with public IPs. Ingress is limited to the load balancer. `enable_nat_gateway` and `place_tasks_in_private_subnets` are the two switches, and a check blocks the combination that cannot pull images. Commit: `600528b`.

2. **One load balancer, three environments, one subnet each.** An ALB needs two availability zones, and the task allows only one public subnet per environment. Three load balancers would also mean three hourly charges. I attached one ALB to all three public subnets and routed `/dev`, `/stage`, and `/prod`, with the `/<env>/api` rules ahead of those so the API path is not served by the frontend. I considered host-header routing and dropped it because this challenge has no domain. Commit: `7bf5f4e`.

3. **The frontend image was still the Vite dev server.** `npm start` does not bake `VITE_*` values, and the browser only learns the API URL from the production build. I changed the frontend image to a build stage plus nginx, and the Jenkins job passes `VITE_BASE` and `VITE_API_URL` from the load balancer DNS name. The backend reads `CORS_ORIGIN` at process start, so that value stays on the task definition. Commit: `944f5e8`. The pipeline build args are in `53e70ea`.

4. **Terraform should not roll back a Jenkins deploy.** A first apply with `desired_count = 1` fails when the `initial` tag is not in ECR yet, and a later apply would return the service to whatever tag Terraform last wrote. Services are created at count 0, and `ignore_changes` covers `task_definition` and `desired_count`. The application pipeline pushes an immutable tag, registers a new revision, and sets the count. Commit: `7bf5f4e` for the ignore rule, `53e70ea` for the pipeline.

5. **Remote state could not live in the same stack as the bucket.** `terraform init` in `live/` needs the bucket before apply can create it. I put the S3 bucket and the DynamoDB lock table in `bootstrap/`, left the `live/` backend commented until that bucket exists, and used local state so the plan could still be written to `plan.json`. Commit: `7dd393a`.
