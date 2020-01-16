## Knative plugin
Install `knctl` by grabbing pre-built binaries from the [Releases](https://github.com/cppforlife/knctl/releases) page
```
$ shasum -a 256 ~/Downloads/knctl-*
# Compare checksum output to what's included in the release notes

$ mv ~/Downloads/knctl-* /usr/local/bin/kubectl-kn

$ chmod +x /usr/local/bin/kubectl-kn

$ cp /usr/local/bin/kubectl-kn /usr/local/bin/knctl

```
kubectl will find any binary named `kubectl-*` on your `PATH` and consider it as a plugin

```
$ ./kubectl plugin list

/usr/local/bin/kubectl-kn
```

## List Knative services

```
$ kubectl kn service list -n prod
```

## List revisions
```
$ kubectl kn revision list -n prod --service psb
```

## Delete revisions

```
$ kubectl kn revision delete -n prod -r psp-xxxx
```