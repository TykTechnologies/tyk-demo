# Build the Acme Support Copilot chat (Go). HTML pages are embedded via go:embed.
FROM golang:1.25-alpine AS build
WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 go build -o /chat .

FROM alpine:3.20
RUN apk add --no-cache ca-certificates    # TLS to any https IdP
COPY --from=build /chat /chat
EXPOSE 8090
ENTRYPOINT ["/chat"]
