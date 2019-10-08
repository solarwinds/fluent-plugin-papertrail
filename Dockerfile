FROM fluent/fluentd:v1.7-1

# Use root account to use apk
USER root

# below RUN includes plugins - you may customize including plugins as you wish
RUN apk add --no-cache --update --virtual .build-deps \
        sudo build-base ruby-dev git \
 && sudo gem install fluent-plugin-papertrail \
 && sudo gem sources --clear-all \
 && apk del .build-deps \
 && rm -rf /tmp/* /var/tmp/* /usr/lib/ruby/gems/*/cache/*.gem

USER fluent
