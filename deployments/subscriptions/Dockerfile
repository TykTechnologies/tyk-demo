FROM golang:1.21-alpine@sha256:2414035b086e3c42b99654c8b26e6f5b1b1598080d65fd03c7f499552ff4dc94 as build
WORKDIR /build
RUN apk update && apk upgrade
RUN apk add git
RUN git clone https://github.com/TykTechnologies/graphql-go-tools.git
WORKDIR /build/graphql-go-tools/examples/chat
RUN go mod tidy && go build -o chat ./server

FROM alpine:3.18@sha256:de0eb0b3f2a47ba1eb89389859a9bd88b28e82f5826b6969ad604979713c2d4f as runner
WORKDIR /app
COPY --from=build /build/graphql-go-tools/examples/chat/chat ./chat
EXPOSE 8085
ENTRYPOINT ["./chat"]
