gcloud run deploy hpo-ingest-service \
    --source hpo-ingest-service \
    --region us-east1 \
    --platform managed \
    --allow-unauthenticated \
    --memory=2Gi \
    --set-env-vars GCS_BUCKET=external-dataset-ingest,BQ_PROJECT=clingen-dev,BQ_DATASET=clinvar_ingest


# # modify the memory allocation
# gcloud run services update hpo-ingest-service \
#     --memory=2Gi \
#     --region=us-east1

# # handy command to get the service account permissions for the compute engine
# gcloud projects get-iam-policy clingen-dev --flatten="bindings[].members" --format="table(bindings.role,bindings.members)" | grep 522856288592-compute@developer.gserviceaccount.com

# # redeploy the service
# gcloud run deploy hpo-ingest-service \
#     --region=us-east1 \
#     --allow-unauthenticated