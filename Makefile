# Organisation name
ORG_NAME=solarwinds
# Repository name
REPO_NAME=fluent-plugin-papertrail


# Scratch Dockerfile
SCRATCH_CONTAINER_DOCKERFILE=Dockerfile.scratch
# Scratch Image name
SCRATCH_IMAGE_NAME=${REPO_NAME}_scratch
# Scratch Container name
SCRATCH_CONTAINER_NAME=${REPO_NAME}_scratch

SCRATCH_CONTAINER_DOCKER_OPTS=--rm -v $(PWD):/home -v $(PWD)/vendor/bundle:/usr/local/bundle -w=/home

build-image-scratch:
	docker build --file ${SCRATCH_CONTAINER_DOCKERFILE} --tag ${SCRATCH_IMAGE_NAME} .

install: build-image-scratch
	docker run ${SCRATCH_CONTAINER_DOCKER_OPTS} --name ${SCRATCH_CONTAINER_NAME} ${SCRATCH_IMAGE_NAME} bundle install

test: install
	docker run ${SCRATCH_CONTAINER_DOCKER_OPTS} --name ${SCRATCH_CONTAINER_NAME} ${SCRATCH_IMAGE_NAME} bundle exec rake test

clean:
	docker rm ${SCRATCH_CONTAINER_NAME}

clean-image-scratch:
	docker rmi -f ${SCRATCH_IMAGE_NAME}