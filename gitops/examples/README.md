# GitOps examples

Reference manifests that are **not** auto-deployed by Flux (this directory is not
referenced by any Flux `Kustomization`). Copy or `kubectl apply` individual files
as needed.

## cloudnative-pg/cluster.yaml

A sample CloudNativePG `Cluster` (2 instances: 1 primary + 1 streaming replica)
using the `longhorn-cnpg` StorageClass (single-replica, `WaitForFirstConsumer`,
`Retain`). HA is provided by Postgres streaming replication, not Longhorn
replication.

Prereqs:
- Longhorn installed + `longhorn-cnpg` StorageClass applied
  (`gitops/infrastructure/config/longhorn-cnpg/storageclass.yaml`).
- CloudNativePG operator installed
  (`gitops/infrastructure/controllers/cloudnative-pg/`).
- The bootstrap secret created out-of-band (see the manifest header).
