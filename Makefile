# Copyright 2019 Hayo van Loon
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

NAME := whatigot
VERSION := v1

# Docker-related
IMAGE_NAME := $(NAME)_$(VERSION)
TAG := latest

SERVICE_NAME := $(NAME)-$(VERSION)

PORT := 8080


.PHONY:

check-project:
ifndef PROJECT
	$(error missing PROJECT)
endif

all: clean build service-account deploy smoke-test

clean:
	go clean

build: check-project
	go mod vendor && \
	gcloud builds submit \
		--project=$(PROJECT) \
		--pack image=gcr.io/$(PROJECT)/$(IMAGE_NAME)
	rm -rf vendor

run:
	export PORT=$(PORT) && go run server.go

service-account: check-project
	gcloud iam service-accounts create $(SERVICE_NAME) \
		--project=$(PROJECT)

deploy: check-project
	gcloud run deploy $(SERVICE_NAME) \
		--project=$(PROJECT) \
		--region=europe-west1 \
		--platform=managed \
		--image=gcr.io/$(PROJECT)/$(IMAGE_NAME) \
		--memory=128Mi \
		--no-allow-unauthenticated \
		--service-account="$(SERVICE_NAME)@$(PROJECT).iam.gserviceaccount.com"

iam-allow-allAuthenticatedUsers: check-project
	gcloud run services add-iam-policy-binding $(SERVICE_NAME) \
 		--project=$(PROJECT) \
    	--region=europe-west1 \
		--platform=managed \
	   	--member=allAuthenticatedUsers \
    	--role="roles/run.invoker"

iam-allow-allUsers: check-project
	gcloud run services add-iam-policy-binding $(SERVICE_NAME) \
 		--project=$(PROJECT) \
    	--region=europe-west1 \
		--platform=managed \
	   	--member=allUsers \
    	--role="roles/run.invoker"

smoke-test: check-project
	URL=$$(gcloud run services list \
        		--project=$(PROJECT) \
        		--region=europe-west1 \
        		--platform=managed | grep whatigot | awk '{print $$4}')/banana && \
    echo $$URL; \
	curl \
		--data "foo=bar" \
		--cookie lalala=bla \
		--header "Authorization: Bearer $(shell gcloud auth print-identity-token)" \
		$$URL

smoke-test-local:
	curl \
	--data "foo=bar" \
	--cookie lalala=bla \
	--header "Authorization: Bearer $(shell gcloud auth print-identity-token)" \
	http://localhost:$(PORT)/banana

destroy: check-project
	gcloud iam service-accounts delete "$(SERVICE_NAME)@$(PROJECT).iam.gserviceaccount.com"
	gcloud run services delete $(SERVICE_NAME) \
 		--project=$(PROJECT) \
		--region=europe-west1 \
		--platform=managed
