"""SES inbound → forward. Mail to *@katzenmutter.com is stored in S3 by SES,
this Lambda re-sends it to FORWARD_TO (env var, not in repo) via SES.
From is rewritten to the domain (DMARC), the original sender goes into Reply-To."""
import email, os, boto3
from email.utils import parseaddr

s3 = boto3.client("s3")
ses = boto3.client("sesv2")
BUCKET, PREFIX = os.environ["BUCKET"], os.environ.get("PREFIX", "inbound/")
FORWARD_TO, FROM = os.environ["FORWARD_TO"], os.environ.get("FROM", "weiterleitung@katzenmutter.com")

def handler(event, _ctx):
    rec = event["Records"][0]["ses"]
    raw = s3.get_object(Bucket=BUCKET, Key=PREFIX + rec["mail"]["messageId"])["Body"].read()
    msg = email.message_from_bytes(raw)
    name, addr = parseaddr(msg.get("From", ""))
    for h in ("DKIM-Signature", "Return-Path", "Sender", "Message-ID", "Reply-To"):
        del msg[h]
    del msg["From"]
    msg["From"] = f'"{(name or addr)[:60]} via katzenmutter" <{FROM}>'
    msg["Reply-To"] = addr
    msg["X-Original-To"] = ", ".join(rec["receipt"]["recipients"])
    ses.send_email(FromEmailAddress=FROM, Destination={"ToAddresses": [FORWARD_TO]},
                   Content={"Raw": {"Data": msg.as_bytes()}})
