# Default values for node projects.
# This is a YAML-formatted file.
# Declare variables to be passed into your templates
deployment:
  namespace: dev
psp:
  image:
    repository: PSP_REPO
    tag: PSP_TAG
    pullPolicy: IfNotPresent