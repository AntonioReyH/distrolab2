FROM golang:1.24-alpine AS build
WORKDIR /app
COPY go.mod go.sum ./
COPY vendor/ ./vendor/
# Copy the entire module context so proto/ and BD2/ are in the module root
COPY . .
WORKDIR /app/BD2
RUN CGO_ENABLED=0 GOOS=linux go build -mod=vendor -o /bd2 ./bd2.go

FROM scratch
COPY --from=build /bd2 /bd2
EXPOSE 50053
ENTRYPOINT ["/bd2"]
