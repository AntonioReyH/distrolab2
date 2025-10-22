# Makefile para levantar contenedores por VM
# Uso: make docker-VM1

# IPs de las VMs
VM1_IP := 10.35.168.88
VM2_IP := 10.35.168.89
VM3_IP := 10.35.168.90
VM4_IP := 10.35.168.112

# Detectar si se necesita sudo
SUDO := $(shell if [ "`id -u`" != "0" ]; then echo sudo; fi)

# Prefijo de proyecto
PROJECT := distrolab2

# Función para build + run de un contenedor simple
# $1 = nombre del servicio
# $2 = ruta del Dockerfile
define build_run
	@echo ">>> Construyendo $1..."
	$(SUDO) docker build -t $(PROJECT)_$1:latest $2
	@echo ">>> Corriendo $1..."
	$(SUDO) docker rm -f $(PROJECT)_$1 2>/dev/null || true
	$(SUDO) docker run -d --name $(PROJECT)_$1 --network host --env BROKER_ADDR=$(VM4_IP):50051 $$(if [ "$1" = "bd1" ]; then echo "--env BD_ADDR=$(VM1_IP):50052"; fi) $$(if [ "$1" = "bd2" ]; then echo "--env BD_ADDR=$(VM2_IP):50053"; fi) $$(if [ "$1" = "bd3" ]; then echo "--env BD_ADDR=$(VM3_IP):50054"; fi) $$(if [ "$1" = "riploy" ]; then echo "--env BD1_ADDR=$(VM1_IP):50052"; fi) $$(if [ "$1" = "falabellox" ]; then echo "--env BD2_ADDR=$(VM2_IP):50053"; fi) $$(if [ "$1" = "parisio" ]; then echo "--env BD3_ADDR=$(VM3_IP):50054"; fi) $(PROJECT)_$1:latest
endef

# ========================================================
# VM1: bd1 + riploy
# ========================================================
docker-VM1:
	$(call build_run,bd1,Riploy_BD1_C2)
	$(call build_run,riploy,Riploy_BD1_C2)

# ========================================================
# VM2: bd2 + falabellox
# ========================================================
docker-VM2:
	$(call build_run,bd2,Fallabellox_BD2_C3)
	$(call build_run,falabellox,Fallabellox_BD2_C3)

# ========================================================
# VM3: bd3 + parisio
# ========================================================
docker-VM3:
	$(call build_run,bd3,Parisio_BD3)
	$(call build_run,parisio,Parisio_BD3)

# ========================================================
# VM4: broker
# ========================================================
docker-VM4:
	$(call build_run,broker,Broker_C1/Broker)
