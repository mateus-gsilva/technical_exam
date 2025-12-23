# technical_exam

Este projeto foi criado como parte de uma entrevista técnica.

Antes de rodar o Terraform, ajuste o `terraform/terraform.tfvars` conforme sua necessidade (ex.: `aws_region`, CIDR/subnets da VPC, acesso ao endpoint do EKS e dimensionamento do node group).

Este repositório contém:
- Infraestrutura (VPC + EKS + addons) via Terraform
- Um app NGINX simples (Hello World) empacotado em imagem Docker
- Pipeline no GitHub Actions para build/push no GHCR e deploy no EKS via `kubectl set image`

## Escopo atendido
- Criar um Cluster EKS com Observabilidade (Prometheus e Grafana) via Terraform
- Criar uma aplicação simples (Hello World) para demonstrar a observabilidade
- Disponibilizar a aplicação externamente
- Publicar no GitHub
- Criar um CI/CD (opcional) para build/push e deploy

## Estrutura
- `terraform/`: VPC + EKS + Helm releases (kube-prometheus-stack e nginx)
- `terraform/helm/`: values dos charts (`nginx_bitnami.yaml`, `kube-prometheus-stack.yaml`)
- `app/`: `Dockerfile`, `.dockerignore` e `index.html`
- `.github/workflows/docker-build.yml`: build/push + deploy

## Pré-requisitos
- AWS CLI configurado localmente (para aplicar Terraform): `aws configure`
- Terraform instalado
- `kubectl` instalado
- Acesso/credenciais AWS com permissão para criar VPC/EKS/EC2/IAM/ELB

## Provisionar (Terraform)

Dentro de `terraform/`:

```bash
cd terraform
terraform init
terraform apply
```

Outputs úteis (após o apply):

```bash
terraform output kubectl_context_command
terraform output demo_app_service_url
```

> Para testes, o endereço do LoadBalancer do NGINX (DNS/IP) aparece no output `demo_app_service_url`.

## O que o Terraform cria (explicação)

### VPC
Definida em `terraform/main.tf` via `terraform-aws-modules/vpc/aws`.

Componentes principais provisionados:
- VPC com CIDR definido em `terraform/terraform.tfvars`
- Subnets públicas e privadas (multi-AZ)
- Internet Gateway (para saída/entrada via subnets públicas)
- NAT Gateway (para permitir saída à internet a partir das subnets privadas)
- Route tables e associações
- Database subnets/subnet group (habilitado no módulo, útil para extensões futuras)

Motivação:
- Os nodes do EKS ficam em subnets privadas; o NLB (Service tipo LoadBalancer) usa subnets públicas para exposição externa.

### EKS
Definido em `terraform/main.tf` via `terraform-aws-modules/eks/aws`.

O que é criado/configurado:
- Cluster EKS com versão Kubernetes configurável
- Endpoint público/privado conforme variáveis (para este teste o endpoint pode estar público; ver “Notas de segurança”)
- Managed Node Group (definido em `terraform/terraform.tfvars`)
- Addons EKS essenciais (ex.: `vpc-cni`, `coredns`, `kube-proxy`, `metrics-server`) configurados via `eks_addons`
- Regras de acesso ao cluster via `access_entries` (EKS Access Entries)

### Observabilidade (Prometheus + Grafana)
Implementada pelo módulo `aws-ia/eks-blueprints-addons/aws` em `terraform/main.tf`.

Este módulo instala o chart `kube-prometheus-stack` (Prometheus Operator), que inclui:
- Prometheus
- Grafana
- Exporters e componentes do stack

Configuração do chart:
- Values em `terraform/helm/kube-prometheus-stack.yaml` (ex.: neste projeto `alertmanager.enabled: false`)

### Aplicação demo (NGINX via Helm)
Definida em `terraform/main.tf` como `helm_release.demo_app` usando o chart Bitnami `nginx`.

O que este release entrega:
- Deployment/Service do NGINX no namespace `nginx`
- Service do tipo `LoadBalancer` (configurado em `terraform/helm/nginx_bitnami.yaml`), criando um NLB na AWS
- O endereço externo é exposto em `terraform/output demo_app_service_url`

Relação com a pipeline:
- Idealmente, este tipo de atualização de imagem seria feito via **GitOps** (ex.: Argo CD/Flux) atualizando declarativos no repositório.
- Por simplicidade (e para manter o CI/CD opcional e curto), esta implementação usa `kubectl set image` no Deployment `demo-app`.
- Ou seja: o Helm cria o “esqueleto” (Deployment/Service/LB) e o CI/CD atualiza a imagem usada pelo Deployment.

## Pipeline (build/push + deploy)

O workflow está em `.github/workflows/docker-build.yml`.

### Build + Push para GHCR
- Em `push` na branch `main`, a pipeline:
  - builda a imagem em `app/`
  - faz push para `ghcr.io/<owner>/<repo>`
  - tags publicadas:
    - `:<sha>`
    - `:<run_number>` (sequencial por execução do workflow)

### Deploy para o EKS
O job `deploy` roda em `push` na `main` e executa:
- `kubectl set image deployment/demo-app ...`
- `kubectl rollout status ...`

Ao final do deploy, a pipeline também consulta o Service `demo-app` e escreve no **Job Summary** do GitHub Actions a URL do LoadBalancer (quando já disponível).

Ele autentica no cluster usando token de ServiceAccount (via secrets do GitHub).

## Configurar acesso do GitHub ao cluster

O deploy usa 3 GitHub Secrets:
- `K8S_SERVER`: endpoint do Kubernetes API
- `K8S_CA`: `certificate-authority-data` (base64)
- `K8S_TOKEN`: token do ServiceAccount com RBAC mínimo

### Comandos para coletar os valores

**K8S_SERVER**
```bash
kubectl config view --raw --minify -o jsonpath='{.clusters[0].cluster.server}'; echo
```

**K8S_CA**
```bash
kubectl config view --raw --minify -o jsonpath='{.clusters[0].cluster.certificate-authority-data}'; echo
```

**K8S_TOKEN** (namespace `nginx`, secret `gha-deployer-token`)
```bash
kubectl -n nginx get secret gha-deployer-token -o jsonpath='{.data.token}' | base64 -d; echo
```

> Observação: o ServiceAccount + RBAC + Secret do token podem estar provisionados via Helm `extraDeploy` no values do nginx.

## Notas de segurança

### Endpoint público do cluster (somente para teste)
Para facilitar os critérios de teste/demonstração com **GitHub-hosted runners** (que executam fora da sua VPC e com IPs que mudam), este projeto pode estar com:
- endpoint público do EKS habilitado
- `eks_endpoint_public_access_cidrs = ["0.0.0.0/0"]` (sem restrição por CIDR)

Isso **não deve ser replicado em produção**.

Alternativas melhores (produção):
- **Self-hosted runner** dentro da VPC (ou com egress IP fixo) + restringir o CIDR do endpoint público para um `/32`, ou até **desabilitar endpoint público**.
- **Endpoint privado do EKS** + conectividade privada (VPN/Direct Connect) para rodar o CI/CD dentro da rede.
- Rodar o CI/CD **internamente** (por exemplo, **GitLab self-managed** dentro da VPC com runners internos), evitando depender da rede do GitHub-hosted runner.
- Evitar token estático de ServiceAccount: preferir **AWS OIDC + IAM (IRSA/Access Entries)** e gerar token via `aws eks get-token` quando possível.

> Importante: se um token de ServiceAccount vazar, considere fazer rotação (recriar o Secret/token) imediatamente.

### Registry público (somente para teste)
Para simplificar o pull da imagem pelos nodes do cluster (sem precisar configurar `imagePullSecret`), o package no **GHCR** pode estar **público**.

Isso **não deve ser replicado em produção**.

Alternativas melhores (produção):
- Manter o GHCR **privado** e configurar `imagePullSecret` no namespace/Deployment (ou via Helm values).
- Usar **Amazon ECR** e permitir pull via **IAM do node group** (ou IRSA em casos específicos), evitando segredos estáticos no cluster.
- Usar External Secrets/Secrets Manager para gerenciar credenciais de registry de forma centralizada.
