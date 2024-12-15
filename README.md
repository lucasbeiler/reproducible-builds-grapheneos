## Disclaimer

This project is a work in progress and will continue to evolve toward greater robustness, simplicity, and modularity. For now, don't take the results too seriously, and keep in mind that it is crucial that you know how to interpret them.

I am NOT affiliated with the GrapheneOS Foundation. I am simply an individual who is interested in reproducible builds, particularly for this operating system that I run on my phone and will play an even larger role in my life in the future with the rumored Google Pixel Laptop. Based on everything I've seen so far, a recent Google Pixel (8th/9th gen) running GrapheneOS provides the most secure device and operating system that most people can have, so I decided to invest in reproducible builds for it myself.

Reproducible builds help users ensure that the official release images match the published source code of a given software, providing transparency and fostering trust.

This project utilizes cloud instances from Hetzner to perform the following:
- Build GrapheneOS;
- Unpack images, archives, and other special or unusual file types;
  - Images, archives, and other file types containing additional nested files are unpacked iteratively until everything is extracted;
  - The signatures of certain files and images are stripped to prevent them from interfering with the comparison process.
- Compare the resulting reproduced build with the official build in order to see the differences;
- Publish the diffoscope output, showcasing all the differences between files in the official builds and the reproduced builds.

The fully automated reproducibility infrastructure will be triggered when a GitHub Actions workflow (running hourly) detects a new official release in the alpha channel. Official releases that hit the alpha channel usually make their way to stable within a few hours, so it's nice to reproduce them as soon as they hit alpha.

The kernel and base OS are both compiled to ensure full OS reproducibility — no prebuilts are used, except for Vanadium and other apps (which I'll build soon). Vendor blobs are fetched directly from Google via `adevtool`, rather than from GrapheneOS repositories.

Currently, this work is limited to the Google Pixel 8 Pro, which is the device I own. However, feel free to use this project with other devices. My scripts might be a bit messy at the moment, but it's a work in progress after all. This project should work with any supported Pixel device, using parameters defined by environment variables before you run the initial script. You can run it on your own infrastructure, given the right device names and cloud provider tokens. To know how to do so, check the [technical documentation](infrastructure/hetzner/README.md).

### Results
- Diffoscope reports:
  - `https://gos-reproducibility-reports.s3.us-east-1.amazonaws.com/${PIXEL_CODENAME}-install-${BUILD_NUMBER}.html`. 
    - For example: https://gos-reproducibility-reports.s3.us-east-1.amazonaws.com/husky-install-2024121200.html
  - `https://gos-reproducibility-reports.s3.us-east-1.amazonaws.com/${PIXEL_CODENAME}-ota_update-${BUILD_NUMBER}.html`. 
    - For example: https://gos-reproducibility-reports.s3.us-east-1.amazonaws.com/husky-ota_update-2024121200.html
- SHA512 hashes of the official builds that were downloaded before comparing:
  - `https://gos-reproducibility-reports.s3.us-east-1.amazonaws.com/${PIXEL_CODENAME}-${BUILD_NUMBER}.checksums.txt`. 
    - For example: https://gos-reproducibility-reports.s3.us-east-1.amazonaws.com/husky-2024121200.checksums.txt
- Hashes of the partitions in the official OTA that was tested/compared with my reproduced build. These hashes are compared with the target hashes of the incrementals/deltas to see if they are trustworthy too:
  - `https://gos-reproducibility-reports.s3.us-east-1.amazonaws.com/ota-partitions-${PIXEL_CODENAME}-${GOS_BUILD_NUMBER}.txt`. 
    - For example: https://gos-reproducibility-reports.s3.us-east-1.amazonaws.com/ota-partitions-husky-2024121200.txt


### Pending work
- [ ] Build/reproduce Vanadium, App Store, Camera, PDF Viewer, TalkBack, GmsCompat, and Info;
- [ ] Compare factory images too. Currently, only full OTA, incremental/delta and install packages are reproduced and compared with the official ones;
- [ ] Sign the artifacts before uploading so that people can verify;
- [ ] Wrap the scripts in Docker for those who want to run them locally.

For more, read the "TODO:" lines inside the code.
