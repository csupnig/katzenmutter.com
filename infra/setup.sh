#!/usr/bin/env bash
# One-time AWS setup for katzenmutter.com (idempotent where possible).
#   1. IAM role for GitHub Actions (OIDC) with least-privilege deploy rights
#   2. CloudFront Function for www→apex + legacy redirects
#   3. Distribution: add www alias, attach function, 404 page, TLS 1.2+
#   4. Route 53: point www at CloudFront (replaces the S3 website redirect bucket)
#
# Usage: AWS_PROFILE=supnig infra/setup.sh [role|function|distribution|dns|all]
set -euo pipefail
cd "$(dirname "$0")"

ACCOUNT=725308806326
REPO=csupnig/katzenmutter.com
BUCKET=katzenmutter.com
DIST=E1TPQL9QC7XI6Z
ZONE=Z9WAQTYUVGKI9
ROLE=github-katzenmutter-deploy
FN=katzenmutter-redirects
CF_ZONE=Z2FDTNDATAQYW2   # fixed hosted zone ID for all CloudFront distributions

role() {
  cat > /tmp/km-trust.json <<EOF
{"Version":"2012-10-17","Statement":[{"Effect":"Allow",
 "Principal":{"Federated":"arn:aws:iam::$ACCOUNT:oidc-provider/token.actions.githubusercontent.com"},
 "Action":"sts:AssumeRoleWithWebIdentity",
 "Condition":{"StringEquals":{"token.actions.githubusercontent.com:aud":"sts.amazonaws.com"},
              "StringLike":{"token.actions.githubusercontent.com:sub":"repo:$REPO:environment:production"}}}]}
EOF
  cat > /tmp/km-policy.json <<EOF
{"Version":"2012-10-17","Statement":[
 {"Effect":"Allow","Action":["s3:ListBucket"],"Resource":"arn:aws:s3:::$BUCKET"},
 {"Effect":"Allow","Action":["s3:PutObject","s3:DeleteObject","s3:GetObject"],"Resource":"arn:aws:s3:::$BUCKET/*"},
 {"Effect":"Allow","Action":["cloudfront:CreateInvalidation"],"Resource":"arn:aws:cloudfront::$ACCOUNT:distribution/$DIST"}]}
EOF
  aws iam get-role --role-name $ROLE >/dev/null 2>&1 \
    && aws iam update-assume-role-policy --role-name $ROLE --policy-document file:///tmp/km-trust.json \
    || aws iam create-role --role-name $ROLE --assume-role-policy-document file:///tmp/km-trust.json --description "GitHub Actions deploy for $REPO" >/dev/null
  aws iam put-role-policy --role-name $ROLE --policy-name deploy --policy-document file:///tmp/km-policy.json
  echo "role: arn:aws:iam::$ACCOUNT:role/$ROLE"
}

function_() {
  if aws cloudfront describe-function --name $FN >/dev/null 2>&1; then
    ETAG=$(aws cloudfront describe-function --name $FN --query ETag --output text)
    aws cloudfront update-function --name $FN --if-match "$ETAG" --function-config Comment="www+legacy redirects",Runtime=cloudfront-js-2.0 --function-code fileb://redirects.js >/dev/null
  else
    aws cloudfront create-function --name $FN --function-config Comment="www+legacy redirects",Runtime=cloudfront-js-2.0 --function-code fileb://redirects.js >/dev/null
  fi
  ETAG=$(aws cloudfront describe-function --name $FN --query ETag --output text)
  aws cloudfront publish-function --name $FN --if-match "$ETAG" >/dev/null
  echo "function published: $FN"
}

distribution() {
  FN_ARN=$(aws cloudfront describe-function --name $FN --stage LIVE --query FunctionSummary.FunctionMetadata.FunctionARN --output text)
  aws cloudfront get-distribution-config --id $DIST > /tmp/km-dist.json
  ETAG=$(python3 -c 'import json;print(json.load(open("/tmp/km-dist.json"))["ETag"])')
  python3 - "$FN_ARN" <<'PY'
import json, sys
fn_arn = sys.argv[1]
d = json.load(open("/tmp/km-dist.json"))["DistributionConfig"]
d["Aliases"] = {"Quantity": 2, "Items": ["katzenmutter.com", "www.katzenmutter.com"]}
d["DefaultCacheBehavior"]["FunctionAssociations"] = {"Quantity": 1, "Items": [{"FunctionARN": fn_arn, "EventType": "viewer-request"}]}
d["CustomErrorResponses"] = {"Quantity": 2, "Items": [
  {"ErrorCode": 403, "ResponsePagePath": "/404.html", "ResponseCode": "404", "ErrorCachingMinTTL": 300},
  {"ErrorCode": 404, "ResponsePagePath": "/404.html", "ResponseCode": "404", "ErrorCachingMinTTL": 300}]}
d["ViewerCertificate"]["MinimumProtocolVersion"] = "TLSv1.2_2021"
d["HttpVersion"] = "http2and3"
d["IsIPV6Enabled"] = True
d["PriceClass"] = "PriceClass_100"   # EU + North America edges; audience is DACH
json.dump(d, open("/tmp/km-dist-new.json", "w"))
PY
  aws cloudfront update-distribution --id $DIST --if-match "$ETAG" --distribution-config file:///tmp/km-dist-new.json --query 'Distribution.Status' --output text
}

dns() {
  CF_DOMAIN=$(aws cloudfront get-distribution --id $DIST --query Distribution.DomainName --output text)
  cat > /tmp/km-dns.json <<EOF
{"Changes":[
 {"Action":"UPSERT","ResourceRecordSet":{"Name":"www.katzenmutter.com","Type":"A","AliasTarget":{"HostedZoneId":"$CF_ZONE","DNSName":"$CF_DOMAIN","EvaluateTargetHealth":false}}},
 {"Action":"UPSERT","ResourceRecordSet":{"Name":"www.katzenmutter.com","Type":"AAAA","AliasTarget":{"HostedZoneId":"$CF_ZONE","DNSName":"$CF_DOMAIN","EvaluateTargetHealth":false}}}]}
EOF
  aws route53 change-resource-record-sets --hosted-zone-id $ZONE --change-batch file:///tmp/km-dns.json --query ChangeInfo.Status --output text
}

case "${1:-all}" in
  role) role ;;
  function) function_ ;;
  distribution) distribution ;;
  dns) dns ;;
  all) role; function_; distribution; dns ;;
  *) echo "unknown step"; exit 1 ;;
esac
