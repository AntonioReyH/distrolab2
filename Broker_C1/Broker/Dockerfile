# build stage
FROM golang:1.24-alpine AS build
WORKDIR /app
COPY go.mod go.sum ./
COPY vendor/ ./vendor/
# Copy the entire module context so Broker/ and proto/ are present
COPY . .
WORKDIR /app/Broker
RUN CGO_ENABLED=0 GOOS=linux go build -mod=vendor -o /broker ./broker_main.go

# final stage
FROM scratch
COPY --from=build /broker /broker
EXPOSE 50051
ENTRYPOINT ["/broker"]
