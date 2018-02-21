# Fluent::Plugin::Papertrail

[![Gem Version](https://badge.fury.io/rb/fluent-plugin-papertrail.svg)](https://badge.fury.io/rb/fluent-plugin-papertrail) [![Docker Repository on Quay](https://quay.io/repository/solarwinds/fluentd-kubernetes/status "Docker Repository on Quay")](https://quay.io/repository/solarwinds/fluentd-kubernetes) [![CircleCI](https://circleci.com/gh/solarwinds/fluent-plugin-papertrail/tree/master.svg?style=shield)](https://circleci.com/gh/solarwinds/fluent-plugin-papertrail/tree/master)

## Description

This repository contains the Fluentd Papertrail Output Plugin and the Docker and Kubernetes assets for deploying that combined Fluentd, Papertrail, Kubernetes log aggregation toolset to your cluster.

## Installation

Install this gem when setting up fluentd:
```ruby
gem install fluent-plugin-papertrail
```

## Usage

### Setup

This plugin connects to Papertrail log destinations over TCP+TLS. This connection method should be enabled by default in standard Papertrail accounts, see:
```
papertrailapp.com > Settings > Log Destinations
```

To configure this in fluentd:
```xml
<match whatever.*>
  type papertrail
  papertrail_host <your papertrail hostname>
  papertrail_port <your papertrail port>
</match>
```

Use a record transform plugin to populate within the record the following fields:
```
    message   The log
    program   The program/tag
    severity  A valid syslog severity label
    facility  A valid syslog facility label
    hostname  The source hostname for papertrail logging
```

The following snippet sets up the records for Kubernetes and assumes you are using
the [fluent-plugin-kubernetes_metadata_filter](https://github.com/fabric8io/fluent-plugin-kubernetes_metadata_filter) plugin which populates the record with useful metadata:
```yaml
<filter kubernetes.**>
  type kubernetes_metadata
</filter>

<filter kubernetes.**>
  type record_transformer
  enable_ruby true
  <record>
    hostname ${record["kubernetes"]["namespace_name"]}-${record["kubernetes"]["pod_name"]}
    program ${record["kubernetes"]["container_name"]}
    severity info
    facility local0
    message ${record['log']}
  </record>
</filter>
```

### Advanced Configuration
This plugin inherits a few useful config parameters from Fluent's BufferedOutput class.

Parameters for flushing the buffer, based on size and time, are `buffer_chunk_limit` and `flush_interval`, respectively. This plugin overrides the inherited default `flush_interval` to `1`, causing the fluent buffer to flush to Papertrail every second. 

If the plugin fails to write to Papertrail for any reason, the log message will be put back in Fluent's buffer and retried. Retrying can be tuned and inherits a default configuration where `retry_wait` is set to `1` second and `retry_limit` is set to `17` attempts.

If you want to change any of these parameters simply add them to a match stanza. For example, to flush the buffer every 60 seconds and stop retrying after 2 attempts, set something like:
```xml
<match whatever.*>
  type papertrail
  papertrail_host <your papertrail hostname>
  papertrail_port <your papertrail port>
  flush_interval 60
  retry_limit 2
</match>
```

## Kubernetes

This repo also includes Kubernetes and Docker assets which do all of the heavy lifting for you.

If you'd like to deploy this plugin as a DaemonSet to your Kubernetes cluster, just adjust the `FLUENT_*` environment variables in `kubernetes/fluentd-daemonset-papertrail.yaml` and push it to your cluster with:

```
kubectl apply -f kubernetes/fluentd-daemonset-papertrail.yaml
```

The Dockerfile that generates [the image used in this DaemonSet](https://quay.io/repository/solarwinds/fluentd-kubernetes), can be found at `docker/Dockerfile`.

## Development

We use GitHub, Make and Docker. 
We have a [scratch Dockerfile](Dockerfile.scratch) where we build an image that contains all the dependencies for working with the RubyGem.
We have a [Makefile](Makefile) to wrap the common functions and make life easier.

### Install
`make install`

### Test
`make test`

### Release in [RubyGems](https://rubygems.org/gems/fluent-plugin-papertrail)
To release a new version, update the version number in the [GemSpec](fluent-plugin-papertrail.gemspec) and then, run:

`make release`

### Release in [Quay.io](https://quay.io/repository/solarwinds/fluentd-kubernetes)

`make release-docker TAG=$(VERSION)`

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/solarwinds/fluent-plugin-papertrail.

## License

The gem is available as open source under the terms of the [Apache License](LICENSE).

# Questions/Comments?

Please [open an issue](https://github.com/solarwinds/fluent-plugin-papertrail/issues/new), we'd love to hear from you. As a SolarWinds Innovation Project, this adapter is supported in a best-effort fashion.
