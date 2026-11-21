# Automatic public addon packaging

Default-branch pushes and manual workflow runs build a manifest-only install ZIP, submit it to CurseForge, and publish the ZIP/checksum as a GitHub prerelease. Matching version tags use the addon's declared release type. Other branch pushes only build an Actions artifact.

Set secret CF_API_TOKEN and variable CF_PROJECT_ID. Optional CF_GAME_VERSION_IDS accepts actual CurseForge version IDs; when unset, gameVersionNames selects 1.60.1. WoW Interface 16001 is handled as a client interface number, not sent as a CurseForge version ID. Missing upload credentials fail the upload step explicitly. A successful submission records the CurseForge file ID in the run summary and dist/*.upload.json. CurseForge moderation is separate from submission.

Only declared addon files and public README/license/changelog/art assets enter install ZIPs. Private toolkit and UberAdmin folders are excluded. The workflow never packages the entire repository.
