package main

import (
	"context"
	"encoding/csv"
	"io"
	"log"
	"math/rand"
	"os"
	"strconv"
	"time"

	pb "riploy_bd1_c2/proto"

	"google.golang.org/grpc"
)

const (
	defaultBroker = "localhost:50051"
)

func getenv(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}

func main() {

	//random seed
	r := rand.New(rand.NewSource(time.Now().UnixNano()))
	//Conectar al servidor gRPC
	address_broker := getenv("BROKER_ADDR", defaultBroker)
	conn, err := grpc.Dial(address_broker, grpc.WithInsecure())
	if err != nil {
		log.Fatalf("Error al conectar al servidor: %v", err)
	}
	defer conn.Close()

	client := pb.NewOfertasClient(conn)

	ctx := context.Background()

	file, err := os.Open("riploy_catalogo.csv")
	if err != nil {
		log.Fatalf("Error abriendo archivo CSV: %v", err)
	}
	defer file.Close()

	reader := csv.NewReader(file)

	if _, err := reader.Read(); err != nil {
		log.Fatalf("Error leyendo header de CSV: %v", err)
	}

	for {
		record, err := reader.Read()

		if err == io.EOF {
			break
		}
		if err != nil {
			log.Fatalf("Error enviando oferta de CSV: %v", err)
		}

		//convertir precio y stock a int32
		originalPrecioBase, err := strconv.Atoi(record[4])
		if err != nil {
			log.Printf("Warning: No pudo transformar precio_base '%s'. Saltando fila.", record[4])
			continue
		}

		stock, err := strconv.Atoi(record[5])
		if err != nil {
			log.Printf("Warning: No pudo transformar stock '%s'. Saltando fila.", record[5])
			continue
		}

		//Aplicar descuento aleatorio entre 10% y 50%
		discountPercent := 0.10 + r.Float64()*0.40
		originalPrecioFloat := float64(originalPrecioBase)
		discountedPrecioFloat := originalPrecioFloat * (1.0 - discountPercent)
		finalPrecio := int32(discountedPrecioFloat)

		//Get Fecha Actual
		currentTime := time.Now()
		formattedDate := currentTime.Format("2006-01-02")

		resp, err := client.Ofertas(ctx, &pb.OfertasRequest{
			ProductoId:      record[0],
			Tienda:          record[1],
			Categoria:       record[2],
			Producto:        record[3],
			PrecioDescuento: int32(finalPrecio),
			Stock:           int32(stock),
			Fecha:           formattedDate,
			ClienteId:       "Riploy", // Identificador del cliente
		})

		if err != nil {
			log.Printf("Error enviando ProductoId %s: %v", record[0], err)
			continue // Continuar a la siguiente fila incluso si hay un error
		}

		log.Printf("Respuesta de %s: %s", record[0], resp.GetBrokerMessage())

		// Esperar un tiempo aleatorio entre 500ms y 2000ms antes de enviar la siguiente oferta
		sleepDuration := time.Duration(500+r.Intn(1500)) * time.Millisecond
		time.Sleep(sleepDuration)
	}

	log.Println("Finalizado enviando todas las ofertas del CSV.")
}
