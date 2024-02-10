export UID=$(shell id -u)
export GID=$(shell id -g)

include .env
-include .env.local
export

DOCKER_COMPOSE_OPTIONS := -f docker-compose.yaml
DOCKER_COMPOSE         := docker compose $(DOCKER_COMPOSE_OPTIONS)

##
## CI/CD
## -----

feature-stage:
	$(eval DOCKER_COMPOSE_OPTIONS := -f docker-compose-feature-stage.yaml -p api-$$(FEATURE_ENV_HOST))
	$(eval DOCKER_COMPOSE := docker compose $$(DOCKER_COMPOSE_OPTIONS))
	@:
.PHONY: feature-stage

up:
	$(DOCKER_COMPOSE) up --build --remove-orphans --detach
.PHONY: up

stop:
	$(DOCKER_COMPOSE) down --remove-orphans
.PHONY: stop

build-stage-image:
	DOCKER_BUILDKIT=1 docker build -f ./docker/php-stage/Dockerfile -t $(CI_REGISTRY_IMAGE):$(FEATURE_ENV_HOST) .

push-stage-image:
	docker --config ~/config-$(CI_JOB_ID) login -u $(CI_REGISTRY_USER) -p $(CI_REGISTRY_PASSWORD) $(CI_REGISTRY)
	docker --config ~/config-$(CI_JOB_ID) push $(CI_REGISTRY_IMAGE):$(FEATURE_ENV_HOST)
	docker --config ~/config-$(CI_JOB_ID) logout $(CI_REGISTRY)
	rm -rf ~/config-$(CI_JOB_ID)

deploy-feature-stage:
	ssh -p 12345 gitlab-deploy@stage "mkdir -p /home/gitlab-deploy/$(FEATURE_ENV_HOST)"
	scp -P 12345 docker-compose-feature-stage.yaml Makefile .env .env.local gitlab-deploy@stage:/home/gitlab-deploy/$(FEATURE_ENV_HOST)
	ssh -p 12345 gitlab-deploy@stage "docker --config ~/config-$(CI_JOB_ID) login -u $(CI_REGISTRY_USER) -p $(CI_REGISTRY_PASSWORD) $(CI_REGISTRY)"
	ssh -p 12345 gitlab-deploy@stage "docker --config ~/config-$(CI_JOB_ID) pull $(CI_REGISTRY_IMAGE):$(FEATURE_ENV_HOST)"
	ssh -p 12345 gitlab-deploy@stage "cd /home/gitlab-deploy/$(FEATURE_ENV_HOST) && $(MAKE) feature-stage stop"
	ssh -p 12345 gitlab-deploy@stage "cd /home/gitlab-deploy/$(FEATURE_ENV_HOST) && $(MAKE) feature-stage up"
	ssh -p 12345 gitlab-deploy@stage "cd /home/gitlab-deploy/$(FEATURE_ENV_HOST) && rm .env.local"
	ssh -p 12345 gitlab-deploy@stage "docker --config ~/config-$(CI_JOB_ID) logout $(CI_REGISTRY)"
	ssh -p 12345 gitlab-deploy@stage "rm -rf ~/config-$(CI_JOB_ID)"

stop-feature-stage:
	ssh -p 12345 gitlab-deploy@stage "cd /home/gitlab-deploy/$(FEATURE_ENV_HOST) && FEATURE_ENV_HOST=$(FEATURE_ENV_HOST) $(MAKE) feature-stage stop"
	ssh -p 12345 gitlab-deploy@stage "rm -rf /home/gitlab-deploy/$(FEATURE_ENV_HOST)"