## Running
To spin up a Hetzner machine following my infrastructure scripts:
1. Set the required environment variables (see the last section);
2. Modify things as you wish;
3. Run `create_server.sh`. It will get the latest GrapheneOS build number and start a machine to reproduce the build.

Wait a few hours, then check your bucket to see the reproducibility reports.

If you want to run locally, use Docker. To learn how to start the containers, read the last few lines of `infrastructure/hetzner/startup_script.sh` and check the `docker-compose.yml` file to know how the volumes are expected to be.

### Environment variables
Export the following variables in your shell with the appropriate values for your setup and use case. If you are running in a CI environment, set them as secret environment variables:
- `HETZNER_API_TOKEN="YOUR HETZNER API TOKEN"`
- `HETZNER_LOCATION="THE DESIRED LOCATION"`
- `AWS_BUCKET_NAME="THE NAME OF YOUR S3 BUCKET"`
- `AWS_ACCESS_KEY_ID="YOUR AWS ACCESS KEY ID WITH PROPER S3 PERMISSIONS"`
- `AWS_SECRET_ACCESS_KEY="YOUR AWS SECRET ACCESS KEY WITH PROPER S3 PERMISSIONS"`
- `AWS_DEFAULT_REGION="THE AWS REGION WHERE YOUR BUCKET IS LOCATED"`
- `PIXEL_CODENAMES="THE CODENAME(S) OF YOUR PIXEL DEVICE(S) (e.g. "bluejay husky tokay")"`
- `ARBITRARY_GOS_BUILD_NUMBER="2025030300"`
- `NONROOT_USER="anything"`
- `GIT_COOKIES_B64="YOUR_BASE64_ENCODED_GITCOOKIES_FILE_CONTAINING_YOUR_GOOGLESOURCE_PASSWORD"`

NOTE: Set `ARBITRARY_GOS_BUILD_NUMBER` to the release you want to reproduce (provided that the older release is still available for download from the GrapheneOS servers), rather than defaulting to the latest one.