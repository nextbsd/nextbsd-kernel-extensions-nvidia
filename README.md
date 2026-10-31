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
nextbsd-kernel ──▶ nextbsd-kernel-extensions-graphics ──graphics-updated──▶ this repo
 (kernel obj)       (graphics-kexts-amd64.tar.gz)                     (nvidia-kexts-amd64.tar.gz)
```

A chain run (freebsd-src's sync when `releng/15.1` moves, or its Sync Fork with `force`) reaches this repo last: after
nextbsd-kernel-extensions-graphics publishes graphics kexts in that run, it dispatches `graphics-updated` here. A merge
elsewhere does not; after one, run this repo's workflow by hand once the graphics kexts are republished.

`nvidia-drm` is built against drm-kmod and checks the DRM API in the built `drm.ko`. This repo does not rebuild
drm-kmod. It takes `drm.ko` and `dmabuf.ko` out of the graphics kexts that nextbsd-kernel-extensions-graphics published
(`IOGraphics.kext` and `DMABuf.kext`, found by bundle identifier). It also reads that repo's `DRM_KMOD_REF` at the
same commit, so the drm-kmod headers always match the `drm.ko`. At runtime `NVIDIAGraphics595` depends on
`IOGraphics.kext` through `OSBundleLibraries`.

## Triggers

- `repository_dispatch: graphics-updated` from nextbsd-kernel-extensions-graphics, in chain runs;
- `push` to `main` touching the workflow or `tools/`;
- `pull_request` (build only, never publishes);
- `workflow_dispatch`.

## Output

The `continuous` release carries `nvidia-kexts-amd64.tar.gz` (stable name, overwritten on each publish).
nextbsd-pkg packages it as `NextBSD-kernel-extensions-nvidia`, amd64 only. The tarball holds only the bundles, since it
is unpacked straight into `/System/Library/Extensions`. Each kext's `Info.plist` carries `NBSDKernelABIVersion`, the
nextbsd-kernel ABI version it was built for (e.g. `27.0`, nextbsd-kernel#376), and the legacy `NBSDKernelBuildID`, that
kernel's `KERNEL-BUILD-ID` (nextbsd-kernel#326). `nvidia-kexts-amd64.BUILD-INFO`, a separate asset, records
the NVIDIA version and the kernel, graphics and drm-kmod builds it was made against.

## Kernel SDK and ABI version

`tools/fetch-kernel-sdk.sh` downloads the kernel SDK, `kernel-sdk-amd64.tar.gz` (nextbsd-kernel#327): the kernel's headers,
generated options, `KERNEL-BUILD-ID` and its `KERNEL-VERSION` and `KERNEL-ABI-VERSION` (nextbsd-kernel#376; an older SDK
has neither, and its `KERNEL-BUILD-ID` stands in for both). The NVIDIA modules build with `SYSDIR` pointing into it, with
no kernel source or obj tree and no kernel relink. `tools/stamp-kernel-abi.py` writes `NBSDKernelABIVersion` and
`NBSDKernelBuildID` into each kext. The build fails if the published graphics kexts carry a different
`NBSDKernelABIVersion` or `NBSDKernelBuildID` than that kernel: rebuild the graphics kexts first.

NextBSD reports `__FreeBSD_version` 2700000 while keeping the releng/15.1 kernel API (nextbsd-kernel#376). The 595.84
sources, after the port patches and `tools/nvidia-portpatch.sh`, have no gate that picks a FreeBSD 16 path at 2700000:
the only `>= 1600000` gate is the port's "FreeBSD-CURRENT" `#error` in `nv-freebsd.h`, which `nvidia-portpatch.sh`
already deletes, and every other gate takes the same branch at 1501000 and 2700000. Re-check on a driver bump.

## Tools

`tools/` holds the scripts this build uses, copied from nextbsd-kernel-extensions-graphics when the NVIDIA build moved here:
`ko2kext.sh`, `gen-nvidia-personalities.sh`, `nvidia-portpatch.sh`, `nvidia-mkbundle.sh` and `nvidia-activate.sh`.
`nvidia-mkbundle.sh` and `nvidia-activate.sh` are at `04b714a` (nextbsd-kernel-extensions-graphics#98); the rest at `a35dc83`.
`fetch-kernel-sdk.sh` and `stamp-kernel-abi.py` are shared with nextbsd-kernel-extensions and -graphics.

`patches/freebsd-ports/` holds the FreeBSD port's driver patches, pinned to one ports commit (see its README).

## Userland bundle and Mesa

`NVIDIA595.bundle` does not carry `libgbm.so.1`. NextBSD-mesa provides it in `/usr/X11/lib`, and nextbsd-pkg lists
it in `shlibs_required_ignore`, so the NVIDIA package doesn't depend on Mesa. `nvidia-activate.sh` links the bundle
into `/usr/X11` (the GBM backend into `/usr/X11/lib/gbm`, Mesa's backend path), and the EGL external-platform files
into `/usr/share/egl/egl_external_platform.d`, the only place `libEGL_nvidia` looks. The build fails if the bundle
carries a libgbm or NEEDs gallium or LLVM.

The driver version must be 595.x: the kext and bundle names are fixed at 595, and the stored patches are for that
branch.

## License

The build scripts are BSD-2-Clause (`LICENSE`). The NVIDIA driver itself is distributed under NVIDIA's own license,
included in the driver tarball.
