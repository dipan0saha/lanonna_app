"""Set a validated sender before worker modules read Settings (#43)."""

import os

os.environ.setdefault("MAILJET_FROM_EMAIL", "sender@example.com")
