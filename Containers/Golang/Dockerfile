FROM golang:1.27.4-alpine3.24

RUN apk add --no-cache git

# goravel: framework installer, air: hot reload
RUN go install github.com/goravel/installer/goravel@v1.18.0 \
    && go install github.com/air-verse/air@v1.67.4
