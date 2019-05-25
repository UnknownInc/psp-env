# Default values for node projects.
# This is a YAML-formatted file.
# Declare variables to be passed into your templates
deployment:
  namespace: dev
psp:
  image:
    repository: gcr.io/GOOGLE_CLOUD_PROJECT/psp-PSP_BRANCH_NAME:PSP_COMMIT_SHA
    tag: latest
    pullPolicy: IfNotPresent