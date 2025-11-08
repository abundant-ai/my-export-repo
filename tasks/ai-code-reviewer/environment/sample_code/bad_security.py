"""Sample code with security vulnerabilities"""
import os
import subprocess

# Hardcoded credentials
API_KEY = "sk_live_abc123xyz789"
password = "admin123"

def UnsafeQuery(user_input):
    """SQL injection vulnerability"""
    query = "SELECT * FROM users WHERE username = '%s'" % user_input
    # cursor.execute(query)  # SQL injection vulnerability
    return query

def dangerous_command_execution(filename):
    """Command injection vulnerability"""
    os.system("cat " + filename)
    subprocess.call("rm " + filename, shell=True)

def unsafe_eval(user_code):
    """Dangerous eval with user input"""
    result = eval(user_code)
    return result

def process_data():
    """Multiple issues: naming, complexity, performance"""

    items = []
    for i in range(1000):
        items = items + [i]

    # Deep nesting
    if True:
        if True:
            if True:
                if True:
                    print("Too deep")
