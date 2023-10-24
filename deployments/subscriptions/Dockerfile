FROM golang:1.21-alpine as build
WORKDIR /build
RUN apk update && apk upgrade
RUN apk add git
RUN git clone https://github.com/TykTechnologies/graphql-go-tools.git
WORKDIR /build/graphql-go-tools/examples/chat
RUN go mod tidy && go build -o chat ./server

FROM alpine:3.18 as runner
WORKDIR /app
COPY --from=build /build/graphql-go-tools/examples/chat/chat ./chat
EXPOSE 8085
ENTRYPOINT ["./chat"]
