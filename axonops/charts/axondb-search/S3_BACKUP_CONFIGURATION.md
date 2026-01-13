# S3 Backup Configuration for AxonDB Search

This document describes how to configure S3 backups for AxonDB Search (OpenSearch) using the Helm chart.

## Configuration Options

### Basic S3 Configuration

```yaml
backups:
  target:
    type: s3  # Change from 'local' to 's3'
    s3:
      bucket: "my-backup-bucket"
      region: "us-east-1"  # Optional - auto-detected if not set
      basePath: "opensearch/backups"  # Optional - base path within bucket
```

### Authentication Methods

#### Method 1: Using Existing Kubernetes Secret

Create a Kubernetes secret with AWS credentials:

```bash
kubectl create secret generic opensearch-s3-credentials \
  --from-literal=aws-access-key-id=YOUR_ACCESS_KEY \
  --from-literal=aws-secret-access-key=YOUR_SECRET_KEY \
  --from-literal=aws-session-token=YOUR_SESSION_TOKEN  # Optional
```

Then reference it in your values:

```yaml
backups:
  target:
    type: s3
    s3:
      bucket: "my-backup-bucket"
      credentials:
        existingSecret: "opensearch-s3-credentials"
```

#### Method 2: Inline Credentials (NOT RECOMMENDED for production)

```yaml
backups:
  target:
    type: s3
    s3:
      bucket: "my-backup-bucket"
      credentials:
        accessKeyId: "YOUR_ACCESS_KEY"
        secretAccessKey: "YOUR_SECRET_KEY"
        sessionToken: ""  # Optional - for temporary credentials
```

#### Method 3: Using IAM Roles (EKS Pod Identity / IRSA)

For EKS clusters using Pod Identity or IRSA, leave credentials empty and configure the service account:

```yaml
backups:
  target:
    type: s3
    s3:
      bucket: "my-backup-bucket"
      region: "us-east-1"
      # No credentials needed - handled by IAM role

rbac:
  serviceAccountAnnotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::ACCOUNT:role/opensearch-backup-role
```

### Snapshot Retention Policy

Configure automatic cleanup of old snapshots:

```yaml
backups:
  retention:
    # Keep snapshots for specified number of days (default: 30)
    # Set to 0 to disable retention-based cleanup
    days: 30

    # Optional: Maximum number of snapshots to keep
    # If both days and count are set, snapshots are deleted
    # if they exceed either limit
    count: 100  # Keep maximum 100 snapshots
```

**Retention Examples:**

1. **Time-based only (default)**:
   ```yaml
   retention:
     days: 30    # Delete snapshots older than 30 days
     count: ""   # No limit on number of snapshots
   ```

2. **Count-based only**:
   ```yaml
   retention:
     days: 0     # Disable age-based deletion
     count: 50   # Keep only the latest 50 snapshots
   ```

3. **Combined retention**:
   ```yaml
   retention:
     days: 30    # Delete snapshots older than 30 days
     count: 100  # AND keep maximum 100 snapshots
   ```

4. **Disable retention**:
   ```yaml
   retention:
     days: 0     # No automatic cleanup
     count: ""
   ```

### S3-Compatible Storage (MinIO, Ceph, etc.)

For S3-compatible storage systems like MinIO or Ceph:

```yaml
backups:
  target:
    type: s3
    s3:
      bucket: "my-backup-bucket"
      endpoint: "http://minio.example.com:9000"  # Your S3-compatible endpoint
      protocol: "http"  # or "https" - auto-detected from endpoint if not set
      pathStyleAccess: true  # Required for most S3-compatible storage
      region: "us-east-1"  # Some S3-compatible systems require a region
      credentials:
        accessKeyId: "minio-access-key"
        secretAccessKey: "minio-secret-key"
```

## Full Example Configuration

```yaml
# values.yaml
backups:
  enabled: true
  schedule: "0 2 * * *"  # Daily at 2 AM

  # Snapshot retention policy
  retention:
    days: 30  # Keep snapshots for 30 days (default)
    count: ""  # Optional: max number of snapshots to keep

  target:
    type: s3
    s3:
      bucket: "my-company-opensearch-backups"
      region: "us-west-2"
      basePath: "production/opensearch"

      # For S3-compatible storage only:
      # endpoint: "https://s3.company.internal"
      # pathStyleAccess: true

      credentials:
        # Option 1: Use existing secret
        existingSecret: "opensearch-s3-credentials"

        # Option 2: Inline (not recommended)
        # accessKeyId: "AKIAXXXXXXXXXXXXXXXX"
        # secretAccessKey: "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
```

## Verifying Configuration

After deploying with S3 backup configuration:

1. Check that environment variables are set:
```bash
kubectl exec -it opensearch-cluster-0 -- env | grep AWS
kubectl exec -it opensearch-cluster-0 -- env | grep AXONOPS_SEARCH_BACKUP
```

2. Check OpenSearch keystore (credentials are injected at startup):
```bash
kubectl exec -it opensearch-cluster-0 -- /usr/share/opensearch/bin/opensearch-keystore list
```

3. Verify backup repository creation:
```bash
kubectl exec -it opensearch-cluster-0 -- curl -k -u admin:admin \
  https://localhost:9200/_snapshot/axonops_backup?pretty
```

## Troubleshooting

### Common Issues

1. **Missing S3 plugin**: The repository-s3 plugin is automatically installed in the Docker image.

2. **Credential errors**: Check that AWS credentials are properly set:
   - For environment variables: AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY must be set
   - For Pod Identity: Verify the service account has the correct IAM role annotation

3. **Bucket access errors**: Ensure the IAM user/role has the required S3 permissions:
   - s3:ListBucket on the bucket
   - s3:GetObject, s3:PutObject, s3:DeleteObject on bucket objects

4. **S3-compatible storage issues**:
   - Ensure `pathStyleAccess: true` is set
   - Verify the endpoint URL is correct and accessible from the pods
   - Check that the protocol (http/https) matches your storage system

## Required IAM Permissions

The IAM user or role needs the following minimum permissions:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:ListBucket",
        "s3:GetBucketLocation"
      ],
      "Resource": "arn:aws:s3:::my-backup-bucket"
    },
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject"
      ],
      "Resource": "arn:aws:s3:::my-backup-bucket/*"
    }
  ]
}
```