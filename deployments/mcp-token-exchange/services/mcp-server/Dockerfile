# Build the minimal Acme MCP tool server (Go).
FROM golang:1.25-alpine AS build
WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 go build -o /mcp-server .

FROM alpine:3.20
RUN apk add --no-cache ca-certificates
COPY --from=build /mcp-server /mcp-server
EXPOSE 7878
ENTRYPOINT ["/mcp-server"]
