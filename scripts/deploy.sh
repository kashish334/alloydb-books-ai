#!/bin/bash
# ================================================================
# BookMind: AlloyDB AI Natural Language Book Search
# Deployment script for Cloud Run + AlloyDB
# Use case: Querying a book catalog using natural language
# ================================================================
set -e

# ── Colors ───────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

log()  { echo -e "${GREEN}[✓]${NC} $1"; }
info() { echo -e "${CYAN}[→]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
err()  { echo -e "${RED}[✗]${NC} $1"; exit 1; }

echo ""
echo -e "${BOLD}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║   BookMind · AlloyDB AI · Natural Language DB    ║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════════════════╝${NC}"
echo ""

# ── Prompt for config ───────────────────────────────────────────
read -p "$(echo -e ${CYAN}Enter your GCP Project ID: ${NC})" PROJECT_ID
read -p "$(echo -e ${CYAN}Enter region [default: us-central1]: ${NC})" REGION
REGION="${REGION:-us-central1}"
read -p "$(echo -e ${CYAN}AlloyDB cluster name [default: bookmind-cluster]: ${NC})" CLUSTER_NAME
CLUSTER_NAME="${CLUSTER_NAME:-bookmind-cluster}"
read -p "$(echo -e ${CYAN}AlloyDB instance name [default: bookmind-instance]: ${NC})" INSTANCE_NAME
INSTANCE_NAME="${INSTANCE_NAME:-bookmind-instance}"
read -s -p "$(echo -e ${CYAN}AlloyDB postgres password: ${NC})" DB_PASS
echo ""

export PROJECT_ID REGION CLUSTER_NAME INSTANCE_NAME DB_PASS
INSTANCE_URI="projects/${PROJECT_ID}/locations/${REGION}/clusters/${CLUSTER_NAME}/instances/${INSTANCE_NAME}"
SERVICE_ACCOUNT="bookmind-sa@${PROJECT_ID}.iam.gserviceaccount.com"
IMAGE_URI="gcr.io/${PROJECT_ID}/bookmind-app"

# ── Step 1: Set project ─────────────────────────────────────────
info "Setting GCP project to ${PROJECT_ID}..."
gcloud config set project "$PROJECT_ID"
log "Project set"

# ── Step 2: Enable APIs ─────────────────────────────────────────
info "Enabling required APIs (this may take a minute)..."
gcloud services enable \
  alloydb.googleapis.com \
  compute.googleapis.com \
  cloudresourcemanager.googleapis.com \
  servicenetworking.googleapis.com \
  run.googleapis.com \
  cloudbuild.googleapis.com \
  aiplatform.googleapis.com \
  secretmanager.googleapis.com \
  iam.googleapis.com \
  --project="$PROJECT_ID" --quiet
log "APIs enabled"

# ── Step 3: Service Account ─────────────────────────────────────
info "Creating service account..."
gcloud iam service-accounts create bookmind-sa \
  --display-name="BookMind Service Account" \
  --project="$PROJECT_ID" 2>/dev/null || warn "Service account already exists"

for ROLE in \
  roles/alloydb.client \
  roles/alloydb.databaseUser \
  roles/aiplatform.user \
  roles/secretmanager.secretAccessor \
  roles/run.invoker; do
  gcloud projects add-iam-policy-binding "$PROJECT_ID" \
    --member="serviceAccount:${SERVICE_ACCOUNT}" \
    --role="$ROLE" --quiet
done
log "Service account configured"

# ── Step 4: VPC Peering for AlloyDB ────────────────────────────
info "Configuring private networking for AlloyDB..."
gcloud compute addresses create google-managed-services-default \
  --global \
  --purpose=VPC_PEERING \
  --prefix-length=16 \
  --network=default \
  --project="$PROJECT_ID" 2>/dev/null || warn "IP range already exists"

gcloud services vpc-peerings connect \
  --service=servicenetworking.googleapis.com \
  --ranges=google-managed-services-default \
  --network=default \
  --project="$PROJECT_ID" 2>/dev/null || warn "VPC peering already configured"
log "Networking ready"

# ── Step 5: AlloyDB Cluster ─────────────────────────────────────
info "Creating AlloyDB cluster: ${CLUSTER_NAME}..."
gcloud alloydb clusters create "$CLUSTER_NAME" \
  --region="$REGION" \
  --password="$DB_PASS" \
  --network=projects/"${PROJECT_ID}"/global/networks/default \
  --project="$PROJECT_ID" 2>/dev/null || warn "Cluster may already exist"
log "Cluster created"

# ── Step 6: AlloyDB Instance ────────────────────────────────────
info "Creating AlloyDB instance (takes 3-5 min)..."
gcloud alloydb instances create "$INSTANCE_NAME" \
  --cluster="$CLUSTER_NAME" \
  --region="$REGION" \
  --instance-type=PRIMARY \
  --cpu-count=2 \
  --project="$PROJECT_ID" 2>/dev/null || warn "Instance may already exist"
log "Instance created"

# ── Step 7: Store DB password in Secret Manager ─────────────────
info "Storing credentials in Secret Manager..."
echo -n "$DB_PASS" | gcloud secrets create alloydb-password \
  --data-file=- --project="$PROJECT_ID" 2>/dev/null || \
  echo -n "$DB_PASS" | gcloud secrets versions add alloydb-password \
  --data-file=- --project="$PROJECT_ID"
log "Secret stored"

# ── Step 8: Load schema and seed data ───────────────────────────
info "Loading books schema and seed data into AlloyDB..."
ALLOYDB_IP=$(gcloud alloydb instances describe "$INSTANCE_NAME" \
  --cluster="$CLUSTER_NAME" \
  --region="$REGION" \
  --format="value(ipAddress)" \
  --project="$PROJECT_ID")

# Use Cloud SQL Proxy / AlloyDB Auth Proxy
info "AlloyDB IP: ${ALLOYDB_IP}"
info "Run this manually to load data:"
echo ""
echo "  PGPASSWORD='${DB_PASS}' psql -h ${ALLOYDB_IP} -U postgres -c 'CREATE DATABASE bookdb;'"
echo "  PGPASSWORD='${DB_PASS}' psql -h ${ALLOYDB_IP} -U postgres -d bookdb -f sql/schema_and_seed.sql"
echo ""

# ── Step 9: Build & push Docker image ───────────────────────────
info "Building Docker image..."
cd app
gcloud builds submit \
  --tag="$IMAGE_URI" \
  --project="$PROJECT_ID"
cd ..
log "Image built and pushed: ${IMAGE_URI}"

# ── Step 10: Deploy to Cloud Run ────────────────────────────────
info "Deploying to Cloud Run..."
gcloud run deploy bookmind \
  --image="$IMAGE_URI" \
  --region="$REGION" \
  --platform=managed \
  --allow-unauthenticated \
  --service-account="$SERVICE_ACCOUNT" \
  --set-env-vars="PROJECT_ID=${PROJECT_ID},REGION=${REGION},CLUSTER_NAME=${CLUSTER_NAME},INSTANCE_NAME=${INSTANCE_NAME},DATABASE_NAME=bookdb,DB_USER=postgres" \
  --set-secrets="DB_PASS=alloydb-password:latest" \
  --memory=1Gi \
  --cpu=1 \
  --timeout=60 \
  --max-instances=10 \
  --project="$PROJECT_ID"

# ── Done ─────────────────────────────────────────────────────────
CLOUD_RUN_URL=$(gcloud run services describe bookmind \
  --region="$REGION" \
  --format="value(status.url)" \
  --project="$PROJECT_ID")

echo ""
echo -e "${BOLD}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║              🎉 Deployment Complete!             ║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  ${GREEN}Cloud Run URL:${NC} ${CLOUD_RUN_URL}"
echo ""
echo -e "  ${CYAN}Sample queries to try:${NC}"
echo "  • Show me sci-fi books with rating above 4.5"
echo "  • Find bestseller mystery books published after 2010"
echo "  • What are the top 5 highest rated books under 300 pages?"
echo "  • List all books in Spanish"
echo ""
