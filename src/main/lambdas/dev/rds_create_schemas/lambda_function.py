import os
import psycopg2

def lambda_handler(event, context):
    # Recupero delle credenziali dallo environment
    db_host = os.environ['DB_HOST']
    db_user = os.environ['DB_USER']
    db_password = os.environ['DB_PASSWORD']
    db_name = os.environ['DB_NAME']
    db_port = os.environ['DB_PORT']
    schemas = os.environ['DB_SCHEMAS'].split(',')

    # Stringa di connessione
    conn_string = f"host={db_host} port={db_port} user={db_user} password={db_password} dbname={db_name}"

    try:
        # Connessione al database
        conn = psycopg2.connect(conn_string)
        cursor = conn.cursor()

        # Creazione degli schemi
        for schema in schemas:
            cursor.execute("CREATE SCHEMA IF NOT EXISTS "+schema+";")

        # Esecuzione della transazione
        conn.commit()
        print("Schemi creati con successo.")

        if cursor:
            cursor.close()
        if conn:
            conn.close()
        return {"message": "Schemi creati con successo."}
    except Exception as e:
        print(f"Errore durante la connessione al database: {e}")
        
        if cursor:
            cursor.close()
        if conn:
            conn.close()
        return {"message": "Errore durante la connessione al database."}

