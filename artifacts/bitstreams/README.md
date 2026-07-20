# Bitstream Artifacts

Local bitstream copies go here for board deployment and handoff.

Use the build tag as the file stem, normally the git short SHA:

```text
<git-short-sha>.bit
<git-short-sha>.bin
<git-short-sha>.manifest.json
```

Bitstream binaries are ignored by git. Commit only small manifests or notes that
record the source commit, Vivado version, timing summary, and remote build path.
