# Serverless AWS Cloud Resume & CI/CD Pipeline

![AWS](https://img.shields.io/badge/AWS-Serverless-232F3E?style=flat&logo=amazon-aws&logoColor=white)
![Terraform](https://img.shields.io/badge/IaC-Terraform-7B42BC?style=flat&logo=terraform&logoColor=white)
![Python](https://img.shields.io/badge/Backend-Python%203.12-3776AB?style=flat&logo=python&logoColor=white)
![GitHub Actions](https://img.shields.io/badge/CI%2FCD-GitHub%20Actions-2088FF?style=flat&logo=githubactions&logoColor=white)
![pytest](https://img.shields.io/badge/Testing-pytest-0A9EDC?style=flat&logo=pytest&logoColor=white)

A production-ready, highly available, serverless portfolio website built on Amazon Web Services (AWS). This project demonstrates modern cloud architecture, Infrastructure as Code (IaC) best practices, automated backend unit testing, and continuous integration/deployment (CI/CD) pipelines.

**Live Demo:** [https://d1wg5h9ba8g8wm.cloudfront.net](https://d1wg5h9ba8g8wm.cloudfront.net)

---

## 🏛 Architecture Overview
```
                          [ Client Browser ]
                                  │
                                  ▼
                    [ Amazon CloudFront (CDN) ]
                       /                     \
                      /                       \
        (Static Web Assets)               (API Traffic)
                    /                           \
                   ▼                             ▼
       [ S3 Bucket (Private) ]         [ API Gateway (HTTP v2) ]
        * CloudFront OAC                  * CORS Configured
                                                 │
                                                 ▼
                                        [ AWS Lambda (Python) ]
                                         * Atomic Counter
                                                 │
                                                 ▼
                                       [ Amazon DynamoDB ]
                                         * On-Demand / Pay-per-request
```

### Key Architectural Highlights
* **Zero-Trust Static Hosting:** The S3 bucket is completely private. Access is granted exclusively to CloudFront via **Origin Access Control (OAC)** and IAM bucket policies.
* **Low-Latency Edge Delivery:** Globally distributed via CloudFront with automated cache invalidation upon continuous deployment.
* **Serverless Backend Microservice:** An API Gateway HTTP endpoint triggers an AWS Lambda function running Python 3.12, performing atomic counter updates on Amazon DynamoDB (`ADD count :incr`).
* **100% Infrastructure as Code:** All AWS resources are defined, version-controlled, and managed using Terraform.

---

## 🛠 Tech Stack

| Domain | Tech / Service | Purpose |
| :--- | :--- | :--- |
| **Frontend** | HTML5, CSS3, JavaScript (Fetch API) | Single-page responsive portfolio UI |
| **Hosting & CDN** | AWS S3, AWS CloudFront (OAC) | Secure global static hosting & TLS termination |
| **Backend API** | Amazon API Gateway (HTTP v2), AWS Lambda (Python 3.12) | Serverless RESTful visitor counter API |
| **Database** | Amazon DynamoDB | NoSQL database for real-time page-view tracking |
| **IaC** | Terraform | Provisioning and managing cloud infrastructure |
| **CI/CD** | GitHub Actions | Automated linting, testing, deployment, & cache invalidation |
| **Testing** | `pytest`, `unittest.mock`, `boto3` | Unit testing Lambda handler logic and AWS integrations |

---

## 🔄 CI/CD Pipeline Workflow

The repository uses **GitHub Actions** to enforce a quality-gated deployment workflow on every `git push` to `main`:

1. **Automated Testing (`test` job):** Spins up a headless Ubuntu container, injects mock AWS environment variables, and executes `pytest`.
2. **Gated Deployment (`deploy` job):** Only runs if all backend unit tests pass. It syncs updated static site assets to S3 and triggers a global CloudFront invalidation (`/*`) so changes reflect instantly.

---

## 💻 Local Development & Setup

### Prerequisites
* [AWS CLI](https://aws.amazon.com/cli/) configured with local credentials.
* [Terraform](https://www.terraform.io/) (v1.5+).
* [Python](https://www.python.org/) 3.10+ & `pip`.

### 1. Clone Repository & Setup Virtual Environment
```bash
git clone [https://github.com/](https://github.com/)Percy300/cloud-resume.git
cd cloud-resume

# Create and activate Python virtual environment
python -m venv .venv
source .venv/bin/activate  # On Windows: .venv\Scripts\Activate.ps1

# Install development dependencies
pip install pytest boto3

### 2. Run local Backend Unit Tests
Bash
pytest

### 3. Deploy Infrastructure via Terraform
Bash

cd terraform
terraform init
terraform plan
terraform apply

GitHub Repository secrets 
To enable the automated CI/CD pipeline, configure the following repository secrets under Settings > Secrets and variables > Actions:
AWS_ACCESS_KEY_ID =	IAM deployment user access key
AWS_SECRET_ACCESS_KEY = IAM deployment user secret key
S3_BUCKET_NAME	= Name of the target private S3 bucket
CLOUDFRONT_DISTRIBUTION_IDTarget = CloudFront distribution ID for cache purges


License
This project is open-source and available under the MIT License.
