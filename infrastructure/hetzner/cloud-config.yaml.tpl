#cloud-config
write_files:
- encoding: b64
  content: ${STARTUP_SCRIPT_B64}
  owner: root:root
  path: /usr/local/bin/startup_script
  permissions: '0755'
- encoding: b64
  content: ${DELETE_SERVER_B64}
  owner: root:root
  path: /usr/local/bin/delete_server
  permissions: '0755'
- encoding: b64
  content: ${BUILD_GOS_B64}
  owner: root:root
  path: /usr/local/bin/build_gos
  permissions: '0755'
- encoding: b64
  content: ${DETECT_DEVICE_B64}
  owner: root:root
  path: /usr/local/bin/detect_device
  permissions: '0755'
- encoding: b64
  content: ${COMPARE_GOS_B64}
  owner: root:root
  path: /usr/local/bin/compare_gos
  permissions: '0755'
- path: /etc/profile.d/custom_env_vars.sh
  content: |
    export PIXEL_CODENAME=$PIXEL_CODENAME
    export GOS_BUILD_NUMBER=$GOS_BUILD_NUMBER
    export GOS_BUILD_DATETIME=$GOS_BUILD_DATETIME
  permissions: '0755'
- path: /root/.bashrc
  append: true
  content: |
    # The variables, but also including the ones that should be exclusive to the root user.
    export HETZNER_API_TOKEN=$HETZNER_API_TOKEN
    export AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID
    export AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY
    export AWS_DEFAULT_REGION=$AWS_DEFAULT_REGION
    export AWS_BUCKET_NAME=$AWS_BUCKET_NAME
    export PIXEL_CODENAME=$PIXEL_CODENAME
    export GOS_BUILD_NUMBER=$GOS_BUILD_NUMBER
    export GOS_BUILD_DATETIME=$GOS_BUILD_DATETIME

runcmd:
    - [ /usr/local/bin/startup_script ]