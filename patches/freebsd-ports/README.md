# FreeBSD port patches for the NVIDIA 595 driver

The four `SUB_PATCHES` from FreeBSD's `x11/nvidia-driver` port that apply to the 595 branch, stored here
unchanged so the build doesn't fetch them from the port's `main` branch.

Pinned to freebsd-ports commit
[`1587486a39ecf579cc59f878a75faef823441e2b`](https://github.com/freebsd/freebsd-ports/commit/1587486a39ecf579cc59f878a75faef823441e2b)
(2026-01-03, the last change to `x11/nvidia-driver/files`). The port has moved on to 595.104.02; these files were
unchanged at the time they were copied here.

The build replaces the only token, `%%NVSRC%%`, with `nvidia` and applies each with `patch -p0`. To update, copy the
files from a newer ports commit and change the commit above in the same PR.
