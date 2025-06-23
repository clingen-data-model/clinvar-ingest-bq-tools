# gcloud iam service-accounts create eventarc-invoker \
#     --description="Service account for Eventarc to invoke Cloud Run" \
#     --display-name="Eventarc Invoker"

# gcloud projects add-iam-policy-binding clingen-dev \
#     --member=serviceAccount:eventarc-invoker@clingen-dev.iam.gserviceaccount.com \
#     --role=roles/eventarc.eventReceiver

# gcloud projects add-iam-policy-binding clingen-dev \
#     --member=serviceAccount:eventarc-invoker@clingen-dev.iam.gserviceaccount.com \
#     --role=roles/run.invoker

# # the pub/sub role must be added to the default GCS service account [PROJECT_NUMBER]-compute@developer.gserviceaccount.com
# gcloud projects add-iam-policy-binding clingen-dev \
#     --member=serviceAccount:522856288592-compute@developer.gserviceaccount.com \
#     --role=roles/pubsub.publisher

# gcloud projects add-iam-policy-binding clingen-dev \
#     --member=serviceAccount:522856288592-compute@developer.gserviceaccount.com \
#     --role=roles/eventarc.eventReceiver

# reference https://cloud.google.com/eventarc/standard/docs/run/create-trigger-storage-gcloud#before-you-begin 
# for assistance.

#delete trigger
gcloud eventarc triggers delete gcs-ingest-trigger --location=us-east1
#recreate trigger
gcloud eventarc triggers create gcs-ingest-trigger \
    --location=us-east1 \
    --destination-run-service=gcs-file-ingest-service \
    --destination-run-region=us-east1 \
    --event-filters=type=google.cloud.storage.object.v1.finalized \
    --event-filters=bucket=external-dataset-ingest \
    --service-account=eventarc-invoker@clingen-dev.iam.gserviceaccount.com
