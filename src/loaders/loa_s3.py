import boto3


def upload_raw_to_s3(
    local_path: str,
    bucket: str,
    object_key: str
):
    s3 = boto3.client("s3")
    s3.upload_file(local_path, bucket, object_key)

    print(f"Rawデータ保存完了: s3://{bucket}/{object_key}")
