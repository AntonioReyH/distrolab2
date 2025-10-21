FROM golang:1.24-alpine AS build
WORKDIR /app
COPY go.mod go.sum ./
COPY vendor/ ./vendor/
# Copy the entire module context so Falabellox/ and proto/ are present
COPY . .
WORKDIR /app/Falabellox
RUN CGO_ENABLED=0 GOOS=linux go build -mod=vendor -o /falabellox ./falabellox.go

FROM scratch
COPY --from=build /falabellox /falabellox
COPY Falabellox/falabellox_catalogo.csv /falabellox_catalogo.csv
ENTRYPOINT ["/falabellox"]
