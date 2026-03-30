"""
AlloyDB AI - Book Library Natural Language Query System
Use case: Querying a book catalog using natural language powered by AlloyDB + Vertex AI
"""

import os
import json
import logging
import pg8000
import sqlalchemy
from sqlalchemy import text
from flask import Flask, render_template, request, jsonify
from google.cloud.alloydb.connector import Connector
import vertexai
from vertexai.generative_models import GenerativeModel

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = Flask(__name__)

# ── Config ──────────────────────────────────────────────────────────────────
PROJECT_ID      = os.environ.get("PROJECT_ID", "")
REGION          = os.environ.get("REGION", "us-central1")
CLUSTER_NAME    = os.environ.get("CLUSTER_NAME", "alloydb-books-cluster")
INSTANCE_NAME   = os.environ.get("INSTANCE_NAME", "alloydb-books-instance")
DATABASE_NAME   = os.environ.get("DATABASE_NAME", "bookdb")
DB_USER         = os.environ.get("DB_USER", "postgres")
DB_PASS         = os.environ.get("DB_PASS", "")

ALLOYDB_INSTANCE_URI = (
    f"projects/{PROJECT_ID}/locations/{REGION}"
    f"/clusters/{CLUSTER_NAME}/instances/{INSTANCE_NAME}"
)

# ── DB Connection ────────────────────────────────────────────────────────────
connector = None
engine = None

def get_engine():
    global connector, engine
    if engine:
        return engine
    connector = Connector()

    def getconn():
        conn = connector.connect(
            ALLOYDB_INSTANCE_URI,
            "pg8000",
            user=DB_USER,
            password=DB_PASS,
            db=DATABASE_NAME,
        )
        return conn

    engine = sqlalchemy.create_engine(
        "postgresql+pg8000://",
        creator=getconn,
        pool_size=5,
        max_overflow=2,
    )
    return engine


# ── Vertex AI NL → SQL ───────────────────────────────────────────────────────
def nl_to_sql(natural_language_query: str) -> str:
    """Convert natural language to SQL using Vertex AI Gemini."""
    vertexai.init(project=PROJECT_ID, location=REGION)
    model = GenerativeModel("gemini-1.5-flash")

    schema_description = """
Table: books
Columns:
  - id: INTEGER (primary key)
  - title: VARCHAR(500) — book title
  - author: VARCHAR(300) — author name
  - genre: VARCHAR(100) — genre (e.g., Fiction, Science Fiction, Mystery, Romance, Biography, History, Self-Help, Fantasy, Thriller, Horror)
  - publication_year: INTEGER — year published (1900-2024)
  - pages: INTEGER — number of pages
  - rating: NUMERIC(3,2) — average rating (1.00 to 5.00)
  - language: VARCHAR(50) — language (e.g., English, Spanish, French)
  - description: TEXT — short book description
  - is_bestseller: BOOLEAN — whether it was a bestseller
  - price_usd: NUMERIC(6,2) — price in USD
"""

    prompt = f"""You are a PostgreSQL expert. Convert the user's natural language query to a valid SQL SELECT statement.

Database Schema:
{schema_description}

Rules:
- Return ONLY the SQL query, no explanation, no markdown, no backticks
- Always use lowercase column names
- Use ILIKE for text searches (case-insensitive)
- Limit results to 20 rows unless user specifies otherwise
- Use ORDER BY rating DESC as default sort unless user specifies
- For genre searches use ILIKE '%genre%'

User query: {natural_language_query}

SQL:"""

    response = model.generate_content(prompt)
    sql = response.text.strip()
    # Clean up any accidental markdown
    sql = sql.replace("```sql", "").replace("```", "").strip()
    return sql


# ── Routes ───────────────────────────────────────────────────────────────────
@app.route("/")
def index():
    return render_template("index.html")


@app.route("/query", methods=["POST"])
def query():
    data = request.get_json()
    nl_query = data.get("query", "").strip()

    if not nl_query:
        return jsonify({"error": "Query cannot be empty"}), 400

    try:
        # Step 1: NL → SQL
        sql_query = nl_to_sql(nl_query)
        logger.info(f"Generated SQL: {sql_query}")

        # Step 2: Execute against AlloyDB
        db_engine = get_engine()
        with db_engine.connect() as conn:
            result = conn.execute(text(sql_query))
            columns = list(result.keys())
            rows = [dict(zip(columns, row)) for row in result.fetchall()]

        return jsonify({
            "success": True,
            "natural_language_query": nl_query,
            "generated_sql": sql_query,
            "columns": columns,
            "rows": rows,
            "count": len(rows),
        })

    except Exception as e:
        logger.error(f"Query error: {e}")
        return jsonify({"error": str(e), "generated_sql": sql_query if 'sql_query' in locals() else ""}), 500


@app.route("/health")
def health():
    return jsonify({"status": "ok", "service": "alloydb-books-ai"})


@app.route("/sample-queries")
def sample_queries():
    samples = [
        "Show me all Science Fiction books with rating above 4.5",
        "Find mystery books published after 2010 that are bestsellers",
        "What are the top 5 highest rated books under 300 pages?",
        "List all books by authors with 'King' in their name",
        "Show fantasy books priced under $15 with more than 400 pages",
        "Find all English biographies published between 2000 and 2020",
        "What are the cheapest self-help books with rating above 4?",
        "Show me horror books that are not bestsellers but have high ratings",
    ]
    return jsonify({"samples": samples})


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=int(os.environ.get("PORT", 8080)), debug=False)
