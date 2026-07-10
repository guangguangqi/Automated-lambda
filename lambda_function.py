import json
import boto3
import re
import os

# Initialize the AWS Batch Client
batch_client = boto3.client('batch')

# Fetch structural environment settings from Lambda configuration
JOB_QUEUE = os.environ.get('BATCH_JOB_QUEUE', 'bioinfo-pipeline-queue')
JOB_DEFINITION = os.environ.get('BATCH_JOB_DEFINITION', 'snakemake-qc-runner:1')

def lambda_handler(event, context):
    # 1. Parse metadata records from the S3 Event Notification
    for record in event['Records']:
        bucket_name = record['s3']['bucket']['name']
        file_key = record['s3']['object']['key'] # e.g., "raw/Sample_A_R1.fastq.gz"
        
        print(f"Detected new file upload: s3://{bucket_name}/{file_key}")
        
        # 2. Gatekeeper Check: We only want to trigger the pipeline once per sample.
        # We catch the Forward Read (_R1) to execute, and ignore the Reverse Read (_R2).
        if "_R1.fastq.gz" not in file_key:
            print("Skipping trigger (not a Forward Read _R1 file) to avoid duplicate runs.")
            continue
            
        # 3. Extract the clean Sample ID using regex
        # Transforms "raw/Sample_A_R1.fastq.gz" -> "Sample_A"
        filename = file_key.split('/')[-1]
        sample_id = re.sub(r'_R1\.fastq\.gz$', '', filename)
        
        # Define the structural directory path where the clean files should be written back
        output_prefix = f"s3://{bucket_name}/processed/{sample_id}/"
        
        print(f"Automating pipeline invocation for Sample: {sample_id}")
        
        # 4. Programmatically submit the containerized execution payload to AWS Batch
        try:
            response = batch_client.submit_job(
                jobName=f"Snakemake_QC_{sample_id}",
                jobQueue=JOB_QUEUE,
                jobDefinition=JOB_DEFINITION,
                # Pass runtime configuration as container overrides (Environment Variables)
                containerOverrides={
                    'environment': [
                        {'name': 'SAMPLE_ID', 'value': sample_id},
                        {'name': 'S3_BUCKET', 'value': bucket_name},
                        {'name': 'S3_KEY_R1', 'value': file_key},
                        {'name': 'S3_KEY_R2', 'value': file_key.replace('_R1.fastq.gz', '_R2.fastq.gz')},
                        {'name': 'S3_OUTPUT_DIR', 'value': output_prefix}
                    ]
                }
            )
            print(f"Successfully submitted AWS Batch Job ID: {response['jobId']}")
            
        except Exception as e:
            print(f"Critical error invoking AWS Batch: {str(e)}")
            raise e
            
    return {
        'statusCode': 200,
        'body': json.dumps('AWS Batch pipeline automation sequence triggered successfully.')
    }

