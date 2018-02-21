REPO_NAME=fluent-plugin-papertrail
SCRATCH_CONTAINER_DOCKERFILE=Dockerfile.scratch
SCRATCH_IMAGE_NAME=${REPO_NAME}_scratch
SCRATCH_CONTAINER_NAME=${REPO_NAME}_scratch
SCRATCH_CONTAINER_DOCKER_OPTS=--rm -v $(PWD):/home -v $(PWD)/vendor/bundle:/usr/local/bundle -w=/home

build-image-scratch:
	docker build --file ${SCRATCH_CONTAINER_DOCKERFILE} --tag ${SCRATCH_IMAGE_NAME} .

install: build-image-scratch
	docker run ${SCRATCH_CONTAINER_DOCKER_OPTS} --name ${SCRATCH_CONTAINER_NAME} ${SCRATCH_IMAGE_NAME} bundle install

test: install
	docker run ${SCRATCH_CONTAINER_DOCKER_OPTS} --name ${SCRATCH_CONTAINER_NAME} ${SCRATCH_IMAGE_NAME} bundle exec rake test

release: install
	rm -rf ${REPO_NAME}-*.gem
	docker run ${SCRATCH_CONTAINER_DOCKER_OPTS} --name ${SCRATCH_CONTAINER_NAME} ${SCRATCH_IMAGE_NAME} bundle exec gem build ${REPO_NAME}.gemspec
	docker run -it ${SCRATCH_CONTAINER_DOCKER_OPTS} --name ${SCRATCH_CONTAINER_NAME} ${SCRATCH_IMAGE_NAME} bundle exec gem push ${REPO_NAME}-*.gem

release-docker:
	cd docker; docker build -t quay.io/solarwinds/fluentd-kubernetes:$(TAG) .
	docker push quay.io/solarwinds/fluentd-kubernetes:$(TAG)

clean:
	docker rm ${SCRATCH_CONTAINER_NAME}

clean-image-scratch:
	docker rmi -f ${SCRATCH_IMAGE_NAME}
