# Use the offical Golang image to create a build artifact.
# This is based on Debian and sets the GOPATH to /go.
# https://hub.docker.com/_/golang
FROM golang:1.12 as builder
ARG version=develop

WORKDIR /go/src/github.com/keptn/dynatrace-service

# Force the go compiler to use modules 
ENV GO111MODULE=on
ENV GOPROXY=https://proxy.golang.org
ENV BUILDFLAGS=""

# Copy `go.mod` for definitions and `go.sum` to invalidate the next layer
# in case of a change in the dependencies
COPY go.mod go.sum ./

# Download dependencies
RUN go mod download 

ARG debugBuild

# set buildflags for debug build
RUN if [ ! -z "$debugBuild" ]; then export BUILDFLAGS='-gcflags "all=-N -l"'; fi  

# Copy local code to the container image.
COPY . .

# Build the command inside the container.
# (You may fetch or manage dependencies here, either manually or with a tool like "godep".)
RUN CGO_ENABLED=0 GOOS=linux go build $BUILDFLAGS -v -o dynatrace-service ./cmd/

# Use a Docker multi-stage build to create a lean production image.
# https://docs.docker.com/develop/develop-images/multistage-build/#use-multi-stage-builds
FROM alpine
RUN apk add --no-cache ca-certificates

ARG debugBuild
ARG version

ENV version $version
# IF we are debugging, we need to install libc6-compat for delve to work on alpine based containers
RUN if [ ! -z "$debugBuild" ]; then apk add --no-cache libc6-compat; fi

ARG KUBE_VERSION=1.14.1
RUN wget -q https://storage.googleapis.com/kubernetes-release/release/v$KUBE_VERSION/bin/linux/amd64/kubectl -O /bin/kubectl && \
  chmod +x /bin/kubectl

# Copy the binary to the production image from the builder stage.
COPY --from=builder /go/src/github.com/keptn/dynatrace-service/dynatrace-service /dynatrace-service
# ADD MANIFEST /

# Run the web service on container startup.
# CMD ["sh", "-c", "cat MANIFEST && /dynatrace-service"]

EXPOSE 8080

# required for external tools to detect this as a go binary
ENV GOTRACEBACK=all

# KEEP THE FOLLOWING LINES COMMENTED OUT!!! (they will be included within the travis-ci build)
#travis-uncomment ADD MANIFEST /
#travis-uncomment COPY entrypoint.sh /
#travis-uncomment ENTRYPOINT ["/entrypoint.sh"]

# Run the web service on container startup.
CMD ["/dynatrace-service"]
