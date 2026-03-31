# BookMind — AlloyDB AI Natural Language Book Search

> **Use case:** Querying a book catalog using natural language powered by AlloyDB + Vertex AI (Gemini)

A Cloud Run web application that lets users search a book library database using plain English. It converts natural language queries into SQL using Gemini, executes them against AlloyDB for PostgreSQL, and returns results in a beautiful book-card UI.

---

## Architecture

```
User (Browser)
     │  natural language query
     ▼
Cloud Run (Flask)
     │  prompt + schema
     ▼
Vertex AI (Gemini 2.5 Flash)
     │  generated SQL
     ▼
AlloyDB for PostgreSQL
     │  query results
     ▼
Cloud Run → JSON → Browser (rendered book cards)
```

---

## Project Submission Details

| Field | Value |
|-------|-------|
| **Use case** | Querying a book catalog using natural language |
| **Dataset** | Custom book library (100 books, genres, ratings, prices) — NOT the lab dataset |
| **Table** | `books` — custom schema with 11 columns including `embedding VECTOR(768)` |
| **NL Query example** | "Show me sci-fi books with rating above 4.5" |
| **SQL Generated** | `SELECT * FROM books WHERE genre ILIKE '%Science Fiction%' AND rating > 4.5 ORDER BY rating DESC LIMIT 20` |
| **Deployment** | Cloud Run (containerized Flask app) |

---

## Project Structure

```
alloydb-books-ai/
├── app/
│   ├── main.py              # Flask app: NL→SQL→AlloyDB pipeline
│   ├── templates/
│   │   └── index.html       # Beautiful book search UI
│   ├── requirements.txt
│   └── Dockerfile
├── sql/
│   └── schema_and_seed.sql  # Books table + 100 seed records
├── scripts/
│   └── deploy.sh            # One-command deployment
└── README.md
```

---

## Quick Deploy

### Prerequisites
- GCP project with billing enabled
- `gcloud` CLI authenticated
- AlloyDB, Cloud Run, Vertex AI APIs enabled

### One-command deployment

```bash
git clone <this-repo>
cd alloydb-books-ai
chmod +x scripts/deploy.sh
./scripts/deploy.sh
```

The script will prompt you for:
- GCP Project ID
- Region (default: `us-central1`)
- AlloyDB cluster name
- AlloyDB instance name
- Database password

### Manual steps

```bash
# 1. Enable APIs
gcloud services enable alloydb.googleapis.com run.googleapis.com \
  aiplatform.googleapis.com cloudbuild.googleapis.com

# 2. Create AlloyDB cluster
gcloud alloydb clusters create bookmind-cluster \
  --region=us-central1 --password=YOUR_PASSWORD \
  --network=projects/PROJECT_ID/global/networks/default

# 3. Create AlloyDB instance
gcloud alloydb instances create bookmind-instance \
  --cluster=bookmind-cluster --region=us-central1 \
  --instance-type=PRIMARY --cpu-count=2

# 4. Load schema + data
psql -h ALLOYDB_IP -U postgres -d bookdb -f sql/schema_and_seed.sql

# 5. Build & deploy
cd app
gcloud builds submit --tag gcr.io/PROJECT_ID/bookmind-app
gcloud run deploy bookmind --image gcr.io/PROJECT_ID/bookmind-app \
  --region=us-central1 --allow-unauthenticated \
  --set-env-vars="PROJECT_ID=...,CLUSTER_NAME=...,INSTANCE_NAME=..."
```

---

## How It Works

### 1. Natural Language → SQL (Vertex AI)
The app sends the user's query + table schema to Gemini 1.5 Flash:

```python
prompt = f"""Convert this query to PostgreSQL SQL:
Table: books (id, title, author, genre, publication_year, pages, 
              rating, language, description, is_bestseller, price_usd)

User query: {natural_language_query}
SQL:"""
```

### 2. SQL Execution (AlloyDB)
The generated SQL is executed against AlloyDB using the AlloyDB Python Connector:

```python
connector = Connector()
engine = sqlalchemy.create_engine("postgresql+pg8000://", creator=getconn)
result = conn.execute(text(generated_sql))
```

### 3. AlloyDB AI Extension
The `google_ml_integration` extension is enabled for future vector embedding support:

```sql
CREATE EXTENSION IF NOT EXISTS google_ml_integration CASCADE;
CREATE EXTENSION IF NOT EXISTS vector CASCADE;
-- Embedding column ready for semantic search:
embedding VECTOR(768)
```

---

## Dataset

Custom book library with **100 books** across 12 genres:

| Genre | Count | Example |
|-------|-------|---------|
| Science Fiction | 10 | Dune, The Martian, Project Hail Mary |
| Fantasy | 8 | The Way of Kings, Mistborn |
| Mystery / Thriller | 7 | Gone Girl, Rebecca |
| Horror | 5 | It, House of Leaves |
| Romance | 5 | Pride and Prejudice, Outlander |
| Biography | 6 | Becoming, Born a Crime |
| History | 5 | Sapiens, The Silk Roads |
| Self-Help | 7 | Atomic Habits, Deep Work |
| Fiction | 10 | 1984, The Kite Runner |
| Young Adult | 5 | Harry Potter, The Hunger Games |
| Non-Fiction | 5 | Quiet, Freakonomics |
| Children | 3 | Charlotte's Web, Matilda |

---

## Sample Natural Language Queries

```
"Show me all Science Fiction books with rating above 4.5"
"Find mystery books published after 2010 that are bestsellers"
"What are the top 5 highest rated books under 300 pages?"
"List all books by authors with 'King' in their name"
"Show fantasy books priced under $15 with more than 400 pages"
"Find all books in Spanish"
"What are the cheapest self-help books with rating above 4?"
"Show me horror books that are not bestsellers but have high ratings"
"Find books published between 2020 and 2023"
"Which biographies have more than 600 pages?"
```

---

## Cloud Run URL

After deployment, the URL will be printed:
```
https://bookmind-XXXXXXXX-uc.a.run.app
```

---

## Security

- AlloyDB uses private IP (VPC peering)
- Database password stored in Secret Manager
- Cloud Run uses a dedicated service account with minimal IAM roles
- No credentials in source code or Docker image

---

## Cleanup

```bash
# Delete Cloud Run service
gcloud run services delete bookmind --region=us-central1

# Delete AlloyDB cluster (also deletes instances)
gcloud alloydb clusters delete bookmind-cluster \
  --region=us-central1 --force

# Delete container image
gcloud container images delete gcr.io/PROJECT_ID/bookmind-app
```

---

## License

Apache 2.0 — see LICENSE
