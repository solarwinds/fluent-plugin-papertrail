# Fluent::Plugin::Papertrail

Welcome to the Papertrail Fluentd plugin!

## Installation

Install this gem when setting up fluentd:

```ruby
gem install fluent-plugin-papertrail
```

## Usage

To configure this in fluentd
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

The default flush interval for Fluent's buffer is set to 1 second. If you want to override this, for example to 60 seconds, you could add an extra config param `flush_interval` to your match stanza:
```xml
<match whatever.*>
  type papertrail
  papertrail_host <your papertrail hostname>
  papertrail_port <your papertrail port>
  flush_interval 60
</match>
```
## Development

We use git, Make and Docker. 
We have a [Dockerfile](Dockerfile.scratch) where we build a scratch image that contains all the dependencies.
We have a [Makefile](Makefile) to wrap the common functions and make life easier.

### Install
`make install`

### Test
`make test`

### Release in [RubyGems](RubyGems.org)
To release a new version, update the version number in the [GemSpec](fluent-plugin-papertrail.gemspec) and then, run:

`make release`

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/solarwinds/fluent-plugin-papertrail.


## License

The gem is available as open source under the terms of the [Apache License](LICENSE).

# Questions/Comments?
Please [open an issue](https://github.com/solarwinds/fluent-plugin-papertrail/issues/new), we'd love to hear from you. As a SolarWinds Innovation Project, this adapter is supported in a best-effort fashion.
