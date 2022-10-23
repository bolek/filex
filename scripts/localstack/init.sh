docker run --rm -it -p 4566-4583:4566-4583 -p 8055:8080 \
    -e AWS_DEFAULT_REGION='us-east-1' \
    -e SERVICES='s3' \
    -e EDGE_PORT='4566' \
    localstack/localstack