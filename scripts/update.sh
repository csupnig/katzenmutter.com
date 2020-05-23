#!/usr/bin/env bash
pwd
aws s3 sync dist/. s3://katzenmutter.com --profile=supnig
echo "Invalidating cloudfrond distribution to get fresh cache"
aws cloudfront create-invalidation --distribution-id=E1TPQL9QC7XI6Z --paths /\* --profile=supnig
