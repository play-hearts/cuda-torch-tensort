NAME := tensorrt-dev
IMAGE := cuda-torch-tensort
HUB_DIR := /home/jim/hub

# Use shell function to get username, UID, and GID
USERNAME := $(shell whoami)
USER_UID := $(shell id -u)
USER_GID := $(shell id -g)

.PHONY: build run stop remove ssh clean status generate_ssh_keys

generate_ssh_keys:
	@if [ ! -f ssh_host_keys/ssh_host_rsa_key ]; then \
		mkdir -p ssh_host_keys; \
		ssh-keygen -f ssh_host_keys/ssh_host_rsa_key -N '' -t rsa; \
		ssh-keygen -f ssh_host_keys/ssh_host_dsa_key -N '' -t dsa; \
		ssh-keygen -f ssh_host_keys/ssh_host_ecdsa_key -N '' -t ecdsa; \
		ssh-keygen -f ssh_host_keys/ssh_host_ed25519_key -N '' -t ed25519; \
	fi

build: generate_ssh_keys
	docker build -t $(IMAGE) \
		--build-arg USERNAME=$(USERNAME) \
		--build-arg USER_UID=$(USER_UID) \
		--build-arg USER_GID=$(USER_GID) .

run:
	docker run --detach --gpus all -p 2222:22 -v ${HUB_DIR}:${HUB_DIR} --name ${NAME} $(IMAGE)

stop:
	-docker stop -t 30 ${NAME}

remove: stop
	-docker rm ${NAME}

ssh:
	ssh -p 2222 $(USERNAME)@localhost

# Clean up everything
clean: remove
	-docker rmi $(IMAGE)

# Show container status
status:
	@echo "Container status:"
	@docker ps -a | grep $(NAME) || echo "Container not found"
	@echo "Image status:"
	@docker images | grep $(IMAGE) || echo "Image not found"
