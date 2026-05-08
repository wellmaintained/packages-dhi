#!/bin/sh
set -e
echo "Waiting for MinIO to be ready..."
until mc alias set myminio "$AWS_ENDPOINT_URL_S3" "${AWS_ACCESS_KEY_ID:-minioadmin}" "${AWS_SECRET_ACCESS_KEY:-minioadmin}"; do
  echo "MinIO not ready, retrying in 2s..."
  sleep 2
done
echo "Creating buckets..."
mc mb --ignore-existing "myminio/$AWS_MEDIA_STORAGE_BUCKET_NAME"
mc mb --ignore-existing "myminio/$AWS_SBOMS_STORAGE_BUCKET_NAME"
echo "Setting public access on media bucket..."
mc anonymous set public "myminio/$AWS_MEDIA_STORAGE_BUCKET_NAME"
echo "Done."
