FROM golang:1.24-alpine AS build

WORKDIR /app
COPY go.mod go.sum ./
COPY vendor/ ./vendor/
# Copy the entire module context so proto/ and BD3/ are in the module root
COPY . .
WORKDIR /app/BD3
RUN CGO_ENABLED=0 GOOS=linux go build -mod=vendor -o /bd3 ./bd3.go

FROM scratch
COPY --from=build /bd3 /bd3
EXPOSE 50054
ENTRYPOINT ["/bd3"]
