# nextbsd-kernel-extensions-nvidia

Builds NextBSD's **NVIDIA kernel extensions**, for **amd64 only**:

- the chained `NVIDIAGraphics595` (nvidia-drm), `NVIDIAModeset595` and `NVIDIACore595` kexts, with the GSP
  firmware and Turing+ device-match tables;
- the `NVIDIA595.bundle` userland (X11, GL, EGL, GBM) that ships alongside them.

NVIDIA's driver is proprietary, so it lives apart from the FreeBSD-derived kexts and the drm-kmod graphics kexts.
See the [E21 plan](https://github.com/nextbsd/nextbsd-userland/wiki/E21-FreeBSD-Module-Kext-Conversion-Plan),
decision D3, and nextbsd/nextbsd#547.

## Build chain

```
nextbsd-kernel ──▶ nextbsd-kernel-extensions ··· (run by hand) ···▶ this repo
 (kernel obj)       (graphics-kexts-amd64.tar.gz)                     (nvidia-kexts-amd64.tar.gz)
```

Nothing upstream starts this build automatically (for now). After nextbsd-kernel-extensions publishes new graphics
kexts, run this repo's workflow by hand.

`nvidia-drm` is built against drm-kmod and checks the DRM API in the built `drm.ko`. This repo does not rebuild
drm-kmod. It takes `drm.ko` and `dmabuf.ko` out of the graphics kexts that nextbsd-kernel-extensions published
(`IOGraphics.kext` and `DMABuf.kext`, found by bundle identifier). It also reads that repo's `DRM_KMOD_REF` at the
same commit, so the drm-kmod headers always match the `drm.ko`. At runtime `NVIDIAGraphics595` depends on
`IOGraphics.kext` through `OSBundleLibraries`.

## Triggers

- `push` to `main` touching the workflow or `tools/`;
- `pull_request` (build only, never publishes);
- `workflow_dispatch`.

## Output

The `continuous` release carries `nvidia-kexts-amd64.tar.gz` (stable name, overwritten on each publish).
nextbsd-pkg packages it as `NextBSD-kernel-extensions-nvidia`, amd64 only. `BUILD-INFO` inside the tarball records
the NVIDIA version and the kernel, graphics and drm-kmod builds it was made against.

## Tools

`tools/` holds the scripts this build uses, copied unchanged from nextbsd-kernel-extensions (`a35dc83`) when the
NVIDIA build moved here: `ko2kext.sh`, `gen-nvidia-personalities.sh`, `nvidia-portpatch.sh`, `nvidia-mkbundle.sh`
and `nvidia-activate.sh`.

## License

The build scripts are BSD-2-Clause (`LICENSE`). The NVIDIA driver itself is distributed under NVIDIA's own license,
included in the driver tarball.
