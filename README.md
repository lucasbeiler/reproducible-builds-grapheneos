## Disclaimer

This project is a work in progress and will continue to evolve toward greater robustness, simplicity, and modularity. Keep in mind that it is crucial that you know how to interpret the results.

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

Currently, the tests I do myself are limited to the Google Pixel 8 Pro, the device I own. However, this project should work with any supported Pixel device, using parameters defined by environment variables before you run the initial script. You can run it on your own infrastructure, given the right device names and cloud provider tokens. To know how to do so, check the [technical documentation](infrastructure/hetzner/README.md).

### Results
- Diffoscope reports:
  - `https://gos-reproducibility-reports.s3.us-east-1.amazonaws.com/${PIXEL_CODENAME}-${BUILD_NUMBER}.html`. 
    - For example: https://gos-reproducibility-reports.s3.us-east-1.amazonaws.com/husky-2024121200.html
- Verified Boot hash covering the partitions in the official build that I have tested:
  - `https://gos-reproducibility-reports.s3.us-east-1.amazonaws.com/avb-hash-${PIXEL_CODENAME}-${GOS_BUILD_NUMBER}.txt`. 
    - For example: https://gos-reproducibility-reports.s3.us-east-1.amazonaws.com/avb-hash-husky-2024121200.txt

### FAQ
- **Why are only install packages compared and compiled? What about OTA updates and incrementals?**
  - Whether a clean install is performed using the `*-install-*` ZIP file, an ota_update ZIP file is sideloaded, or an incremental/delta update is applied via the Updater, the GrapheneOS partitions will ultimately be the same for a given release. The scripts build and compare `*-install-*` ZIP files, and also calculate and publish the Verified Boot hash of the official build. This hash covers all these partitions. If the Verified Boot hash shown in the Auditor app on a Pixel device matches this published hash, it confirms that the official build running on the device is exactly the same as the official one that was tested.

### Pending work
- [ ] Build/reproduce Vanadium, App Store, Camera, PDF Viewer, TalkBack, GmsCompat, and Info;
- [ ] Sign the artifacts before uploading so that people can verify;
- [ ] Use different users to build and compare;
- [ ] Wrap the scripts in Docker for those who want to run them locally.

For more, read the "TODO:" lines inside the code.
