import logging
import os
from flask import Flask, session, redirect, url_for, render_template, request
from authlib.integrations.flask_client import OAuth
import boto3, psycopg2, json

app = Flask(__name__)
app.secret_key = os.environ.get('FLASK_SECRET', 'dev_secret_key')
app.logger.setLevel(logging.INFO)

# ---- Configure OAuth/OpenID Connect ----
oauth = OAuth(app)
oauth.register(
    name='oidc',
    client_id=os.environ.get('OIDC_CLIENT_ID'),
    client_secret=os.environ.get('OIDC_CLIENT_SECRET'),
    server_metadata_url=os.environ.get('OIDC_METADATA_URL'),
    client_kwargs={'scope': 'openid profile email'}
)


# ---- Real secret retrieval from AWS SSM ----
def get_secret():
    try:
        ssm_client = boto3.client('ssm', region_name='eu-west-2')
        resp = ssm_client.get_parameter(
            Name='/gchq-demo/secret',
            WithDecryption=True
        )
        secret = resp['Parameter']['Value']
        app.logger.info('CONFIG_SECRET_RETRIEVED')
        return secret
    except Exception as e:
        app.logger.error(f"KMS secret retrieval failed: {e}")
        return None

CONFIG_SECRET = get_secret()

# ---- Routes ----
@app.route('/')
def index():
    user = session.get('user')
    if user:
        return render_template('index.html', user=user)
    return redirect(url_for('login'))

@app.route('/login')
def login():
    app.logger.info('LOGIN_ATTEMPT')
    return oauth.oidc.authorize_redirect(
        redirect_uri=url_for('auth', _external=True)
    )

@app.route('/auth')
def auth():
    try:
        token = oauth.oidc.authorize_access_token()
        userinfo = token.get('userinfo') or token.get('id_token')
        if not userinfo:
            app.logger.warning('LOGIN_FAILED')
            return "Login failed", 401
        session['user'] = userinfo
        app.logger.info(f"LOGIN_SUCCESS for {userinfo.get('email')}")
        return redirect('/')
    except Exception as e:
        app.logger.warning('LOGIN_FAILED')
        return f"Login failed: {e}", 401

@app.route('/logout')
def logout():
    session.clear()
    # Compose the Auth0 logout URL
    return_to = url_for('index', _external=True)
    logout_url = f"https://{os.environ.get('OIDC_DOMAIN')}/v2/logout?returnTo={return_to}&client_id={os.environ.get('OIDC_CLIENT_ID')}"
    return redirect(logout_url)


@app.route('/dashboard')
def dashboard():
    if 'user' not in session:
        return redirect(url_for('login'))

    try:
        ssm = boto3.client('ssm', region_name='eu-west-2')
        conn_str = ssm.get_parameter(
            Name="/gchq-demo/db-url", WithDecryption=True
        )["Parameter"]["Value"]
        conn = psycopg2.connect(conn_str)
        cur = conn.cursor()
        cur.execute("SELECT severity, message FROM alerts ORDER BY id;")
        alerts = [{"severity": severity, "message": message} for severity, message in cur.fetchall()]
        cur.close()
        conn.close()
    except Exception as e:
        app.logger.error(f"Error fetching alerts: {e}")
        alerts = []
    return render_template('dashboard.html', alerts=alerts, user=session['user'])

@app.route('/test-secret-api')
def test_secret_api():
    if CONFIG_SECRET is None:
        return {'error': 'Server secret not available'}, 500
    # Directly use CONFIG_SECRET without exposing it
    return {
        'status': 'ok',
        'message': 'Test Secret API successful',
        'secret_length': len(CONFIG_SECRET)
    }
@app.route('/health')
def health():
    return "OK", 200

@app.route('/test-login-failure')
def test_login_failure():
    app.logger.warning('LOGIN_FAILED')
    return "Simulated login failed event for demo purposes", 401


@app.route("/db-check")
def db_check():
    ssm = boto3.client("ssm", region_name="eu-west-2")
    conn_str = ssm.get_parameter(
        Name="/gchq-demo/db-url", WithDecryption=True
    )["Parameter"]["Value"]
    try:
        conn = psycopg2.connect(conn_str, connect_timeout=3)
        cur = conn.cursor()
        cur.execute("SELECT 1;")
        cur.fetchone()
        conn.close()
        return "DB connection OK", 200
    except Exception as e:
        app.logger.warning(f"DB_CHECK_FAILED: {e}")
        return "DB connection failed", 500

if __name__ == "__main__":
    app.run(host='0.0.0.0', port=5000, debug=True)
