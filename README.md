### About

Based on everything I’ve seen so far, a recent Google Pixel (8th generation or newer) running GrapheneOS offers the highest level of security among all widely available devices and operating systems. As an independent, external researcher interested in reproducible builds, I’ve been personally motivated to invest in continuously and automatically testing the reproducibility of GrapheneOS releases for the device I own.

Reproducible builds help users ensure that the official release images and binaries match the published source code of a given software, thereby providing transparency and fostering trust.

This project utilizes cloud instances from Hetzner to perform the following:
- Build GrapheneOS;
- Unpack images, archives, and other special or unusual file types;
  - Images, archives, and other file types containing additional nested files are unpacked iteratively until everything is extracted;
  - The signatures of certain files and images are stripped to prevent them from interfering with the comparison process.
- Compare the resulting reproduced build with the official build in order to see the differences;
- Publish the diffoscope output, showcasing all the differences between files in the official builds and the reproduced builds.

The fully automated reproducibility infrastructure is triggered when a GitHub Actions workflow (running every hour) detects a new official release in the alpha channel. Official releases that hit the alpha channel usually make their way to stable within a few hours, so it's nice to reproduce them as soon as they hit alpha.

The kernel and the base OS are both compiled to ensure full OS reproducibility. Vanadium and other minor apps (which I plan to build soon) are prebuilts copied from the GrapheneOS repositories. Vendor blobs are fetched directly from Google via `adevtool`, rather than from GrapheneOS repositories.

Currently, the tests I run cover the Google Pixel 8 Pro, the device I own. However, this project should work with any supported Pixel device, using parameters defined by environment variables before you run the initial script. You can run it on your own infrastructure, given the right device names and cloud provider tokens. For instructions, check the [technical documentation](infrastructure/hetzner/README.md).

### Results
- Diffoscope reports:
  - `https://gos-reproducibility-reports.s3.us-east-1.amazonaws.com/${PIXEL_CODENAME}-${BUILD_NUMBER}.html`. 
    - For example: https://gos-reproducibility-reports.s3.us-east-1.amazonaws.com/husky-2025070800.html

### FAQ
- **Why are only installation packages used? What about OTA updates and incrementals?**
  - Whether a clean install is performed using the `*-install-*` ZIP file, an `*-ota_update-*` ZIP file is sideloaded, or an incremental/delta update is applied via the Updater, the GrapheneOS partitions should, in the end, be exactly the same for a given release and device. The scripts build and compare the reproduced and official `*-install-*` ZIP files, and also calculate and publish the Verified Boot hash of the official build. This hash covers all the OS partitions. If the Verified Boot hash attested by the Auditor app on a Pixel device matches this published hash, it confirms that the operating system running on the device is exactly the same official build that was tested by the reproducibility tests.
    - The Auditor app can also periodically send results to your linked account on https://attestation.app, allowing you to maintain a history of your Verified Boot hashes.

### Pending work
- [ ] Build/reproduce Vanadium (and other critical/important apps).

For more, read the "TODO:" lines inside the code.