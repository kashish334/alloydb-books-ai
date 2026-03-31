"""
AlloyDB AI - Book Library Natural Language Query System
Use case: Querying a book catalog using natural language powered by AlloyDB + Vertex AI
"""

import os
import logging
import sqlalchemy
from sqlalchemy import text
from flask import Flask, render_template, request, jsonify
import vertexai
from vertexai.generative_models import GenerativeModel

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = Flask(__name__)

PROJECT_ID    = os.environ.get("PROJECT_ID", "")
REGION        = os.environ.get("REGION", "us-central1")
CLUSTER_NAME  = os.environ.get("CLUSTER_NAME", "alloydb-books-cluster")
INSTANCE_NAME = os.environ.get("INSTANCE_NAME", "alloydb-books-instance")
DATABASE_NAME = os.environ.get("DATABASE_NAME", "bookdb")
DB_USER       = os.environ.get("DB_USER", "postgres")
DB_PASS       = os.environ.get("DB_PASS", "")
DB_HOST       = os.environ.get("DB_HOST", "")

vertexai.init(project=PROJECT_ID, location=REGION)
model = GenerativeModel("gemini-2.5-flash")
logger.info("Vertex AI initialized")

engine = None

def get_engine():
    global engine
    if engine:
        return engine
    if not DB_HOST:
        raise RuntimeError(
            "DB_HOST env var is not set. "
            "Set it to the private IP of your AlloyDB instance."
        )
    try:
        url = sqlalchemy.engine.URL.create(
            drivername="postgresql+pg8000",
            username=DB_USER,
            password=DB_PASS,
            host=DB_HOST,
            port=5432,
            database=DATABASE_NAME,
        )
        engine = sqlalchemy.create_engine(
            url,
            pool_size=5,
            max_overflow=2,
            pool_timeout=30,
            pool_pre_ping=True,
        )
        # Verify connection immediately so we fail fast on startup
        with engine.connect() as conn:
            conn.execute(text("SELECT 1"))
        logger.info(f"AlloyDB connected via direct IP: {DB_HOST}")
        return engine
    except Exception as e:
        engine = None
        logger.error(f"DB connection failed: {e}")
        raise RuntimeError(f"Database connection failed: {e}") from e


SCHEMA_DESCRIPTION = """
Table: books
Columns:
  - id: INTEGER (primary key)
  - title: VARCHAR(500)
  - author: VARCHAR(300)
  - genre: VARCHAR(100) — e.g. Fiction, Science Fiction, Mystery, Romance, Biography, History, Self-Help, Fantasy, Thriller, Horror
  - publication_year: INTEGER (1900–2024)
  - pages: INTEGER
  - rating: NUMERIC(3,2) — 1.00 to 5.00
  - language: VARCHAR(50) — e.g. English, Spanish, French
  - description: TEXT
  - is_bestseller: BOOLEAN
  - price_usd: NUMERIC(6,2)
"""

def nl_to_sql(natural_language_query: str) -> str:
    prompt = f"""You are a PostgreSQL expert. Convert the user query to a valid SQL SELECT statement.

Schema:{SCHEMA_DESCRIPTION}
Rules:
- Return ONLY the SQL query — no explanation, no markdown, no backticks
- Use lowercase column names
- Use ILIKE for text searches
- Default LIMIT 20 unless user specifies
- Default ORDER BY rating DESC

User query: {natural_language_query}

SQL:"""
    response = model.generate_content(
        prompt,
        generation_config={"max_output_tokens": 256},
    )
    sql = response.text.strip().replace("```sql", "").replace("```", "").strip()
    return sql


#Routes 
@app.route("/")
def index():
    return render_template("index.html")


@app.route("/query", methods=["POST"])
def query():
    data = request.get_json()
    nl_query = data.get("query", "").strip()
    if not nl_query:
        return jsonify({"error": "Query cannot be empty"}), 400

    sql_query = ""
    try:
        sql_query = nl_to_sql(nl_query)
        logger.info(f"Generated SQL: {sql_query}")

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
        return jsonify({"error": str(e), "generated_sql": sql_query}), 500


@app.route("/health")
def health():
    return jsonify({"status": "ok", "service": "alloydb-books-ai"})


@app.route("/warmup")
def warmup():
    try:
        get_engine()
        return jsonify({"status": "warm", "db": "connected"})
    except Exception as e:
        return jsonify({"status": "warm", "db": str(e)}), 200


@app.route("/sample-queries")
def sample_queries():
    return jsonify({"samples": [
        "Show me all Science Fiction books with rating above 4.5",
        "Find mystery books published after 2010 that are bestsellers",
        "What are the top 5 highest rated books under 300 pages?",
        "List all books by authors with 'King' in their name",
        "Show fantasy books priced under $15 with more than 400 pages",
        "Find all English biographies published between 2000 and 2020",
        "What are the cheapest self-help books with rating above 4?",
        "Show me horror books that are not bestsellers but have high ratings",
    ]})


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=int(os.environ.get("PORT", 8080)), debug=False)