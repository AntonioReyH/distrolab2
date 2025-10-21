FROM golang:1.24-alpine AS build
WORKDIR /app
COPY go.mod go.sum ./
COPY vendor/ ./vendor/
# Copy the entire module context so Riploy/ and proto/ are present
COPY . .
WORKDIR /app/Riploy
RUN CGO_ENABLED=0 GOOS=linux go build -mod=vendor -o /riploy ./riploy.go

FROM scratch
COPY --from=build /riploy /riploy
# include CSV in final image (copying from build context)
COPY Riploy/riploy_catalogo.csv /riploy_catalogo.csv
ENTRYPOINT ["/riploy"]
