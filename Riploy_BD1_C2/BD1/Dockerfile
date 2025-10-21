FROM golang:1.24-alpine AS build
WORKDIR /app
COPY go.mod go.sum ./
COPY vendor/ ./vendor/
# Copy the entire module context so proto/ and BD1/ are in the module root
COPY . .
WORKDIR /app/BD1
RUN CGO_ENABLED=0 GOOS=linux go build -mod=vendor -o /bd1 ./bd1.go

FROM scratch
COPY --from=build /bd1 /bd1
EXPOSE 50052
ENTRYPOINT ["/bd1"]
