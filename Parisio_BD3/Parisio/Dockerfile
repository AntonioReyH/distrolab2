FROM golang:1.24-alpine AS build
WORKDIR /app
COPY go.mod go.sum ./
COPY vendor/ ./vendor/
# Copy the entire module context so Parisio/ and proto/ are present
COPY . .
WORKDIR /app/Parisio
RUN CGO_ENABLED=0 GOOS=linux go build -mod=vendor -o /parisio ./parisio.go

FROM scratch
COPY --from=build /parisio /parisio
COPY Parisio/parisio_catalogo.csv /parisio_catalogo.csv
ENTRYPOINT ["/parisio"]
