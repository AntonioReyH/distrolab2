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

# Genera .env temporal y ejecuta compose para los servicios indicados
define run_vm
	@echo "Generating .env for $(1)"
	@printf 'BROKER_ADDR=%s\n' "${BROKER_ADDR:-$(4)}" > .env
	@printf 'DB_ADDRESSES=%s\n' "${DB_ADDRESSES:-$(5)}" >> .env
	@printf 'BD1_ADDR=%s\n' "${BD1_ADDR:-$(6)}" >> .env
	@printf 'BD2_ADDR=%s\n' "${BD2_ADDR:-$(7)}" >> .env
	@printf 'BD3_ADDR=%s\n' "${BD3_ADDR:-$(8)}" >> .env
	@echo "Starting services: ${2}"
	@echo "Detecting compose command and sudo requirement..."
	@sh -c '
	if docker compose version >/dev/null 2>&1; then
		COMPOSE_CMD="docker compose"
	elif command -v docker-compose >/dev/null 2>&1; then
		COMPOSE_CMD="docker-compose"
	else
		echo "ERROR: neither 'docker compose' nor 'docker-compose' found" >&2; exit 1
	fi
	# If we're not root, run docker with sudo
	if [ "$(id -u)" -ne 0 ]; then SUDO="sudo"; else SUDO=""; fi
	# Run compose
	$${SUDO} $${COMPOSE_CMD} up -d --build $(2)
	'
	@rm -f .env
endef

.PHONY: docker-VM1 docker-VM2 docker-VM3 docker-VM4 docker-all

docker-VM1:
	$(call run_vm,VM1,${VM1_SVCS},${VM1_IP},${VM4_IP},bd1:${VM2_IP}:50052,bd2:${VM3_IP}:50053,bd3:${VM4_IP}:50054,${VM1_IP}:50052,${VM2_IP}:50053,${VM3_IP}:50054)

docker-VM2:
	$(call run_vm,VM2,${VM2_SVCS},${VM2_IP},${VM4_IP},bd1:${VM1_IP}:50052,bd2:${VM3_IP}:50053,bd3:${VM4_IP}:50054,${VM1_IP}:50052,${VM2_IP}:50053,${VM3_IP}:50054)

docker-VM3:
	$(call run_vm,VM3,${VM3_SVCS},${VM3_IP},${VM4_IP},bd1:${VM1_IP}:50052,bd2:${VM2_IP}:50053,bd3:${VM4_IP}:50054,${VM1_IP}:50052,${VM2_IP}:50053,${VM3_IP}:50054)

docker-VM4:
	$(call run_vm,VM4,${VM4_SVCS},${VM4_IP},${VM4_IP},bd1:${VM1_IP}:50052,bd2:${VM2_IP}:50053,bd3:${VM3_IP}:50054,${VM1_IP}:50052,${VM2_IP}:50053,${VM3_IP}:50054)

# Levanta todo localmente (útil para pruebas)
docker-all:
	docker compose up -d --build
