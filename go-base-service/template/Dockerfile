FROM golang:1.21-alpine AS builder

WORKDIR /app

COPY go.mod ./
# COPY go.sum ./
RUN go mod download

COPY . .

RUN go build -o /app/server

FROM alpine:3.18

WORKDIR /app
COPY --from=builder /app/server .

CMD ["./server"]
