REPO_NAME=fluent-plugin-papertrail

bundle:
	bundle install

test: bundle
	bundle exec rake test

release: bundle
	rm -rf ${REPO_NAME}-*.gem
	bundle exec gem build ${REPO_NAME}.gemspec
	bundle exec gem push ${REPO_NAME}-*.gem

release-docker:
	cd docker; docker build -t quay.io/solarwinds/fluentd-kubernetes:$(TAG) .
	docker push quay.io/solarwinds/fluentd-kubernetes:$(TAG)