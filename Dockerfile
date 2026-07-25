FROM swift:6.3-noble AS build
WORKDIR /build
COPY Package.swift Package.resolved* ./
RUN swift package resolve
COPY Sources ./Sources
RUN swift build -c release --static-swift-stdlib

FROM ubuntu:noble
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates libjemalloc2 libssl3 zlib1g && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY --from=build /build/.build/release/BubblyBackend /app/BubblyBackend
USER 65532:65532
EXPOSE 8080
ENTRYPOINT ["/app/BubblyBackend"]
CMD ["serve", "--env", "production", "--hostname", "0.0.0.0", "--port", "8080"]
