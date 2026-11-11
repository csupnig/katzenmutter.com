#!/usr/bin/env bash
# Email forwarding for *@katzenmutter.com via Amazon SES (eu-west-1):
#   MX → SES inbound → S3 (30-day retention) → Lambda → SES send → FORWARD_TO
# Usage: AWS_PROFILE=supnig FORWARD_TO=you@example.com infra/setup-mail.sh
set -euo pipefail
cd "$(dirname "$0")"
: "${FORWARD_TO:?set FORWARD_TO}"

REGION=eu-west-1
ACCOUNT=725308806326
DOMAIN=katzenmutter.com
ZONE=Z9WAQTYUVGKI9
BUCKET=katzenmutter-mail-inbound
FN=katzenmutter-mail-forward
ROLE=katzenmutter-mail-forward
RULESET=katzenmutter
A="--region $REGION"
T=$(mktemp -d)

# 1. Domain identity with Easy DKIM (for sending the forwarded mail)
aws sesv2 get-email-identity --email-identity $DOMAIN $A >/dev/null 2>&1 || aws sesv2 create-email-identity --email-identity $DOMAIN $A >/dev/null
TOKENS=$(aws sesv2 get-email-identity --email-identity $DOMAIN $A --query 'DkimAttributes.Tokens' --output text)

# 2. DNS: MX (replaces null MX), DKIM, SPF, DMARC
{
  echo '{"Changes":['
  echo "{\"Action\":\"UPSERT\",\"ResourceRecordSet\":{\"Name\":\"$DOMAIN\",\"Type\":\"MX\",\"TTL\":300,\"ResourceRecords\":[{\"Value\":\"10 inbound-smtp.$REGION.amazonaws.com\"}]}},"
  echo "{\"Action\":\"UPSERT\",\"ResourceRecordSet\":{\"Name\":\"$DOMAIN\",\"Type\":\"TXT\",\"TTL\":300,\"ResourceRecords\":[{\"Value\":\"\\\"v=spf1 include:amazonses.com ~all\\\"\"}]}},"
  echo "{\"Action\":\"UPSERT\",\"ResourceRecordSet\":{\"Name\":\"_dmarc.$DOMAIN\",\"Type\":\"TXT\",\"TTL\":300,\"ResourceRecords\":[{\"Value\":\"\\\"v=DMARC1; p=none\\\"\"}]}}"
  for t in $TOKENS; do
    echo ",{\"Action\":\"UPSERT\",\"ResourceRecordSet\":{\"Name\":\"$t._domainkey.$DOMAIN\",\"Type\":\"CNAME\",\"TTL\":300,\"ResourceRecords\":[{\"Value\":\"$t.dkim.amazonses.com\"}]}}"
  done
  echo ']}'
} > $T/dns.json
aws route53 change-resource-record-sets --hosted-zone-id $ZONE --change-batch file://$T/dns.json --query ChangeInfo.Status --output text

# 3. S3 bucket for raw mail
aws s3api head-bucket --bucket $BUCKET $A 2>/dev/null || aws s3api create-bucket --bucket $BUCKET $A --create-bucket-configuration LocationConstraint=$REGION >/dev/null
aws s3api put-public-access-block --bucket $BUCKET --public-access-block-configuration BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
aws s3api put-bucket-policy --bucket $BUCKET --policy "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Effect\":\"Allow\",\"Principal\":{\"Service\":\"ses.amazonaws.com\"},\"Action\":\"s3:PutObject\",\"Resource\":\"arn:aws:s3:::$BUCKET/*\",\"Condition\":{\"StringEquals\":{\"AWS:SourceAccount\":\"$ACCOUNT\"}}}]}"
aws s3api put-bucket-lifecycle-configuration --bucket $BUCKET --lifecycle-configuration '{"Rules":[{"ID":"expire","Status":"Enabled","Filter":{"Prefix":""},"Expiration":{"Days":30}}]}'

# 4. Lambda role + function
if ! aws iam get-role --role-name $ROLE >/dev/null 2>&1; then
  aws iam create-role --role-name $ROLE --assume-role-policy-document '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":"lambda.amazonaws.com"},"Action":"sts:AssumeRole"}]}' >/dev/null
  aws iam attach-role-policy --role-name $ROLE --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole
  sleep 10
fi
aws iam put-role-policy --role-name $ROLE --policy-name forward --policy-document "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Effect\":\"Allow\",\"Action\":\"s3:GetObject\",\"Resource\":\"arn:aws:s3:::$BUCKET/*\"},{\"Effect\":\"Allow\",\"Action\":[\"ses:SendEmail\",\"ses:SendRawEmail\"],\"Resource\":\"*\"}]}"
cp mail-forward.py $T/index.py && (cd $T && zip -q fn.zip index.py)
ENV="Variables={BUCKET=$BUCKET,PREFIX=inbound/,FORWARD_TO=$FORWARD_TO,FROM=weiterleitung@$DOMAIN}"
if aws lambda get-function --function-name $FN $A >/dev/null 2>&1; then
  aws lambda update-function-code --function-name $FN --zip-file fileb://$T/fn.zip $A >/dev/null
  aws lambda wait function-updated --function-name $FN $A
  aws lambda update-function-configuration --function-name $FN --environment "$ENV" $A >/dev/null
else
  aws lambda create-function --function-name $FN --runtime python3.13 --handler index.handler --timeout 30 \
    --role arn:aws:iam::$ACCOUNT:role/$ROLE --zip-file fileb://$T/fn.zip --environment "$ENV" $A >/dev/null
  aws lambda wait function-active --function-name $FN $A
fi
aws lambda add-permission --function-name $FN --statement-id ses-invoke --action lambda:InvokeFunction \
  --principal ses.amazonaws.com --source-account $ACCOUNT $A >/dev/null 2>&1 || true

# 5. Receipt rule: all recipients @domain → S3 → Lambda
aws ses describe-receipt-rule-set --rule-set-name $RULESET $A >/dev/null 2>&1 || aws ses create-receipt-rule-set --rule-set-name $RULESET $A
RULE="{\"Name\":\"forward\",\"Enabled\":true,\"ScanEnabled\":true,\"TlsPolicy\":\"Optional\",\"Recipients\":[\"$DOMAIN\"],
 \"Actions\":[{\"S3Action\":{\"BucketName\":\"$BUCKET\",\"ObjectKeyPrefix\":\"inbound/\"}},
              {\"LambdaAction\":{\"FunctionArn\":\"arn:aws:lambda:$REGION:$ACCOUNT:function:$FN\",\"InvocationType\":\"Event\"}}]}"
aws ses describe-receipt-rule --rule-set-name $RULESET --rule-name forward $A >/dev/null 2>&1 \
  && aws ses update-receipt-rule --rule-set-name $RULESET --rule "$RULE" $A \
  || aws ses create-receipt-rule --rule-set-name $RULESET --rule "$RULE" $A
aws ses set-active-receipt-rule-set --rule-set-name $RULESET $A
echo "mail forwarding active: *@$DOMAIN → $FORWARD_TO"
