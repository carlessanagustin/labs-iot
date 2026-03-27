IMAGE_NAME     := labs-iot-tools
CONTAINER_NAME := labs-iot-tools

.PHONY: build run stop clean

build:
	docker build -t $(IMAGE_NAME) .

run:
	docker run --rm -it \
		--name $(CONTAINER_NAME) \
		-v $(PWD):/workspace \
		$(IMAGE_NAME)

stop:
	docker stop $(CONTAINER_NAME) 2>/dev/null || true

clean: stop
	docker rmi $(IMAGE_NAME) 2>/dev/null || true
