# Acceptance examples

- `coco/`: 20 images from the official COCO 2017 validation image host.
- `imagenet/`: 20 public ImageNet-1k class samples, with class IDs and synsets in the manifest.

These samples are a compact functional test set. They validate FPGA/compiler agreement and
exercise the host heads; they are not large enough to claim COCO mAP or ImageNet Top-1 accuracy.
`python run.py --acceptance` runs every selected image in native INT8 and widened INT16 mode.
