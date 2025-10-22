# Makefile para orquestar despliegue por VM
# Uso: make docker-VM1  (ejecutar en la VM1 después de git clone)

VM1_IP=10.35.168.88
VM2_IP=10.35.168.89
VM3_IP=10.35.168.90
VM4_IP=10.35.168.112

# Services por VM (según enunciado)
VM1_SVCS=bd1 riploy
VM2_SVCS=bd2 falabellox
VM3_SVCS=bd3 parisio
VM4_SVCS=broker

# Detect compose command at parse time (prefer docker-compose, fallback to `docker compose`)
ifeq (,$(shell command -v docker-compose 2>/dev/null))
	ifeq (,$(shell docker compose version >/dev/null 2>&1; echo $?))
		# docker compose not available as subcommand
		ifneq (,$(shell command -v docker 2>/dev/null))
			COMPOSE_BIN=docker
			COMPOSE_ARGS=compose
		else
			$(error neither docker-compose nor docker (with compose) found)
		endif
	else
		# This branch normally shouldn't run because above shell returns empty; keep fallback
		COMPOSE_BIN=docker
		COMPOSE_ARGS=compose
	endif
else
	COMPOSE_BIN=docker-compose
	COMPOSE_ARGS=
endif

# Determine if sudo is required (empty if root)
NEED_SUDO := $(shell if [ "`id -u`" != "0" ]; then echo sudo; fi)

# Genera .env temporal y ejecuta compose para los servicios indicados
define run_vm
	@echo "Generating .env for $(1)"
	@printf 'BROKER_ADDR=%s\n' "${BROKER_ADDR:-10.35.168.112:50051}" > .env
	@printf 'DB_ADDRESSES=%s\n' "${DB_ADDRESSES:-10.35.168.88:50052,10.35.168.89:50053,10.35.168.90:50054}" >> .env
	@printf 'BD1_ADDR=%s\n' "${BD1_ADDR:-10.35.168.88:50052}" >> .env
	@printf 'BD2_ADDR=%s\n' "${BD2_ADDR:-10.35.168.89:50053}" >> .env
	@printf 'BD3_ADDR=%s\n' "${BD3_ADDR:-10.35.168.90:50054}" >> .env
	@echo "Building services (in order): ${2}"
	@echo "Using compose: $(COMPOSE_BIN) $(COMPOSE_ARGS)  (sudo: $(NEED_SUDO))"
	@# Build each service image only (avoid starting unrelated containers)
	@for svc in ${2}; do \
		echo "-> Building $$svc"; \
		if [ "$(COMPOSE_BIN)" = "docker" ]; then \
			$(NEED_SUDO) $(COMPOSE_BIN) $(COMPOSE_ARGS) build --no-cache --progress=plain $$svc || exit $$?; \
		else \
			$(NEED_SUDO) $(COMPOSE_BIN) $(COMPOSE_ARGS) build --no-cache $$svc || exit $$?; \
		fi; \
	done
	@rm -f .env
	@echo "Build finished for $(1)"
endef

# Recreate (rm + up --build) services for a VM, removing old containers first
define run_vm_recreate
	@echo "Generating .env for $(1)"
	@printf 'BROKER_ADDR=%s\n' "10.35.168.112:50051" > .env
	@printf 'DB_ADDRESSES=%s\n' "10.35.168.88:50052,10.35.168.89:50053,10.35.168.90:50054" >> .env
	@printf 'BD1_ADDR=%s\n' "10.35.168.88:50052" >> .env
	@printf 'BD2_ADDR=%s\n' "10.35.168.89:50053" >> .env
	@printf 'BD3_ADDR=%s\n' "10.35.168.90:50054" >> .env
	@echo "Recreating services (no-deps): ${2}"
	# create a fixed script path and write the recreation script to it
	printf '%s\n' "#!/bin/sh" > /tmp/distrolab2_recreate_$(1).sh; \
	printf '%s\n' "set -eu" >> /tmp/distrolab2_recreate_$(1).sh; \
	# write SUDO variable for script
	printf '%s\n' "SUDO='$(NEED_SUDO)'" >> /tmp/distrolab2_recreate_$(1).sh; \
	# pass project name
	printf '%s\n' "PROJECT='${COMPOSE_PROJECT_NAME:-distrolab2}'" >> /tmp/distrolab2_recreate_$(1).sh; \
	# write services list
	printf '%s\n' "SERVICES='${2}'" >> /tmp/distrolab2_recreate_$(1).sh; \
	# script body: iterate and attempt compose up, fallback to docker run
	printf '%s\n' "for svc in $$SERVICES; do" >> /tmp/distrolab2_recreate_$(1).sh; \
	printf '%s\n' "  echo '-> Removing possible old container for' $$svc" >> /tmp/distrolab2_recreate_$(1).sh; \
	printf '%s\n' "  $$SUDO $(COMPOSE_BIN) $(COMPOSE_ARGS) rm -f $$svc 2>/dev/null || true" >> /tmp/distrolab2_recreate_$(1).sh; \
	printf '%s\n' "  $$SUDO docker ps -a -q --filter name=$$PROJECT_$$svc 2>/dev/null | xargs -r $$SUDO docker rm -f || true" >> /tmp/distrolab2_recreate_$(1).sh; \
	printf '%s\n' "  # also remove any container matching pattern *_<svc>_1 (handles different compose project names)" >> /tmp/distrolab2_recreate_$(1).sh; \
	printf '%s\n' "  $$SUDO docker ps -a -q --filter name=_$$svc_1 2>/dev/null | xargs -r $$SUDO docker rm -f || true" >> /tmp/distrolab2_recreate_$(1).sh; \
	printf '%s\n' "  echo '-> Recreating' $$svc" >> /tmp/distrolab2_recreate_$(1).sh; \
	printf '%s\n' "  if $$SUDO $(COMPOSE_BIN) $(COMPOSE_ARGS) up -d --build --force-recreate --no-deps $$svc 2>/tmp/compose-$$svc.log; then" >> /tmp/distrolab2_recreate_$(1).sh; \
	printf '%s\n' "    echo '-> compose up succeeded for' $$svc" >> /tmp/distrolab2_recreate_$(1).sh; \
	printf '%s\n' "  else" >> /tmp/distrolab2_recreate_$(1).sh; \
	printf '%s\n' "    cat /tmp/compose-$$svc.log 1>&2 || true" >> /tmp/distrolab2_recreate_$(1).sh; \
	printf '%s\n' "    $$SUDO docker rm -f $$PROJECT_$$svc 2>/dev/null || true" >> /tmp/distrolab2_recreate_$(1).sh; \
	printf '%s\n' "    $$SUDO docker run -d --name $$PROJECT_$$svc --env-file .env distrolab2_$$svc:latest || exit 1" >> /tmp/distrolab2_recreate_$(1).sh; \
	printf '%s\n' "  fi" >> /tmp/distrolab2_recreate_$(1).sh; \
	printf '%s\n' "done" >> /tmp/distrolab2_recreate_$(1).sh; \
	chmod +x /tmp/distrolab2_recreate_$(1).sh; \
	$(NEED_SUDO) sh /tmp/distrolab2_recreate_$(1).sh; \
	rc=$$?; rm -f /tmp/distrolab2_recreate_$(1).sh || true; exit $$rc
endef

# Run (up) services for a VM without starting dependencies on that host
define run_vm_up
	@echo "Generating .env for $(1)"
	@printf 'BROKER_ADDR=%s\n' "$${BROKER_ADDR:-$(4):50051}" > .env
	@printf 'DB_ADDRESSES=%s\n' "$${DB_ADDRESSES:-$(5)}" >> .env
	@printf 'BD1_ADDR=%s\n' "$${BD1_ADDR:-$(8)}" >> .env
	@printf 'BD2_ADDR=%s\n' "$${BD2_ADDR:-$(9)}" >> .env
	@printf 'BD3_ADDR=%s\n' "$${BD3_ADDR:-$(10)}" >> .env
	@echo "Starting services (no-deps): ${2}"
	@for svc in ${2}; do \
		echo "-> Up $$svc"; \
		$(NEED_SUDO) $(COMPOSE_BIN) $(COMPOSE_ARGS) up -d --no-deps $$svc || exit $$?; \
	done
	@rm -f .env
	@echo "Services started for $(1)"
endef

.PHONY: docker-VM1 docker-VM2 docker-VM3 docker-VM4 docker-all

docker-VM1:
	$(call run_vm,VM1,${VM1_SVCS},${VM1_IP},${VM4_IP},bd1:${VM2_IP}:50052,bd2:${VM3_IP}:50053,bd3:${VM4_IP}:50054,${VM1_IP}:50052,${VM2_IP}:50053,${VM3_IP}:50054)

docker-VM1-up:
	$(call run_vm_up,VM1,${VM1_SVCS},${VM1_IP},${VM4_IP},bd1:${VM2_IP}:50052,bd2:${VM3_IP}:50053,bd3:${VM4_IP}:50054,${VM1_IP}:50052,${VM2_IP}:50053,${VM3_IP}:50054)

docker-VM1-recreate:
	$(call run_vm_recreate,VM1,${VM1_SVCS},${VM1_IP},${VM4_IP},bd1:${VM2_IP}:50052,bd2:${VM3_IP}:50053,bd3:${VM4_IP}:50054,${VM1_IP}:50052,${VM2_IP}:50053,${VM3_IP}:50054)

docker-VM2:
	$(call run_vm,VM2,${VM2_SVCS},${VM2_IP},${VM4_IP},bd1:${VM1_IP}:50052,bd2:${VM3_IP}:50053,bd3:${VM4_IP}:50054,${VM1_IP}:50052,${VM2_IP}:50053,${VM3_IP}:50054)

docker-VM2-up:
	$(call run_vm_up,VM2,${VM2_SVCS},${VM2_IP},${VM4_IP},bd1:${VM1_IP}:50052,bd2:${VM3_IP}:50053,bd3:${VM4_IP}:50054,${VM1_IP}:50052,${VM2_IP}:50053,${VM3_IP}:50054)

docker-VM2-recreate:
	$(call run_vm_recreate,VM2,${VM2_SVCS},${VM2_IP},${VM4_IP},bd1:${VM1_IP}:50052,bd2:${VM3_IP}:50053,bd3:${VM4_IP}:50054,${VM1_IP}:50052,${VM2_IP}:50053,${VM3_IP}:50054)

docker-VM3:
	$(call run_vm,VM3,${VM3_SVCS},${VM3_IP},${VM4_IP},bd1:${VM1_IP}:50052,bd2:${VM2_IP}:50053,bd3:${VM4_IP}:50054,${VM1_IP}:50052,${VM2_IP}:50053,${VM3_IP}:50054)

docker-VM3-up:
	$(call run_vm_up,VM3,${VM3_SVCS},${VM3_IP},${VM4_IP},bd1:${VM1_IP}:50052,bd2:${VM2_IP}:50053,bd3:${VM4_IP}:50054,${VM1_IP}:50052,${VM2_IP}:50053,${VM3_IP}:50054)

docker-VM3-recreate:
	$(call run_vm_recreate,VM3,${VM3_SVCS},${VM3_IP},${VM4_IP},bd1:${VM1_IP}:50052,bd2:${VM2_IP}:50053,bd3:${VM4_IP}:50054,${VM1_IP}:50052,${VM2_IP}:50053,${VM3_IP}:50054)

docker-VM4:
	$(call run_vm,VM4,${VM4_SVCS},${VM4_IP},${VM4_IP},bd1:${VM1_IP}:50052,bd2:${VM2_IP}:50053,bd3:${VM3_IP}:50054,${VM1_IP}:50052,${VM2_IP}:50053,${VM3_IP}:50054)

docker-VM4-up:
	$(call run_vm_up,VM4,${VM4_SVCS},${VM4_IP},${VM4_IP},bd1:${VM1_IP}:50052,bd2:${VM2_IP}:50053,bd3:${VM3_IP}:50054,${VM1_IP}:50052,${VM2_IP}:50053,${VM3_IP}:50054)

docker-VM4-recreate:
	$(call run_vm_recreate,VM4,${VM4_SVCS},${VM4_IP},${VM4_IP},bd1:${VM1_IP}:50052,bd2:${VM2_IP}:50053,bd3:${VM3_IP}:50054,${VM1_IP}:50052,${VM2_IP}:50053,${VM3_IP}:50054)

# Levanta todo localmente (útil para pruebas)
docker-all:
	docker compose up -d --build

# generate-env target: create a persistent .env for debugging or manual docker run
define gen_env
	@echo "Writing persistent .env for $(1)"
	@printf 'BROKER_ADDR=%s\n' "10.35.168.112:50051" > .env
	@printf 'DB_ADDRESSES=%s\n' "10.35.168.88:50052,10.35.168.89:50053,10.35.168.90:50054" >> .env
	@printf 'BD1_ADDR=%s\n' "10.35.168.88:50052" >> .env
	@printf 'BD2_ADDR=%s\n' "10.35.168.89:50053" >> .env
	@printf 'BD3_ADDR=%s\n' "10.35.168.90:50054" >> .env
	@echo ".env written (KEEP_ENV=1 will preserve it when running other targets)"
endef

.PHONY: generate-env-VM1 generate-env-VM2 generate-env-VM3 generate-env-VM4

generate-env-VM1:
	$(call gen_env,VM1,${VM1_SVCS},${VM1_IP},${VM4_IP},bd1:${VM2_IP}:50052,bd2:${VM3_IP}:50053,bd3:${VM4_IP}:50054,${VM1_IP}:50052,${VM2_IP}:50053,${VM3_IP}:50054)

generate-env-VM2:
	$(call gen_env,VM2,${VM2_SVCS},${VM2_IP},${VM4_IP},bd1:${VM1_IP}:50052,bd2:${VM3_IP}:50053,bd3:${VM4_IP}:50054,${VM1_IP}:50052,${VM2_IP}:50053,${VM3_IP}:50054)

generate-env-VM3:
	$(call gen_env,VM3,${VM3_SVCS},${VM3_IP},${VM4_IP},bd1:${VM1_IP}:50052,bd2:${VM2_IP}:50053,bd3:${VM4_IP}:50054,${VM1_IP}:50052,${VM2_IP}:50053,${VM3_IP}:50054)

generate-env-VM4:
	$(call gen_env,VM4,${VM4_SVCS},${VM4_IP},${VM4_IP},bd1:${VM1_IP}:50052,bd2:${VM2_IP}:50053,bd3:${VM3_IP}:50054,${VM1_IP}:50052,${VM2_IP}:50053,${VM3_IP}:50054)
