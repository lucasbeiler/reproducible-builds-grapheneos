## Running
To spin up a machine following my infrastructure scripts:
1. Set the required environment variables (see the last section);
2. Modify things as you wish;
3. Run create_server.sh. It will get the latest GrapheneOS build number and start a machine to reproduce the build.

Wait a few hours and check your bucket in order to see the reproducibility reports.

### Environment variables
Export the following variables in your shell with the appropriate values ​​for your intentions and setup. If you are running in a CI environment, set them as secret environment variables:
- `HETZNER_API_TOKEN="YOUR HETZNER API TOKEN"`
- `HETZNER_LOCATION="THE DESIRED LOCATION"`
- `AWS_BUCKET_NAME="THE NAME OF YOUR S3 BUCKET"`
- `AWS_ACCESS_KEY_ID="YOUR AWS ACCESS KEY ID WITH PROPER S3 PERMISSIONS"`
- `AWS_SECRET_ACCESS_KEY="YOUR AWS SECRET ACCESS KEY WITH PROPER S3 PERMISSIONS"`
- `AWS_DEFAULT_REGION="THE AWS REGION WHERE YOUR BUCKET IS LOCATED"`
- `AWS_BUCKET_NAME="THE AWS REGION WHERE YOUR BUCKET IS LOCATED"`
- `PIXEL_CODENAMES="THE CODENAME(S) OF YOUR PIXEL DEVICE(S) (e.g. "bluejay husky tokay")"`