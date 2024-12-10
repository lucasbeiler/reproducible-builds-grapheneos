## Disclaimer

This project is a work in progress and will continue to evolve toward greater robustness, simplicity, and modularity.

**For now**, don't take the results too seriously. Also, it's important that you know how to interpret them!

I am **NOT** affiliated with the GrapheneOS Foundation. I am simply an individual who is interested in reproducible builds, particularly for this operating system that I run on my phone and will play an even larger role in my life in the future with the rumored Google Pixel Laptop. From everything I've seen, a recent Google Pixel running GrapheneOS is the most secure device most people could have, so I decided to invest in reproducible builds for it myself.

This project:
- Builds GrapheneOS on Hetzner Cloud machines;
- Unpacks images, archives and other special/unusual file types;
  - Images, archives and other special/unusual file types that contain images, archives and other special/unusual file types are also unpacked iteratively until everything is unpacked;
  - Signatures are stripped/removed from certain files and images in order to prevent them from messing with the comparison.
- Compares the resulting build with the official one for any given release;
- Publishes the diffoscope output showing all the differences between files from the official builds and my builds.

Reproducible builds ensure official GrapheneOS release images match the published source code, providing transparecy and trust.

A new build will be triggered as soon as a release reaches the alpha channel. Official releases that hit the alpha channel usually make their way to stable within a few hours, so it's nice to reproduce them as early as they hit alpha.

Kernel and base OS are both compiled to ensure full OS reproducibility — no prebuilts are used (except for Vanadium and other apps, but I'll build them all soon). Vendor blobs are fetched directly from Google via `adevtool`, rather than from the GrapheneOS repositories.

Currently, this work is limited to the Google Pixel 8 Pro, the device I own. However, feel free to fork this project for other devices. My scripts might be a bit messy at the moment, but it's work in progress after all.

### Results
The diffoscope reports are available at URLs that follow this pattern:
- `https://gos-reproducibility-reports.s3.us-east-1.amazonaws.com/${PIXEL_CODENAME}-${BUILD_NUMBER}.html`. 
  - For example: https://gos-reproducibility-reports.s3.us-east-1.amazonaws.com/husky-2024120400.html

The SHA512 hashes of the official builds that were tested/compared with are available at URLs that follow this pattern:
- `https://gos-reproducibility-reports.s3.us-east-1.amazonaws.com/${PIXEL_CODENAME}-${BUILD_NUMBER}.checksums`. 
  - For example: https://gos-reproducibility-reports.s3.us-east-1.amazonaws.com/husky-2024120400.checksums

### Pending work
- [ ] Build/reproduce Vanadium, App Store, Camera, PDF Viewer, TalkBack, GmsCompat, and Info;
- [ ] Compare incremental and factory images too, instead of just ota_update and install images;
  - Since I already compare the official OTA update images with my reproduced ones, I'd just need to verify whether the files within each incremental update file match the hashes of their respective counterparts in the official OTA images that I compared my reproduced build to.
- [ ] Decide whether to continue using `7z x` or mounting filesystem images instead;
- [ ] In the instance, store the scripts somewhere appropriate, rather than /usr/local/bin/;
- [ ] Sign the artifacts before uploading so that people can verify.
